using MongoDB.Driver;
using Skincore.Api.Models;

namespace Skincore.Api.Services;

public class UserProfileService
{
    private readonly IMongoCollection<User> _users;
    private readonly IMongoCollection<Product> _products;
    private readonly NotificationService _notificationService;

    public UserProfileService(MongoDbService mongoDbService, NotificationService notificationService)
    {
        _users = mongoDbService.UsersCollection;
        _products = mongoDbService.ProductsCollection;
        _notificationService = notificationService;
    }

    // ==================== PROFİL ====================

    public async Task<UserProfileResponse?> GetProfile(string userId)
    {
        var user = await _users.Find(u => u.Id == userId).FirstOrDefaultAsync();
        if (user == null) return null;

        return MapToProfileResponse(user);
    }

    public async Task<bool> UpdateProfile(string userId, UpdateProfileRequest request)
    {
        var updateDefs = new List<UpdateDefinition<User>>();

        if (request.DisplayName != null)
            updateDefs.Add(Builders<User>.Update.Set(u => u.FullName, request.DisplayName));

        if (request.Bio != null)
            updateDefs.Add(Builders<User>.Update.Set(u => u.Bio, request.Bio));

        if (request.SkinType != null)
        {
            var validSkinTypes = new[] { "Normal", "Kuru", "Yağlı", "Karma", "Hassas", "Akneye Meyilli", "Olgun" };
            if (!validSkinTypes.Contains(request.SkinType))
            {
                // Geçersiz cilt tipi
                return false;
            }
            updateDefs.Add(Builders<User>.Update.Set(u => u.SkinType, request.SkinType));
        }

        if (request.Username != null)
        {
            var sanitizedUsername = request.Username.Trim();
            // Check if username is already taken by someone else (case-insensitive)
            var existingUser = await _users.Find(u => 
                u.Id != userId && 
                u.Username != null && 
                u.Username.ToLower() == sanitizedUsername.ToLower()
            ).FirstOrDefaultAsync();

            if (existingUser != null)
            {
                return false; // Username is already taken
            }
            
            updateDefs.Add(Builders<User>.Update.Set(u => u.Username, sanitizedUsername));
        }

        if (updateDefs.Count == 0)
            return false;

        updateDefs.Add(Builders<User>.Update.Set(u => u.UpdatedAt, DateTime.UtcNow));

        var combinedUpdate = Builders<User>.Update.Combine(updateDefs);
        var result = await _users.UpdateOneAsync(u => u.Id == userId, combinedUpdate);
        return result.ModifiedCount > 0;
    }

    public async Task<bool> IsUsernameAvailable(string username)
    {
        if (string.IsNullOrWhiteSpace(username)) return false;
        
        var sanitizedUsername = username.Trim().ToLower();
        var count = await _users.CountDocumentsAsync(u => 
            u.Username != null && u.Username.ToLower() == sanitizedUsername);
            
        return count == 0;
    }

    // ==================== BİYOGRAFİ ====================

    public async Task<string?> UpdateProfileImage(string userId, IFormFile file, IWebHostEnvironment env)
    {
        var uploadsDir = Path.Combine(env.WebRootPath, "uploads", "profile-images");
        Directory.CreateDirectory(uploadsDir);

        // Delete old image if exists
        var user = await _users.Find(u => u.Id == userId).FirstOrDefaultAsync();
        if (user?.ProfileImageUrl != null)
        {
            var oldFile = Path.Combine(env.WebRootPath, user.ProfileImageUrl.TrimStart('/'));
            if (File.Exists(oldFile)) File.Delete(oldFile);
        }

        var ext = Path.GetExtension(file.FileName).ToLower();
        var fileName = $"{userId}_{DateTime.UtcNow.Ticks}{ext}";
        var filePath = Path.Combine(uploadsDir, fileName);

        using (var stream = new FileStream(filePath, FileMode.Create))
            await file.CopyToAsync(stream);

        var imageUrl = $"/uploads/profile-images/{fileName}";

        var update = Builders<User>.Update
            .Set(u => u.ProfileImageUrl, imageUrl)
            .Set(u => u.UpdatedAt, DateTime.UtcNow);
        await _users.UpdateOneAsync(u => u.Id == userId, update);

        return imageUrl;
    }

    public async Task<bool> UpdateBio(string userId, string? bio)
    {
        var update = Builders<User>.Update
            .Set(u => u.Bio, bio)
            .Set(u => u.UpdatedAt, DateTime.UtcNow);

        var result = await _users.UpdateOneAsync(u => u.Id == userId, update);
        return result.ModifiedCount > 0;
    }

    // ==================== TAKİP ====================

