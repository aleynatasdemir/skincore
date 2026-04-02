using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Skincore.Api.Models;
using Skincore.Api.Services;

namespace Skincore.Api.Controllers;

[ApiController]
[Route("api/admin")]
[Authorize]
public class AdminController : ControllerBase
{
    private readonly AdminService _adminService;
    private readonly GoogleVisionOcrService _googleVisionOcrService;

    public AdminController(AdminService adminService, GoogleVisionOcrService googleVisionOcrService)
    {
        _adminService = adminService;
        _googleVisionOcrService = googleVisionOcrService;
    }

    private async Task<bool> CheckAdmin()
    {
        var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (string.IsNullOrEmpty(userId)) return false;
        return await _adminService.IsAdminAsync(userId);
    }

    // ───────────────────────────────────────────
    // KULLANICILAR
    // ───────────────────────────────────────────

    /// <summary>GET /api/admin/users — Tüm kullanıcıları listele</summary>
    [HttpGet("users")]
    public async Task<IActionResult> GetUsers(
        [FromQuery] int page = 1,
        [FromQuery] int limit = 50,
        [FromQuery] string? search = null,
        [FromQuery] string? status = null)
    {
        if (!await CheckAdmin()) return Forbid();

        bool? isBanned = status?.Trim().ToLowerInvariant() switch
        {
            "active" => false,
            "banned" => true,
            _ => null
        };

        var users = await _adminService.GetAllUsersAsync(page, limit, search, isBanned);
        var total = await _adminService.GetUserCountAsync(search, isBanned);
        return Ok(new { data = users, total, page, limit });
    }

    /// <summary>PUT /api/admin/users/{id}/ban — Kullanıcıyı banla</summary>
    [HttpPut("users/{id}/ban")]
    public async Task<IActionResult> BanUser(string id, [FromBody] BanRequest request)
    {
        if (!await CheckAdmin()) return Forbid();
        var success = await _adminService.BanUserAsync(id, request.Reason);
        if (!success) return NotFound(new MessageResponse { Message = "Kullanıcı bulunamadı." });
        return Ok(new MessageResponse { Message = "Kullanıcı banlandı." });
    }

    /// <summary>PUT /api/admin/users/{id}/unban — Banı kaldır</summary>
    [HttpPut("users/{id}/unban")]
    public async Task<IActionResult> UnbanUser(string id)
    {
        if (!await CheckAdmin()) return Forbid();
        var success = await _adminService.UnbanUserAsync(id);
        if (!success) return NotFound(new MessageResponse { Message = "Kullanıcı bulunamadı." });
        return Ok(new MessageResponse { Message = "Ban kaldırıldı." });
    }

    // ───────────────────────────────────────────
    // RUTİNLER
    // ───────────────────────────────────────────

    /// <summary>GET /api/admin/routines — Tüm rutinleri listele</summary>
    [HttpGet("routines")]
    public async Task<IActionResult> GetRoutines([FromQuery] int page = 1, [FromQuery] int limit = 50, [FromQuery] string? search = null)
    {
        if (!await CheckAdmin()) return Forbid();
        var routines = await _adminService.GetAllRoutinesAsync(page, limit, search);
        return Ok(new { data = routines, page, limit });
    }

    /// <summary>GET /api/admin/routines/{id}/comments — Rutinin yorumlarını listele</summary>
    [HttpGet("routines/{id}/comments")]
    public async Task<IActionResult> GetRoutineComments(string id)
    {
        if (!await CheckAdmin()) return Forbid();
        var comments = await _adminService.GetRoutineCommentsAsync(id);
        if (comments == null) return NotFound(new MessageResponse { Message = "Rutin bulunamadı." });
        return Ok(new { data = comments, total = comments.Count });
    }

    /// <summary>DELETE /api/admin/routines/{id} — Rutini sil</summary>
    [HttpDelete("routines/{id}")]
    public async Task<IActionResult> DeleteRoutine(string id)
    {
        if (!await CheckAdmin()) return Forbid();
        var success = await _adminService.DeleteRoutineAsync(id);
        if (!success) return NotFound(new MessageResponse { Message = "Rutin bulunamadı." });
        return Ok(new MessageResponse { Message = "Rutin silindi." });
    }

