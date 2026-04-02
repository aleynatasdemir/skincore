using System.Text;
using System.Text.Json;
using MongoDB.Driver;
using Skincore.Api.Models;

namespace Skincore.Api.Services;

public class AdminService
{
    private readonly MongoDbService _db;
    private readonly NotificationService _notificationService;
    private readonly IConfiguration _configuration;
    private readonly IWebHostEnvironment _env;
    private readonly ImageSearchService _imageSearchService;
    private readonly HttpClient _httpClient = new();

    // barcode → image URL (ortak_urunler.json'dan yüklenir)
    private readonly Dictionary<string, string> _barcodeImageMap;

    public AdminService(MongoDbService db, NotificationService notificationService, IConfiguration configuration, IWebHostEnvironment env, ImageSearchService imageSearchService)
    {
        _db = db;
        _notificationService = notificationService;
        _configuration = configuration;
        _env = env;
        _imageSearchService = imageSearchService;
        _barcodeImageMap = LoadBarcodeImageMap(env.ContentRootPath);
    }

    private static Dictionary<string, string> LoadBarcodeImageMap(string contentRoot)
    {
        var map = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        var path = Path.Combine(contentRoot, "ortak_urunler.json");
        if (!File.Exists(path)) return map;

        try
        {
            using var stream = File.OpenRead(path);
            var items = System.Text.Json.JsonSerializer.Deserialize<List<OrtakUrun>>(stream,
                new System.Text.Json.JsonSerializerOptions { PropertyNameCaseInsensitive = true });

            if (items == null) return map;

            foreach (var item in items)
            {
                if (string.IsNullOrWhiteSpace(item.Image) || string.IsNullOrWhiteSpace(item.Barcode))
                    continue;

                // Virgülle ayrılmış birden fazla barcode olabilir
                foreach (var bc in item.Barcode.Split(',', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries))
                {
                    if (!map.ContainsKey(bc))
                        map[bc] = item.Image;
                }
            }
        }
        catch { /* dosya okunamazsa boş map döner */ }

        return map;
    }

    private record OrtakUrun(string? Barcode, string? Image);


    // ── Kullanıcı listesi ──
    public async Task<List<AdminUserResponse>> GetAllUsersAsync(int page = 1, int limit = 50, string? search = null, bool? isBanned = null)
    {
        var filter = BuildUserFilter(search, isBanned);

        var users = await _db.UsersCollection
            .Find(filter)
            .SortByDescending(u => u.CreatedAt)
            .Skip((page - 1) * limit)
            .Limit(limit)
            .ToListAsync();

        return users.Select(AdminUserResponse.FromUser).ToList();
    }

    public async Task<long> GetUserCountAsync(string? search = null, bool? isBanned = null)
    {
        var filter = BuildUserFilter(search, isBanned);
        return await _db.UsersCollection.CountDocumentsAsync(filter);
    }

    // ── Ban / Unban ──
    public async Task<bool> BanUserAsync(string userId, string? reason)
    {
        var update = Builders<User>.Update
            .Set(u => u.IsBanned, true)
            .Set(u => u.BanReason, reason)
            .Set(u => u.UpdatedAt, DateTime.UtcNow);
        var result = await _db.UsersCollection.UpdateOneAsync(u => u.Id == userId, update);
        return result.MatchedCount > 0;
    }

    public async Task<bool> UnbanUserAsync(string userId)
    {
        var update = Builders<User>.Update
            .Set(u => u.IsBanned, false)
            .Unset(u => u.BanReason)
            .Set(u => u.UpdatedAt, DateTime.UtcNow);
        var result = await _db.UsersCollection.UpdateOneAsync(u => u.Id == userId, update);
        return result.MatchedCount > 0;
    }

    // ── Rutin sil ──
    public async Task<bool> DeleteRoutineAsync(string routineId)
    {
        var result = await _db.RoutinesCollection.DeleteOneAsync(r => r.Id == routineId);
        return result.DeletedCount > 0;
    }

    // ── Yorum sil ──
    public async Task<bool> DeleteCommentAsync(string routineId, string commentId)
    {
        var update = Builders<Routine>.Update.PullFilter(
            r => r.Comments,
            Builders<RoutineComment>.Filter.Eq(c => c.Id, commentId)
        );
        var result = await _db.RoutinesCollection.UpdateOneAsync(r => r.Id == routineId, update);
        return result.ModifiedCount > 0;
    }

