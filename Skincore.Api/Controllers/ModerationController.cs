using System.Security.Claims;
using Microsoft.AspNetCore.Mvc;
using MongoDB.Driver;
using Skincore.Api.Models;
using Skincore.Api.Services;

namespace Skincore.Api.Controllers;

[ApiController]
[Route("api/moderation")]
public class ModerationController : ControllerBase
{
    private readonly MongoDbService _db;
    private readonly IWebHostEnvironment _env;
    private readonly AdminService _adminService;
    private static readonly string[] AllowedExtensions = [".jpg", ".jpeg", ".png", ".heic"];

    public ModerationController(MongoDbService db, IWebHostEnvironment env, AdminService adminService)
    {
        _db = db;
        _env = env;
        _adminService = adminService;
    }

    private string? GetUserId() => User.FindFirst(ClaimTypes.NameIdentifier)?.Value;

    private async Task<bool> CheckAdmin()
    {
        var userId = GetUserId();
        if (string.IsNullOrEmpty(userId)) return false;
        return await _adminService.IsAdminAsync(userId);
    }

    // ───────────────────────────────────────────
    // KULLANICI: Moderasyon talebi oluştur
    // POST /api/moderation/products/{productId}
    // ───────────────────────────────────────────
    [HttpPost("products/{productId}")]
    [Consumes("multipart/form-data")]
    public async Task<IActionResult> Submit(
        string productId,
        [FromForm] string? note,
        IFormFile? frontImage,
        IFormFile? backImage)
    {
        var userId = GetUserId();
        if (string.IsNullOrEmpty(userId))
            return Unauthorized(new MessageResponse { Message = "Giriş yapmanız gerekiyor." });

        var product = await _db.ProductsCollection
            .Find(p => p.Id == productId)
            .FirstOrDefaultAsync();
        if (product == null)
            return NotFound(new MessageResponse { Message = "Ürün bulunamadı." });

        var uploadDir = Path.Combine(_env.WebRootPath, "uploads", "moderation");
        Directory.CreateDirectory(uploadDir);

        var frontImageUrl = await SaveImageAsync(frontImage, uploadDir);
        var backImageUrl = await SaveImageAsync(backImage, uploadDir);

        var request = new ModerationRequest
        {
            ProductId = productId,
            UserId = userId,
            Note = note?.Trim(),
            FrontImageUrl = frontImageUrl,
            BackImageUrl = backImageUrl,
            Status = "pending",
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        await _db.ModerationRequestsCollection.InsertOneAsync(request);

        return Ok(new MessageResponse { Message = "Moderasyon talebiniz alındı. En kısa sürede inceleyeceğiz." });
    }

    // ───────────────────────────────────────────
    // ADMIN: Tüm talepleri listele
    // GET /api/moderation/admin?status=pending&page=1&limit=50
    // ───────────────────────────────────────────
    [HttpGet("admin")]
    public async Task<IActionResult> GetAll(
        [FromQuery] string? status = null,
        [FromQuery] int page = 1,
        [FromQuery] int limit = 50)
    {
        if (!await CheckAdmin()) return Forbid();

        var filter = string.IsNullOrWhiteSpace(status)
            ? Builders<ModerationRequest>.Filter.Empty
            : Builders<ModerationRequest>.Filter.Eq(r => r.Status, status.Trim().ToLower());

        var total = await _db.ModerationRequestsCollection.CountDocumentsAsync(filter);
        var requests = await _db.ModerationRequestsCollection
            .Find(filter)
            .SortByDescending(r => r.CreatedAt)
            .Skip((page - 1) * limit)
            .Limit(limit)
            .ToListAsync();

        // Ürün ve kullanıcı bilgilerini zenginleştir
        var productIds = requests.Select(r => r.ProductId).Distinct().ToList();
        var userIds = requests.Select(r => r.UserId).Distinct().ToList();

        var products = await _db.ProductsCollection
            .Find(p => productIds.Contains(p.Id))
            .ToListAsync();
        var users = await _db.UsersCollection
            .Find(u => userIds.Contains(u.Id))
            .ToListAsync();

        var productMap = products.ToDictionary(p => p.Id!, p => p);
        var userMap = users.ToDictionary(u => u.Id, u => u);

        var data = requests.Select(r => new AdminModerationRequestResponse
        {
            Id = r.Id,
            ProductId = r.ProductId,
            ProductName = productMap.TryGetValue(r.ProductId, out var prod) ? prod.Name : null,
            ProductBrand = prod?.Brand,
            UserId = r.UserId,
            UserName = userMap.TryGetValue(r.UserId, out var user) ? (user.Username ?? user.FullName) : null,
            Note = r.Note,
            FrontImageUrl = r.FrontImageUrl,
            BackImageUrl = r.BackImageUrl,
            Status = r.Status,
            AdminNote = r.AdminNote,
            CreatedAt = r.CreatedAt,
            UpdatedAt = r.UpdatedAt
        }).ToList();

        return Ok(new { data, total, page, limit });
    }

    // ───────────────────────────────────────────
    // ADMIN: Talebi güncelle (status + adminNote + ürün alanları)
    // PUT /api/moderation/admin/{id}
    // ───────────────────────────────────────────
    [HttpPut("admin/{id}")]
    public async Task<IActionResult> Update(string id, [FromBody] AdminUpdateModerationRequest body)
    {
        if (!await CheckAdmin()) return Forbid();

        var existing = await _db.ModerationRequestsCollection
            .Find(r => r.Id == id)
            .FirstOrDefaultAsync();
        if (existing == null)
            return NotFound(new MessageResponse { Message = "Talep bulunamadı." });

        var updates = new List<UpdateDefinition<ModerationRequest>>
        {
            Builders<ModerationRequest>.Update.Set(r => r.UpdatedAt, DateTime.UtcNow)
        };

        if (!string.IsNullOrWhiteSpace(body.Status))
            updates.Add(Builders<ModerationRequest>.Update.Set(r => r.Status, body.Status.Trim().ToLower()));

        if (body.AdminNote != null)
            updates.Add(Builders<ModerationRequest>.Update.Set(r => r.AdminNote, body.AdminNote.Trim()));

        await _db.ModerationRequestsCollection.UpdateOneAsync(
            r => r.Id == id,
            Builders<ModerationRequest>.Update.Combine(updates));

        return Ok(new MessageResponse { Message = "Talep güncellendi." });
    }

    // ───────────────────────────────────────────
    // ADMIN: Talebi sil
    // DELETE /api/moderation/admin/{id}
    // ───────────────────────────────────────────
    [HttpDelete("admin/{id}")]
    public async Task<IActionResult> Delete(string id)
    {
        if (!await CheckAdmin()) return Forbid();
        var result = await _db.ModerationRequestsCollection.DeleteOneAsync(r => r.Id == id);
        if (result.DeletedCount == 0)
            return NotFound(new MessageResponse { Message = "Talep bulunamadı." });
        return Ok(new MessageResponse { Message = "Talep silindi." });
    }

    // ───────────────────────────────────────────
    private async Task<string?> SaveImageAsync(IFormFile? file, string uploadDir)
    {
        if (file == null || file.Length == 0) return null;
        var extension = Path.GetExtension(file.FileName).ToLowerInvariant();
        if (!AllowedExtensions.Contains(extension)) return null;

        var fileName = $"{Guid.NewGuid()}{extension}";
        var filePath = Path.Combine(uploadDir, fileName);

        await using var stream = new FileStream(filePath, FileMode.Create);
        await file.CopyToAsync(stream);

        var baseUrl = $"{Request.Scheme}://{Request.Host}{Request.PathBase}";
        return $"{baseUrl}/uploads/moderation/{fileName}";
    }
}