    /// <summary>DELETE /api/admin/routines/{routineId}/comments/{commentId} — Yorum sil</summary>
    [HttpDelete("routines/{routineId}/comments/{commentId}")]
    public async Task<IActionResult> DeleteComment(string routineId, string commentId)
    {
        if (!await CheckAdmin()) return Forbid();
        var success = await _adminService.DeleteCommentAsync(routineId, commentId);
        if (!success) return NotFound(new MessageResponse { Message = "Yorum bulunamadı." });
        return Ok(new MessageResponse { Message = "Yorum silindi." });
    }

    // ───────────────────────────────────────────
    // BİLDİRİMLER
    // ───────────────────────────────────────────

    /// <summary>GET /api/admin/notifications — Gönderilen bildirim logları</summary>
    [HttpGet("notifications")]
    public async Task<IActionResult> GetNotificationLogs([FromQuery] int page = 1, [FromQuery] int limit = 50)
    {
        if (!await CheckAdmin()) return Forbid();
        var logs = await _adminService.GetNotificationLogsAsync(page, limit);
        var total = await _adminService.GetNotificationLogCountAsync();
        return Ok(new { data = logs, total, page, limit });
    }

    /// <summary>POST /api/admin/notifications/broadcast — Tüm kullanıcılara bildirim gönder</summary>
    [HttpPost("notifications/broadcast")]
    public async Task<IActionResult> BroadcastNotification([FromBody] BroadcastNotificationRequest request)
    {
        if (!await CheckAdmin()) return Forbid();
        if (string.IsNullOrWhiteSpace(request.Title) || string.IsNullOrWhiteSpace(request.Body))
            return BadRequest(new MessageResponse { Message = "Başlık ve içerik gereklidir." });

        var (sent, failed) = await _adminService.BroadcastNotificationAsync(request.Title, request.Body);
        return Ok(new { message = $"{sent} kullanıcıya gönderildi, {failed} başarısız.", sent, failed });
    }

    /// <summary>POST /api/admin/notifications/send — Hedefli veya toplu bildirim gönder</summary>
    [HttpPost("notifications/send")]
    public async Task<IActionResult> SendNotification([FromBody] SendNotificationRequest request)
    {
        if (!await CheckAdmin()) return Forbid();

        var hasDefault = !string.IsNullOrWhiteSpace(request.Title) && !string.IsNullOrWhiteSpace(request.Body);
        var hasTr = !string.IsNullOrWhiteSpace(request.TitleTr) && !string.IsNullOrWhiteSpace(request.BodyTr);
        var hasEn = !string.IsNullOrWhiteSpace(request.TitleEn) && !string.IsNullOrWhiteSpace(request.BodyEn);
        if (!hasDefault && !hasTr && !hasEn)
            return BadRequest(new MessageResponse { Message = "En az bir dil için başlık ve içerik gereklidir." });

        if (!hasDefault)
        {
            request.Title = request.TitleTr?.Trim() ?? request.TitleEn?.Trim() ?? "";
            request.Body = request.BodyTr?.Trim() ?? request.BodyEn?.Trim() ?? "";
        }

        var audience = request.Audience?.Trim().ToLowerInvariant() ?? NotificationAudience.AllUsers;
        request.Audience = audience;

        if (audience == NotificationAudience.SpecificUser && string.IsNullOrWhiteSpace(request.RecipientUserId))
            return BadRequest(new MessageResponse { Message = "Belirli kullanıcı seçildiyse recipientUserId zorunludur." });

        var (sent, failed) = await _adminService.SendNotificationAsync(request);
        return Ok(new { message = $"{sent} kullanıcıya gönderildi, {failed} başarısız.", sent, failed });
    }