    // ── Rutin listesi ──
    public async Task<List<AdminRoutineResponse>> GetAllRoutinesAsync(int page = 1, int limit = 50, string? search = null)
    {
        var filter = Builders<Routine>.Filter.Empty;
        if (!string.IsNullOrWhiteSpace(search))
        {
            var q = search.Trim().ToLower();
            filter = Builders<Routine>.Filter.Or(
                Builders<Routine>.Filter.Regex(r => r.Title, new MongoDB.Bson.BsonRegularExpression(q, "i")),
                Builders<Routine>.Filter.Regex(r => r.UserName, new MongoDB.Bson.BsonRegularExpression(q, "i"))
            );
        }

        var routines = await _db.RoutinesCollection
            .Find(filter)
            .SortByDescending(r => r.CreatedAt)
            .Skip((page - 1) * limit)
            .Limit(limit)
            .ToListAsync();

        return routines.Select(AdminRoutineResponse.FromRoutine).ToList();
    }

    public async Task<List<AdminRoutineCommentResponse>?> GetRoutineCommentsAsync(string routineId)
    {
        var routine = await _db.RoutinesCollection
            .Find(r => r.Id == routineId)
            .FirstOrDefaultAsync();

        if (routine == null)
            return null;

        var comments = routine.Comments ?? new List<RoutineComment>();
        if (comments.Count == 0)
            return new List<AdminRoutineCommentResponse>();

        var commenterIds = comments
            .Select(c => c.UserId)
            .Where(id => !string.IsNullOrWhiteSpace(id))
            .Distinct()
            .ToList();

        var users = commenterIds.Count == 0
            ? new List<User>()
            : await _db.UsersCollection
                .Find(u => commenterIds.Contains(u.Id))
                .ToListAsync();

        var profileMap = users.ToDictionary(u => u.Id, u => u.ProfileImageUrl);

        return comments
            .OrderByDescending(c => c.CreatedAt)
            .Select(c => new AdminRoutineCommentResponse
            {
                Id = c.Id,
                UserId = c.UserId,
                UserName = c.UserName,
                Text = c.Text,
                UserProfileImageUrl = profileMap.TryGetValue(c.UserId, out var profile) ? profile : null,
                CreatedAt = c.CreatedAt
            })
            .ToList();
    }

    // ── Bildirim logları ──
    public async Task<List<AdminNotificationLogResponse>> GetNotificationLogsAsync(int page = 1, int limit = 50)
    {
        var logs = await _db.NotificationLogsCollection
            .Find(Builders<NotificationLog>.Filter.Empty)
            .SortByDescending(l => l.SentAt)
            .Skip((page - 1) * limit)
            .Limit(limit)
            .ToListAsync();

        return logs.Select(l => new AdminNotificationLogResponse
        {
            Id = l.Id,
            RecipientUserId = l.RecipientUserId,
            Title = l.Title,
            Body = l.Body,
            Type = l.Type,
            Success = l.Success,
            SentAt = l.SentAt
        }).ToList();
    }

    public async Task<long> GetNotificationLogCountAsync() =>
        await _db.NotificationLogsCollection.CountDocumentsAsync(Builders<NotificationLog>.Filter.Empty);

    // ── Toplu bildirim ──
    public async Task<(int sent, int failed)> BroadcastNotificationAsync(string title, string body)
    {
        var users = await _db.UsersCollection
            .Find(u => u.NotificationsEnabled && u.FcmToken != null && !u.IsBanned)
            .ToListAsync();

        int sent = 0, failed = 0;
        foreach (var user in users)
        {
            if (string.IsNullOrEmpty(user.FcmToken)) continue;
            var success = await _notificationService.SendPushNotificationAsync(
                user.FcmToken, title, body,
                recipientUserId: user.Id, type: "broadcast");
            if (success) sent++; else failed++;
        }
        return (sent, failed);
    }