    public async Task<List<FavoriteResponse>?> GetPublicFavorites(string username)
    {
        var user = await _users.Find(u => u.Username != null && u.Username.ToLower() == username.ToLower()).FirstOrDefaultAsync();
        if (user == null) return null;

        var productIds = user.Favorites
            .Select(f => f.ProductId)
            .Where(id => !string.IsNullOrEmpty(id))
            .Distinct()
            .Select(MongoDB.Bson.ObjectId.Parse)
            .ToList();

        var products = new List<Product>();
        if (productIds.Count > 0)
        {
            var productFilter = Builders<Product>.Filter.In("_id", productIds);
            products = await _products.Find(productFilter).ToListAsync();
        }

        return user.Favorites
            .OrderByDescending(f => f.AddedAt)
            .Select(f =>
            {
                var product = products.FirstOrDefault(p => p.Id == f.ProductId);
                var response = MapToFavoriteResponse(f);
                response.ProductImageURL ??= PopularSearchService.ExtractFirstImageUrl(product);
                return response;
            })
            .ToList();
    }

    public async Task<(bool Success, string Message)> FollowUser(string currentUserId, string targetUserId)
    {
        if (currentUserId == targetUserId)
            return (false, "Kendinizi takip edemezsiniz.");

        var target = await _users.Find(u => u.Id == targetUserId).FirstOrDefaultAsync();
        if (target == null)
            return (false, "Kullanıcı bulunamadı.");

        var current = await _users.Find(u => u.Id == currentUserId).FirstOrDefaultAsync();
        if (current == null)
            return (false, "Kullanıcı bulunamadı.");

        if (current.Following.Contains(targetUserId))
            return (false, "Bu kullanıcıyı zaten takip ediyorsunuz.");

        // Add targetUserId to current user's following
        await _users.UpdateOneAsync(
            u => u.Id == currentUserId,
            Builders<User>.Update.AddToSet(u => u.Following, targetUserId)
                .Set(u => u.UpdatedAt, DateTime.UtcNow));

        // Add currentUserId to target user's followers
        await _users.UpdateOneAsync(
            u => u.Id == targetUserId,
            Builders<User>.Update.AddToSet(u => u.Followers, currentUserId)
                .Set(u => u.UpdatedAt, DateTime.UtcNow));

        if (!string.IsNullOrEmpty(target.FcmToken))
        {
            var title = target.PreferredLanguage == "en" ? "New Follower!" : "Yeni Takipçi!";
            var body = target.PreferredLanguage == "en" 
                ? $"{current.Username ?? current.FullName ?? "Someone"} started following you." 
                : $"{current.Username ?? current.FullName ?? "Biri"} seni takip etmeye başladı.";
                
            await _notificationService.SendPushNotificationAsync(target.FcmToken, title, body);
        }

        return (true, "Takip edildi.");
    }

    public async Task<(bool Success, string Message)> UnfollowUser(string currentUserId, string targetUserId)
    {
        var current = await _users.Find(u => u.Id == currentUserId).FirstOrDefaultAsync();
        if (current == null || !current.Following.Contains(targetUserId))
            return (false, "Bu kullanıcıyı takip etmiyorsunuz.");

        await _users.UpdateOneAsync(
            u => u.Id == currentUserId,
            Builders<User>.Update.Pull(u => u.Following, targetUserId)
                .Set(u => u.UpdatedAt, DateTime.UtcNow));

        await _users.UpdateOneAsync(
            u => u.Id == targetUserId,
            Builders<User>.Update.Pull(u => u.Followers, currentUserId)
                .Set(u => u.UpdatedAt, DateTime.UtcNow));

        return (true, "Takipten çıkıldı.");
    }

    public async Task<List<PublicUserProfileResponse>> GetFollowers(string userId)
    {
        var user = await _users.Find(u => u.Id == userId).FirstOrDefaultAsync();
        if (user == null) return new();

        var followers = await _users.Find(u => user.Followers.Contains(u.Id)).ToListAsync();
        // isFollowing: current user (userId) follows this follower back?
        return followers.Select(f => MapToPublicProfileResponse(f, user.Following.Contains(f.Id))).ToList();
    }

    public async Task<List<PublicUserProfileResponse>> GetFollowing(string userId)
    {
        var user = await _users.Find(u => u.Id == userId).FirstOrDefaultAsync();
        if (user == null) return new();

        var following = await _users.Find(u => user.Following.Contains(u.Id)).ToListAsync();
        // isFollowing: always true — these are users the current user follows
        return following.Select(f => MapToPublicProfileResponse(f, true)).ToList();
    }