    /// <summary>POST /api/admin/ocr/extract — Google Vision ile OCR</summary>
    [HttpPost("ocr/extract")]
    public async Task<IActionResult> ExtractOcr([FromBody] OcrExtractRequest request, CancellationToken cancellationToken)
    {
        if (!await CheckAdmin()) return Forbid();
        if (string.IsNullOrWhiteSpace(request.ImageUrl))
            return BadRequest(new MessageResponse { Message = "Resim URL'si gereklidir." });

        var (success, message, data) = await _googleVisionOcrService
            .ExtractTextFromImageUrlAsync(request.ImageUrl, cancellationToken);

        if (!success || data == null)
            return BadRequest(new MessageResponse { Message = message });

        return Ok(data);
    }

    // ───────────────────────────────────────────
    // ÜRÜN TALEPLERİ
    // ───────────────────────────────────────────

    /// <summary>GET /api/admin/product-requests — Ürün taleplerini listele</summary>
    [HttpGet("product-requests")]
    public async Task<IActionResult> GetProductRequests([FromQuery] string? status = null, [FromQuery] int page = 1, [FromQuery] int limit = 50)
    {
        if (!await CheckAdmin()) return Forbid();
        var requests = await _adminService.GetProductRequestsAsync(status, page, limit);
        return Ok(new { data = requests, page, limit });
    }

    /// <summary>POST /api/admin/product-requests/{id}/approve — OCR text ile ürünü DB'ye ekle</summary>
    [HttpPost("product-requests/{id}/approve")]
    public async Task<IActionResult> ApproveProductRequest(string id, [FromBody] ApproveProductRequestBody body)
    {
        if (!await CheckAdmin()) return Forbid();
        if (string.IsNullOrWhiteSpace(body.Name))
            return BadRequest(new MessageResponse { Message = "Ürün adı gereklidir." });

        var productId = await _adminService.ApproveProductRequestAsync(id, body);
        if (productId == null) return NotFound(new MessageResponse { Message = "Talep bulunamadı." });

        return Ok(new { message = "Ürün veritabanına eklendi.", productId });
    }

    /// <summary>DELETE /api/admin/product-requests/{id} — Talebi sil</summary>
    [HttpDelete("product-requests/{id}")]
    public async Task<IActionResult> DeleteProductRequest(string id)
    {
        if (!await CheckAdmin()) return Forbid();
        var success = await _adminService.DeleteProductRequestAsync(id);
        if (!success) return NotFound(new MessageResponse { Message = "Talep bulunamadı." });
        return Ok(new MessageResponse { Message = "Talep silindi." });
    }

    // ───────────────────────────────────────────
    // ÜRÜN GÖRSEL / EMBEDDING
    // ───────────────────────────────────────────

    /// <summary>GET /api/admin/products/image-by-barcode?barcode=xxx — Barkoddan fotoğraf linki</summary>
    [HttpGet("products/image-by-barcode")]
    public async Task<IActionResult> GetImageByBarcode([FromQuery] string barcode)
    {
        if (!await CheckAdmin()) return Forbid();
        if (string.IsNullOrWhiteSpace(barcode))
            return BadRequest(new MessageResponse { Message = "Barcode parametresi gereklidir." });

        var imageUrl = await _adminService.GetImageByBarcodeAsync(barcode.Trim());
        if (imageUrl == null)
            return NotFound(new MessageResponse { Message = "Bu barkod için fotoğraf bulunamadı." });

        return Ok(new { imageUrl });
    }

    /// <summary>POST /api/admin/products/embed — Görsel URL → Gemini embedding → MongoDB</summary>
    [HttpPost("products/embed")]
    public async Task<IActionResult> EmbedProduct([FromBody] EmbedProductRequest request)
    {
        if (!await CheckAdmin()) return Forbid();
        if (string.IsNullOrWhiteSpace(request.ImageBase64) && string.IsNullOrWhiteSpace(request.ImageUrl))
            return BadRequest(new MessageResponse { Message = "imageBase64 veya imageUrl gereklidir." });

        var (success, message, dimensions) = await _adminService.EmbedProductAsync(request.ImageBase64, request.ImageUrl, request.Barcode);
        if (!success)
            return BadRequest(new MessageResponse { Message = message ?? "Embedding başarısız." });

        return Ok(new { message = "Embedding kaydedildi.", dimensions });
    }
}