    public async Task<(int sent, int failed)> SendNotificationAsync(SendNotificationRequest request)
    {
        if (request.Audience == NotificationAudience.SpecificUser)
        {
            if (string.IsNullOrWhiteSpace(request.RecipientUserId))
                return (0, 1);

            var user = await _db.UsersCollection
                .Find(u => u.Id == request.RecipientUserId)
                .FirstOrDefaultAsync();

            if (user == null || user.IsBanned || !user.NotificationsEnabled || string.IsNullOrWhiteSpace(user.FcmToken))
                return (0, 1);

            var (title, body) = SelectLocalizedMessage(user.PreferredLanguage, request);
            var success = await _notificationService.SendPushNotificationAsync(
                user.FcmToken,
                title,
                body,
                recipientUserId: user.Id,
                type: "system");

            return success ? (1, 0) : (0, 1);
        }

        if (request.Audience == NotificationAudience.AdminStaff)
        {
            var targetAdmins = await _db.AdminUsersCollection
                .Find(a => a.IsActive && a.NotificationsEnabled && a.FcmToken != null)
                .ToListAsync();

            int adminSent = 0, adminFailed = 0;
            foreach (var admin in targetAdmins)
            {
                if (string.IsNullOrWhiteSpace(admin.FcmToken))
                    continue;

                var (title, body) = SelectLocalizedMessage(admin.PreferredLanguage, request);
                var success = await _notificationService.SendPushNotificationAsync(
                    admin.FcmToken,
                    title,
                    body,
                    recipientUserId: admin.Id,
                    type: "system");

                if (success) adminSent++; else adminFailed++;
            }

            return (adminSent, adminFailed);
        }

        var targetUsers = await _db.UsersCollection
            .Find(u => u.NotificationsEnabled && u.FcmToken != null && !u.IsBanned)
            .ToListAsync();

        int sent = 0, failed = 0;
        foreach (var user in targetUsers)
        {
            if (string.IsNullOrWhiteSpace(user.FcmToken))
                continue;

            var (title, body) = SelectLocalizedMessage(user.PreferredLanguage, request);
            var success = await _notificationService.SendPushNotificationAsync(
                user.FcmToken,
                title,
                body,
                recipientUserId: user.Id,
                type: "system");

            if (success) sent++; else failed++;
        }

        return (sent, failed);
    }

    // ── Product request listesi ──
    public async Task<List<AdminProductRequestResponse>> GetProductRequestsAsync(string? status = null, int page = 1, int limit = 50)
    {
        var filter = string.IsNullOrWhiteSpace(status)
            ? Builders<ProductRequest>.Filter.Empty
            : Builders<ProductRequest>.Filter.Eq(r => r.Status, status);

        var requests = await _db.ProductRequestsCollection
            .Find(filter)
            .SortByDescending(r => r.CreatedAt)
            .Skip((page - 1) * limit)
            .Limit(limit)
            .ToListAsync();

        return requests.Select(AdminProductRequestResponse.FromRequest).ToList();
    }

    // ── Product request onayla → Product oluştur ──
    public async Task<string?> ApproveProductRequestAsync(string requestId, ApproveProductRequestBody body)
    {
        var request = await _db.ProductRequestsCollection
            .Find(r => r.Id == requestId)
            .FirstOrDefaultAsync();

        if (request == null) return null;

        // İçerikleri parse et (virgülle ayrılmış liste)
        List<string>? ingredients = null;
        if (!string.IsNullOrWhiteSpace(body.IngredientsText))
        {
            ingredients = body.IngredientsText
                .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                .ToList();
        }

        var product = new Product
        {
            Name = body.Name.Trim(),
            Barcode = string.IsNullOrWhiteSpace(body.Barcode) ? null : body.Barcode.Trim(),
            Brand = body.Brand?.Trim(),
            OcrText = body.OcrText,
            ProductIngredients = ingredients,
            ImageUrls = string.IsNullOrWhiteSpace(body.ImageUrl)
                ? null
                : new List<ImageUrlItem> { new() { FileUrl = body.ImageUrl.Trim() } }
        };

        await _db.ProductsCollection.InsertOneAsync(product);

        // Request'i "added" olarak işaretle
        await _db.ProductRequestsCollection.UpdateOneAsync(
            r => r.Id == requestId,
            Builders<ProductRequest>.Update.Set(r => r.Status, "added")
        );

        // Fotoğraf varsa embedding'i arka planda al ve kaydet
        if (!string.IsNullOrWhiteSpace(body.ImageUrl))
        {
            _ = Task.Run(async () =>
            {
                try
                {
                    var (_, _, _) = await EmbedProductAsync(null, body.ImageUrl.Trim(), product.Barcode);
                }
                catch { /* embedding hatası approve'u etkilemesin */ }
            });
        }

        return product.Id;
    }

    // ── Product request sil ──
    public async Task<bool> DeleteProductRequestAsync(string requestId)
    {
        var result = await _db.ProductRequestsCollection.DeleteOneAsync(r => r.Id == requestId);
        return result.DeletedCount > 0;
    }

    // ── Barkoddan fotoğraf linki bul (ortak_urunler.json'dan) ──
    public Task<string?> GetImageByBarcodeAsync(string barcode)
    {
        _barcodeImageMap.TryGetValue(barcode.Trim(), out var imageUrl);
        return Task.FromResult(imageUrl);
    }