    public async Task<List<PublicUserProfileResponse>> SearchUsers(string query, string currentUserId, int limit = 20)
    {
        if (string.IsNullOrWhiteSpace(query)) return new();

        var q = query.Trim().ToLower();
        var filter = Builders<User>.Filter.And(
            Builders<User>.Filter.Ne(u => u.Id, currentUserId),
            Builders<User>.Filter.Ne(u => u.Username, null),
            Builders<User>.Filter.Regex(u => u.Username, new MongoDB.Bson.BsonRegularExpression(q, "i"))
        );

        var users = await _users.Find(filter).Limit(limit).ToListAsync();
        return users.Select(u => MapToPublicProfileResponse(u, u.Followers.Contains(currentUserId))).ToList();
    }

    public async Task<PublicUserProfileResponse?> GetPublicProfile(string username, string currentUserId)
    {
        var user = await _users.Find(u => u.Username != null && u.Username.ToLower() == username.ToLower()).FirstOrDefaultAsync();
        if (user == null) return null;

        var isFollowing = user.Followers.Contains(currentUserId);
        return MapToPublicProfileResponse(user, isFollowing);
    }

    // ==================== FAVORİLER ====================

    public async Task<List<FavoriteResponse>> GetFavorites(string userId)
    {
        var user = await _users.Find(u => u.Id == userId).FirstOrDefaultAsync();
        if (user == null) return new List<FavoriteResponse>();

        // Ürün image_urls'lerini çek
        var productIds = user.Favorites
            .Select(f => f.ProductId)
            .Where(id => !string.IsNullOrEmpty(id))
            .Distinct()
            .Select(MongoDB.Bson.ObjectId.Parse)
            .ToList();

        var productFilter = Builders<Product>.Filter.In("_id", productIds);
        var products = await _products.Find(productFilter).ToListAsync();

        return user.Favorites
            .OrderByDescending(f => f.AddedAt)
            .Select(f =>
            {
                var product = products.FirstOrDefault(p => p.Id == f.ProductId);
                var response = MapToFavoriteResponse(f);
                response.ProductImageURL ??= PopularSearchService.ExtractFirstImageUrl(product);
                return response;
            })
            .ToList();
    }

    public async Task<(bool Success, string Message)> AddFavorite(string userId, AddFavoriteRequest request)
    {
        var user = await _users.Find(u => u.Id == userId).FirstOrDefaultAsync();
        if (user == null) return (false, "Kullanıcı bulunamadı.");

        if (user.Favorites.Any(f => f.ProductId == request.ProductId))
            return (false, "Bu ürün zaten favorilerinizde.");

        var favorite = new FavoriteProduct
        {
            ProductId = request.ProductId,
            ProductName = request.ProductName,
            ProductBrand = request.ProductBrand,
            ProductImageURL = request.ProductImageURL,
            AddedAt = DateTime.UtcNow
        };

        var update = Builders<User>.Update
            .Push(u => u.Favorites, favorite)
            .Set(u => u.UpdatedAt, DateTime.UtcNow);

        await _users.UpdateOneAsync(u => u.Id == userId, update);
        return (true, "Favorilere eklendi.");
    }

    public async Task<(bool Success, string Message)> RemoveFavorite(string userId, string productId)
    {
        var update = Builders<User>.Update
            .PullFilter(u => u.Favorites, f => f.ProductId == productId)
            .Set(u => u.UpdatedAt, DateTime.UtcNow);

        var result = await _users.UpdateOneAsync(u => u.Id == userId, update);

        return result.ModifiedCount > 0
            ? (true, "Favorilerden kaldırıldı.")
            : (false, "Ürün favorilerde bulunamadı.");
    }

    public async Task<(bool IsFavorite, string Message)> ToggleFavorite(string userId, AddFavoriteRequest request)
    {
        var user = await _users.Find(u => u.Id == userId).FirstOrDefaultAsync();
        if (user == null) return (false, "Kullanıcı bulunamadı.");

        if (user.Favorites.Any(f => f.ProductId == request.ProductId))
        {
            await RemoveFavorite(userId, request.ProductId);
            return (false, "Favorilerden kaldırıldı.");
        }
        else
        {
            await AddFavorite(userId, request);
            return (true, "Favorilere eklendi.");
        }
    }

    public async Task<bool> IsFavorite(string userId, string productId)
    {
        var filter = Builders<User>.Filter.And(
            Builders<User>.Filter.Eq(u => u.Id, userId),
            Builders<User>.Filter.ElemMatch(u => u.Favorites, f => f.ProductId == productId)
        );

        var count = await _users.CountDocumentsAsync(filter);
        return count > 0;
    }

    // ==================== ARAMA GEÇMİŞİ ====================

