using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Skincore.Api.Models;
using Skincore.Api.Services;

namespace Skincore.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class RoutinesController : ControllerBase
{
    private readonly SocialRoutinesService _routinesService;

    public RoutinesController(SocialRoutinesService routinesService)
    {
        _routinesService = routinesService;
    }

    private string GetUserId() =>
        User.FindFirstValue(ClaimTypes.NameIdentifier)
        ?? throw new UnauthorizedAccessException();

    /// <summary>
    /// GET /api/routines?limit=20&search=...
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> GetFeed([FromQuery] int limit = 20, [FromQuery] string? search = null)
    {
        var userId = GetUserId();
        var feed = await _routinesService.GetFeed(userId, limit, search);
        return Ok(feed);
    }

    /// <summary>
    /// GET /api/routines/my
    /// </summary>
    [HttpGet("my")]
    public async Task<IActionResult> GetMyRoutines()
    {
        var userId = GetUserId();
        var routines = await _routinesService.GetRoutinesByUserId(userId);
        return Ok(routines);
    }

    /// <summary>
    /// GET /api/routines/favorites - kendi beğenilen rutinler
    /// </summary>
    [HttpGet("favorites")]
    public async Task<IActionResult> GetFavoriteRoutines()
    {
        var userId = GetUserId();
        var routines = await _routinesService.GetLikedRoutines(userId, userId);
        return Ok(routines);
    }

    /// <summary>
    /// GET /api/routines/user/{userId}/favorites - başkasının beğenilen rutinleri
    /// </summary>
    [HttpGet("user/{userId}/favorites")]
    public async Task<IActionResult> GetUserFavoriteRoutines(string userId)
    {
        var currentUserId = GetUserId();
        var routines = await _routinesService.GetLikedRoutines(userId, currentUserId);
        return Ok(routines);
    }

    /// <summary>
    /// GET /api/routines/user/{userId}
    /// </summary>
    [HttpGet("user/{userId}")]
    public async Task<IActionResult> GetByUserId(string userId)
    {
        var currentUserId = GetUserId();
        var routines = await _routinesService.GetRoutinesByUserId(userId, currentUserId);
        return Ok(routines);
    }

    /// <summary>
    /// GET /api/routines/{id}
    /// </summary>
    [HttpGet("{id}")]
    public async Task<IActionResult> GetById(string id)
    {
        var userId = GetUserId();
        var routine = await _routinesService.GetById(id, userId);

        if (routine == null)
            return NotFound(new MessageResponse { Message = "Rutin bulunamadı." });

        return Ok(routine);
    }

    /// <summary>
    /// POST /api/routines
    /// </summary>
    [HttpPost]
    public async Task<IActionResult> CreateRoutine([FromBody] CreateRoutineRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Title))
            return BadRequest(new MessageResponse { Message = "Rutin başlığı boş olamaz." });

        var userId = GetUserId();
        var routine = await _routinesService.CreateRoutine(userId, request);
        return Ok(routine);
    }

    /// <summary>
    /// DELETE /api/routines/{id}
    /// </summary>
    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteRoutine(string id)
    {
        var userId = GetUserId();
        var success = await _routinesService.DeleteRoutine(id, userId);
        if (!success)
            return NotFound(new MessageResponse { Message = "Rutin bulunamadı veya silme yetkiniz yok." });
        return Ok(new MessageResponse { Message = "Rutin silindi." });
    }

    /// <summary>
    /// POST /api/routines/{id}/comments
    /// </summary>
    [HttpPost("{id}/comments")]
    public async Task<IActionResult> AddComment(string id, [FromBody] AddRoutineCommentRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Text))
            return BadRequest(new MessageResponse { Message = "Yorum boş olamaz." });

        var userId = GetUserId();
        var comment = await _routinesService.AddComment(userId, id, request.Text);

        if (comment == null)
            return NotFound(new MessageResponse { Message = "Rutin bulunamadı." });

        return Ok(comment);
    }

    /// <summary>
    /// POST /api/routines/{id}/likes/toggle
    /// </summary>
    [HttpPost("{id}/likes/toggle")]
    public async Task<IActionResult> ToggleLike(string id)
    {
        var userId = GetUserId();
        var result = await _routinesService.ToggleLike(userId, id);

        if (result == null)
            return NotFound(new MessageResponse { Message = "Rutin bulunamadı." });

        return Ok(result);
    }

    /// <summary>
    /// POST /api/routines/upload-image
    /// </summary>
    [HttpPost("upload-image")]
    public async Task<IActionResult> UploadImage(IFormFile file)
    {
        if (file == null || file.Length == 0)
            return BadRequest(new MessageResponse { Message = "Dosya seçilmedi." });

        var allowedExtensions = new[] { ".jpg", ".jpeg", ".png", ".heic" };
        var extension = Path.GetExtension(file.FileName).ToLower();
        if (!allowedExtensions.Contains(extension))
            return BadRequest(new MessageResponse { Message = "Geçersiz dosya formatı." });

        var fileName = $"{Guid.NewGuid()}{extension}";
        var path = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "uploads", "routines", fileName);

        using (var stream = new FileStream(path, FileMode.Create))
        {
            await file.CopyToAsync(stream);
        }

        var baseUrl = $"{Request.Scheme}://{Request.Host}{Request.PathBase}";
        var imageUrl = $"{baseUrl}/uploads/routines/{fileName}";

        return Ok(new { ImageUrl = imageUrl });
    }
}