    private async Task<string> DownloadImageViaProxyAsync(string imageUrl)
    {
        // image_proxy.py curl_cffi ile CDN bypass yaparak görseli indirir, base64 döndürür
        var scriptPath = Path.Combine(_env.ContentRootPath, "image_proxy.py");
        var psi = new System.Diagnostics.ProcessStartInfo
        {
            FileName = "python3",
            ArgumentList = { scriptPath, imageUrl },
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
        };

        using var process = System.Diagnostics.Process.Start(psi)
            ?? throw new Exception("image_proxy.py başlatılamadı.");

        var stdoutTask = process.StandardOutput.ReadToEndAsync();
        var stderrTask = process.StandardError.ReadToEndAsync();
        await process.WaitForExitAsync();

        var stderr = await stderrTask;
        if (process.ExitCode != 0 || !string.IsNullOrWhiteSpace(stderr))
            throw new Exception($"Görsel indirilemedi: {stderr.Trim()}");

        var b64 = (await stdoutTask).Trim();
        if (string.IsNullOrEmpty(b64))
            throw new Exception("Görsel indirilemedi: boş çıktı.");

        return b64;
    }

    private static void ApplyCdnHeaders(HttpRequestMessage req, string url)
    {
        req.Headers.TryAddWithoutValidation("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36");
        req.Headers.TryAddWithoutValidation("Accept", "image/avif,image/webp,image/apng,image/*,*/*;q=0.8");
        req.Headers.TryAddWithoutValidation("Accept-Language", "tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7");

        if (url.Contains("watsons.com.tr"))
        {
            req.Headers.TryAddWithoutValidation("Referer", "https://www.watsons.com.tr/");
            req.Headers.TryAddWithoutValidation("Origin", "https://www.watsons.com.tr");
        }
        else if (url.Contains("sephora"))
        {
            req.Headers.TryAddWithoutValidation("Referer", "https://www.sephora.com.tr/");
            req.Headers.TryAddWithoutValidation("Origin", "https://www.sephora.com.tr");
        }
        else if (url.Contains("gratis.com"))
            req.Headers.TryAddWithoutValidation("Referer", "https://www.gratis.com/");
        else if (url.Contains("goldenrose"))
            req.Headers.TryAddWithoutValidation("Referer", "https://shop.goldenrose.com.tr/");
        else if (url.Contains("nivea"))
            req.Headers.TryAddWithoutValidation("Referer", "https://www.nivea.com.tr/");
        else if (url.Contains("dermokozmetika"))
            req.Headers.TryAddWithoutValidation("Referer", "https://www.dermokozmetika.com.tr/");
    }

    // ── Görsel (base64 veya URL) → Gemini embedding → MongoDB ──
    public async Task<(bool success, string? message, int dimensions)> EmbedProductAsync(string? imageBase64, string? imageUrl, string? barcode)
    {
        var apiKey = _configuration["GoogleApiKey"];
        if (string.IsNullOrEmpty(apiKey))
            return (false, "GoogleApiKey yapılandırılmamış.", 0);

        string base64;

        if (!string.IsNullOrWhiteSpace(imageBase64))
        {
            base64 = imageBase64;
        }
        else if (!string.IsNullOrWhiteSpace(imageUrl))
        {
            try
            {
                base64 = await DownloadImageViaProxyAsync(imageUrl);
            }
            catch (Exception ex)
            {
                return (false, ex.Message, 0);
            }
        }
        else
        {
            return (false, "imageBase64 veya imageUrl gereklidir.", 0);
        }

        // Gemini Embedding API
        var model = "gemini-embedding-2-preview";
        var url = $"https://generativelanguage.googleapis.com/v1beta/models/{model}:embedContent?key={apiKey}";

        var payload = new
        {
            model = $"models/{model}",
            content = new
            {
                parts = new[] { new { inlineData = new { mimeType = "image/jpeg", data = base64 } } }
            }
        };

        double[]? vector;
        try
        {
            var json = JsonSerializer.Serialize(payload);
            var response = await _httpClient.PostAsync(url, new StringContent(json, Encoding.UTF8, "application/json"));
            if (!response.IsSuccessStatusCode)
            {
                var err = await response.Content.ReadAsStringAsync();
                return (false, $"Gemini API hatası: {response.StatusCode} — {err[..Math.Min(200, err.Length)]}", 0);
            }
            var respJson = await response.Content.ReadAsStringAsync();
            using var doc = JsonDocument.Parse(respJson);
            vector = doc.RootElement
                .GetProperty("embedding")
                .GetProperty("values")
                .EnumerateArray()
                .Select(v => v.GetDouble())
                .ToArray();
        }
        catch (Exception ex)
        {
            return (false, $"Embedding alınamadı: {ex.Message}", 0);
        }

        if (vector == null || vector.Length == 0)
            return (false, "Boş embedding döndü.", 0);

        // MongoDB'de ürünü bul ve embedding'i güncelle
        // Önce barcode ile dene, yoksa image_urls.fileUrl ile eşleştir
        FilterDefinition<Product> filter;
        if (!string.IsNullOrWhiteSpace(barcode))
        {
            filter = Builders<Product>.Filter.Eq(p => p.Barcode, barcode);
        }
        else if (!string.IsNullOrWhiteSpace(imageUrl))
        {
            filter = Builders<Product>.Filter.ElemMatch(
                p => p.ImageUrls,
                Builders<ImageUrlItem>.Filter.Eq(i => i.FileUrl, imageUrl));
        }
        else
        {
            return (false, "Ürünü bulmak için barcode veya imageUrl gereklidir.", vector.Length);
        }

        var update = Builders<Product>.Update.Set(p => p.Embedding, vector.ToList().ConvertAll(v => (double)v));
        var result = await _db.ProductsCollection.UpdateOneAsync(filter, update);

        if (result.MatchedCount == 0)
            return (false, "Ürün MongoDB'de bulunamadı.", vector.Length);

        // Güncel ürünü bul ve in-memory cache'e ekle — restart gerekmez
        var updated = await _db.ProductsCollection
            .Find(filter)
            .Project<Product>(Builders<Product>.Projection.Include(p => p.Id))
            .FirstOrDefaultAsync();
        if (updated?.Id != null)
            _imageSearchService.AddToCache(updated.Id, vector);

        return (true, null, vector.Length);
    }