    public async Task<List<SearchHistoryResponse>> GetSearchHistory(string userId, int limit = 20)
    {
        var user = await _users.Find(u => u.Id == userId).FirstOrDefaultAsync();
        if (user == null) return new List<SearchHistoryResponse>();

        var items = user.SearchHistory
            .OrderByDescending(s => s.SearchedAt)
            .Take(limit)
            .ToList();

        // Ürün image_urls'lerini çek
        var productIds = items
            .Where(s => !string.IsNullOrEmpty(s.ProductId))
            .Select(s => MongoDB.Bson.ObjectId.Parse(s.ProductId!))
            .Distinct()
            .ToList();

        var products = new List<Product>();
        if (productIds.Count > 0)
        {
            var productFilter = Builders<Product>.Filter.In("_id", productIds);
            products = await _products.Find(productFilter).ToListAsync();
        }

        return items.Select(s =>
        {
            var response = MapToSearchHistoryResponse(s);
            if (!string.IsNullOrEmpty(s.ProductId))
            {
                var product = products.FirstOrDefault(p => p.Id == s.ProductId);
                response.ImageUrl = PopularSearchService.ExtractFirstImageUrl(product);
            }
            return response;
        }).ToList();
    }

    public async Task AddSearchHistory(string userId, AddSearchHistoryRequest request)
    {
        // Aynı query varsa kaldır (tekrar en üste eklenecek)
        var pullUpdate = Builders<User>.Update
            .PullFilter(u => u.SearchHistory, s => s.Query.ToLower() == request.Query.ToLower());
        await _users.UpdateOneAsync(u => u.Id == userId, pullUpdate);

        var item = new SearchHistoryItem
        {
            Query = request.Query,
            ProductId = request.ProductId,
            ProductName = request.ProductName,
            Category = request.Category,
            SearchedAt = DateTime.UtcNow
        };

        // Maximum 50 kayıt tut
        var user = await _users.Find(u => u.Id == userId).FirstOrDefaultAsync();
        if (user != null && user.SearchHistory.Count >= 50)
        {
            var oldest = user.SearchHistory.OrderBy(s => s.SearchedAt).First();
            var removeOldest = Builders<User>.Update
                .PullFilter(u => u.SearchHistory, s => s.Id == oldest.Id);
            await _users.UpdateOneAsync(u => u.Id == userId, removeOldest);
        }

        var update = Builders<User>.Update
            .Push(u => u.SearchHistory, item)
            .Set(u => u.UpdatedAt, DateTime.UtcNow);

        await _users.UpdateOneAsync(u => u.Id == userId, update);
    }

    public async Task<bool> DeleteSearchHistoryItem(string userId, string itemId)
    {
        var update = Builders<User>.Update
            .PullFilter(u => u.SearchHistory, s => s.Id == itemId)
            .Set(u => u.UpdatedAt, DateTime.UtcNow);

        var result = await _users.UpdateOneAsync(u => u.Id == userId, update);
        return result.ModifiedCount > 0;
    }

    public async Task ClearSearchHistory(string userId)
    {
        var update = Builders<User>.Update
            .Set(u => u.SearchHistory, new List<SearchHistoryItem>())
            .Set(u => u.UpdatedAt, DateTime.UtcNow);

        await _users.UpdateOneAsync(u => u.Id == userId, update);
    }

    // ==================== MAPPERS ====================

    private static UserProfileResponse MapToProfileResponse(User user) => new()
    {
        Id = user.Id,
        Email = user.Email,
        FullName = user.FullName,
        SkinType = user.SkinType,
        Username = user.Username,
        Bio = user.Bio,
        ProfileImageUrl = user.ProfileImageUrl,
        FollowerCount = user.Followers.Count,
        FollowingCount = user.Following.Count,
        CreatedAt = user.CreatedAt,
        UpdatedAt = user.UpdatedAt
    };

    private static PublicUserProfileResponse MapToPublicProfileResponse(User user, bool isFollowing) => new()
    {
        Id = user.Id,
        FullName = user.FullName,
        Username = user.Username,
        SkinType = user.SkinType,
        Bio = user.Bio,
        ProfileImageUrl = user.ProfileImageUrl,
        FollowerCount = user.Followers.Count,
        FollowingCount = user.Following.Count,
        IsFollowing = isFollowing
    };

    private static FavoriteResponse MapToFavoriteResponse(FavoriteProduct f) => new()
    {
        Id = f.Id,
        ProductId = f.ProductId,
        ProductName = f.ProductName,
        ProductBrand = f.ProductBrand,
        ProductImageURL = f.ProductImageURL,
        AddedAt = f.AddedAt
    };

    private static SearchHistoryResponse MapToSearchHistoryResponse(SearchHistoryItem s) => new()
    {
        Id = s.Id,
        Query = s.Query,
        ProductId = s.ProductId,
        ProductName = s.ProductName,
        Category = s.Category,
        SearchedAt = s.SearchedAt
    };
}