    // ── Admin yetkisi kontrol ──
    public async Task<bool> IsAdminAsync(string userId)
    {
        var admin = await _db.AdminUsersCollection
            .Find(a => a.Id == userId && a.IsActive)
            .FirstOrDefaultAsync();
        return admin != null;
    }

    private static FilterDefinition<User> BuildUserFilter(string? search, bool? isBanned)
    {
        var filters = new List<FilterDefinition<User>>
        {
            Builders<User>.Filter.Or(
                Builders<User>.Filter.Eq(u => u.IsAdmin, false),
                Builders<User>.Filter.Exists("isAdmin", false)
            )
        };

        if (!string.IsNullOrWhiteSpace(search))
        {
            var q = search.Trim().ToLowerInvariant();
            filters.Add(Builders<User>.Filter.Or(
                Builders<User>.Filter.Regex(u => u.Email, new MongoDB.Bson.BsonRegularExpression(q, "i")),
                Builders<User>.Filter.Regex(u => u.Username, new MongoDB.Bson.BsonRegularExpression(q, "i")),
                Builders<User>.Filter.Regex(u => u.FullName, new MongoDB.Bson.BsonRegularExpression(q, "i"))
            ));
        }

        if (isBanned.HasValue)
            filters.Add(Builders<User>.Filter.Eq(u => u.IsBanned, isBanned.Value));

        return filters.Count == 0
            ? Builders<User>.Filter.Empty
            : Builders<User>.Filter.And(filters);
    }

    private static (string Title, string Body) SelectLocalizedMessage(string? preferredLanguage, SendNotificationRequest request)
    {
        var tr = (
            Title: request.TitleTr?.Trim(),
            Body: request.BodyTr?.Trim()
        );
        var en = (
            Title: request.TitleEn?.Trim(),
            Body: request.BodyEn?.Trim()
        );
        var fallback = (
            Title: request.Title.Trim(),
            Body: request.Body.Trim()
        );

        var preferred = preferredLanguage?.Trim().ToLowerInvariant() ?? "tr";
        if (preferred.StartsWith("tr"))
        {
            if (!string.IsNullOrWhiteSpace(tr.Title) && !string.IsNullOrWhiteSpace(tr.Body))
                return (tr.Title, tr.Body);
            if (!string.IsNullOrWhiteSpace(en.Title) && !string.IsNullOrWhiteSpace(en.Body))
                return (en.Title, en.Body);
            return fallback;
        }

        if (!string.IsNullOrWhiteSpace(en.Title) && !string.IsNullOrWhiteSpace(en.Body))
            return (en.Title, en.Body);
        if (!string.IsNullOrWhiteSpace(tr.Title) && !string.IsNullOrWhiteSpace(tr.Body))
            return (tr.Title, tr.Body);
        return fallback;
    }
}
