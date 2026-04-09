using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Skincore.Api.Models;
using Skincore.Api.Services;

namespace Skincore.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class UserProfileController : ControllerBase
{
    private readonly UserProfileService _profileService;
    private readonly IWebHostEnvironment _env;

    public UserProfileController(UserProfileService profileService, IWebHostEnvironment env)
    {
        _profileService = profileService;
        _env = env;
    }

    private string GetUserId() =>
        User.FindFirstValue(ClaimTypes.NameIdentifier)
        ?? throw new UnauthorizedAccessException();

    // ==================== PROFİL ====================

    /// <summary>
    /// GET /api/userprofile - Kullanıcı profilini getir
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> GetProfile()
    {
        var userId = GetUserId();
        var profile = await _profileService.GetProfile(userId);

        if (profile == null)
            return NotFound(new MessageResponse { Message = "Kullanıcı bulunamadı." });

        return Ok(profile);
    }

    /// <summary>
    /// PUT /api/userprofile - Profili güncelle (displayName, skinType, username, vb.)
    /// </summary>
    [HttpPut]
    public async Task<IActionResult> UpdateProfile([FromBody] UpdateProfileRequest request)
    {
        var userId = GetUserId();
        var result = await _profileService.UpdateProfile(userId, request);

        if (!result)
            return BadRequest(new MessageResponse { Message = "Profil güncellenemedi. Cilt tipi geçersiz veya kullanıcı adı daha önceden alınmış olabilir." });

        return Ok(new MessageResponse { Message = "Profil güncellendi." });
    }

    /// <summary>
    /// POST /api/userprofile/check-username - Kullanıcı adı uygunluğunu kontrol et
    /// </summary>
    [HttpPost("check-username")]
    public async Task<IActionResult> CheckUsername([FromBody] CheckUsernameRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Username))
            return BadRequest(new MessageResponse { Message = "Kullanıcı adı boş olamaz." });

        var isAvailable = await _profileService.IsUsernameAvailable(request.Username);

        return Ok(new { isAvailable, message = isAvailable ? "Kullanıcı adı kullanılabilir." : "Bu kullanıcı adı zaten alınmış." });
    }

    /// <summary>
    /// POST /api/userprofile/profile-image - Profil fotoğrafı yükle
    /// </summary>
    [HttpPost("profile-image")]
    public async Task<IActionResult> UploadProfileImage(IFormFile file)
    {
        if (file == null || file.Length == 0)
            return BadRequest(new MessageResponse { Message = "Dosya seçilmedi." });

        var allowedTypes = new[] { "image/jpeg", "image/png", "image/webp" };
        if (!allowedTypes.Contains(file.ContentType.ToLower()))
            return BadRequest(new MessageResponse { Message = "Sadece JPEG, PNG veya WebP yüklenebilir." });

        if (file.Length > 5 * 1024 * 1024)
            return BadRequest(new MessageResponse { Message = "Dosya boyutu 5MB'ı geçemez." });

        var userId = GetUserId();
        var imageUrl = await _profileService.UpdateProfileImage(userId, file, _env);

        if (imageUrl == null)
            return StatusCode(500, new MessageResponse { Message = "Yükleme başarısız." });

        return Ok(new { imageUrl });
    }

    /// <summary>
    /// PUT /api/userprofile/bio - Biyografiyi güncelle
    /// </summary>
    [HttpPut("bio")]
    public async Task<IActionResult> UpdateBio([FromBody] UpdateBioRequest request)
    {
        var userId = GetUserId();
        await _profileService.UpdateBio(userId, request.Bio);
        return Ok(new MessageResponse { Message = "Biyografi güncellendi." });
    }

    // ==================== TAKİP ====================

    /// <summary>
    /// POST /api/userprofile/follow/{targetUserId} - Kullanıcıyı takip et
    /// </summary>
    [HttpPost("follow/{targetUserId}")]
    public async Task<IActionResult> Follow(string targetUserId)
    {
        var userId = GetUserId();
        var (success, message) = await _profileService.FollowUser(userId, targetUserId);

        if (!success)
            return BadRequest(new MessageResponse { Message = message });

        return Ok(new MessageResponse { Message = message });
    }

    /// <summary>
    /// DELETE /api/userprofile/follow/{targetUserId} - Takipten çık
    /// </summary>
    [HttpDelete("follow/{targetUserId}")]
    public async Task<IActionResult> Unfollow(string targetUserId)
    {
        var userId = GetUserId();
        var (success, message) = await _profileService.UnfollowUser(userId, targetUserId);

        if (!success)
            return BadRequest(new MessageResponse { Message = message });

        return Ok(new MessageResponse { Message = message });
    }

    /// <summary>
    /// GET /api/userprofile/followers - Takipçilerimi getir
    /// </summary>
    [HttpGet("followers")]
    public async Task<IActionResult> GetFollowers()
    {
        var userId = GetUserId();
        var followers = await _profileService.GetFollowers(userId);
        return Ok(followers);
    }

    /// <summary>
    /// GET /api/userprofile/following - Takip ettiklerimi getir
    /// </summary>
    [HttpGet("following")]
    public async Task<IActionResult> GetFollowing()
    {
        var userId = GetUserId();
        var following = await _profileService.GetFollowing(userId);
        return Ok(following);
    }

    /// <summary>
    /// GET /api/userprofile/public/{username}/followers - Kullanıcının takipçilerini getir
    /// </summary>
    [HttpGet("public/{username}/followers")]
    public async Task<IActionResult> GetPublicFollowers(string username)
    {
        var currentUserId = GetUserId();
        var followers = await _profileService.GetPublicFollowers(username, currentUserId);
        if (followers == null)
            return NotFound(new MessageResponse { Message = "Kullanıcı bulunamadı." });
        return Ok(followers);
    }

    /// <summary>
    /// GET /api/userprofile/public/{username}/following - Kullanıcının takip ettiklerini getir
    /// </summary>
    [HttpGet("public/{username}/following")]
    public async Task<IActionResult> GetPublicFollowing(string username)
    {
        var currentUserId = GetUserId();
        var following = await _profileService.GetPublicFollowing(username, currentUserId);
        if (following == null)
            return NotFound(new MessageResponse { Message = "Kullanıcı bulunamadı." });
        return Ok(following);
    }

    /// <summary>
    /// GET /api/userprofile/public/{username}/favorites - Kullanıcının favorilerini getir
    /// </summary>
    [HttpGet("public/{username}/favorites")]
    public async Task<IActionResult> GetPublicFavorites(string username)
    {
        var favorites = await _profileService.GetPublicFavorites(username);
        if (favorites == null)
            return NotFound(new MessageResponse { Message = "Kullanıcı bulunamadı." });
        return Ok(favorites);
    }

    /// <summary>
    /// GET /api/userprofile/search?query=xxx - Kullanıcı ara
    /// </summary>
    [HttpGet("search")]
    public async Task<IActionResult> SearchUsers([FromQuery] string query, [FromQuery] int limit = 20)
    {
        if (string.IsNullOrWhiteSpace(query))
            return Ok(new List<object>());

        var userId = GetUserId();
        var results = await _profileService.SearchUsers(query, userId, limit);
        return Ok(results);
    }

    /// <summary>
    /// GET /api/userprofile/public/{username} - Başka kullanıcının profilini getir
    /// </summary>
    [HttpGet("public/{username}")]
    public async Task<IActionResult> GetPublicProfile(string username)
    {
        var userId = GetUserId();
        var profile = await _profileService.GetPublicProfile(username, userId);

        if (profile == null)
            return NotFound(new MessageResponse { Message = "Kullanıcı bulunamadı." });

        return Ok(profile);
    }

    // ==================== FAVORİLER ====================

    /// <summary>
    /// GET /api/userprofile/favorites - Tüm favorileri getir
    /// </summary>
    [HttpGet("favorites")]
    public async Task<IActionResult> GetFavorites()
    {
        var userId = GetUserId();
        var favorites = await _profileService.GetFavorites(userId);
        return Ok(favorites);
    }

    /// <summary>
    /// POST /api/userprofile/favorites - Favorilere ürün ekle
    /// </summary>
    [HttpPost("favorites")]
    public async Task<IActionResult> AddFavorite([FromBody] AddFavoriteRequest request)
    {
        var userId = GetUserId();
        var (success, message) = await _profileService.AddFavorite(userId, request);

        if (!success)
            return BadRequest(new MessageResponse { Message = message });

        return Ok(new MessageResponse { Message = message });
    }

    /// <summary>
    /// DELETE /api/userprofile/favorites/{productId} - Favorilerden ürün kaldır
    /// </summary>
    [HttpDelete("favorites/{productId}")]
    public async Task<IActionResult> RemoveFavorite(string productId)
    {
        var userId = GetUserId();
        var (success, message) = await _profileService.RemoveFavorite(userId, productId);

        if (!success)
            return NotFound(new MessageResponse { Message = message });

        return Ok(new MessageResponse { Message = message });
    }

    /// <summary>
    /// POST /api/userprofile/favorites/toggle - Favori durumunu değiştir (ekle/kaldır)
    /// </summary>
    [HttpPost("favorites/toggle")]
    public async Task<IActionResult> ToggleFavorite([FromBody] AddFavoriteRequest request)
    {
        var userId = GetUserId();
        var (isFavorite, message) = await _profileService.ToggleFavorite(userId, request);

        return Ok(new { isFavorite, message });
    }

    /// <summary>
    /// GET /api/userprofile/favorites/{productId}/check - Favori kontrolü
    /// </summary>
    [HttpGet("favorites/{productId}/check")]
    public async Task<IActionResult> CheckFavorite(string productId)
    {
        var userId = GetUserId();
        var isFavorite = await _profileService.IsFavorite(userId, productId);

        return Ok(new { isFavorite });
    }

    // ==================== ARAMA GEÇMİŞİ ====================

    /// <summary>
    /// GET /api/userprofile/search-history?limit=20 - Arama geçmişini getir
    /// </summary>
    [HttpGet("search-history")]
    public async Task<IActionResult> GetSearchHistory([FromQuery] int limit = 20)
    {
        var userId = GetUserId();
        var history = await _profileService.GetSearchHistory(userId, limit);
        return Ok(history);
    }

    /// <summary>
    /// GET /api/userprofile/search-history/recent?limit=5 - Son aramaları getir
    /// </summary>
    [HttpGet("search-history/recent")]
    public async Task<IActionResult> GetRecentSearches([FromQuery] int limit = 5)
    {
        var userId = GetUserId();
        var history = await _profileService.GetSearchHistory(userId, limit);
        return Ok(history);
    }

    /// <summary>
    /// POST /api/userprofile/search-history - Arama geçmişine ekle
    /// </summary>
    [HttpPost("search-history")]
    public async Task<IActionResult> AddSearchHistory([FromBody] AddSearchHistoryRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Query))
            return BadRequest(new MessageResponse { Message = "Arama sorgusu boş olamaz." });

        var userId = GetUserId();
        await _profileService.AddSearchHistory(userId, request);

        return Ok(new MessageResponse { Message = "Arama geçmişine eklendi." });
    }

    /// <summary>
    /// DELETE /api/userprofile/search-history/{itemId} - Tek arama kaydını sil
    /// </summary>
    [HttpDelete("search-history/{itemId}")]
    public async Task<IActionResult> DeleteSearchHistoryItem(string itemId)
    {
        var userId = GetUserId();
        var result = await _profileService.DeleteSearchHistoryItem(userId, itemId);

        if (!result)
            return NotFound(new MessageResponse { Message = "Kayıt bulunamadı." });

        return Ok(new MessageResponse { Message = "Arama kaydı silindi." });
    }

    /// <summary>
    /// DELETE /api/userprofile/search-history - Tüm arama geçmişini temizle
    /// </summary>
    [HttpDelete("search-history")]
    public async Task<IActionResult> ClearSearchHistory()
    {
        var userId = GetUserId();
        await _profileService.ClearSearchHistory(userId);

        return Ok(new MessageResponse { Message = "Arama geçmişi temizlendi." });
    }
}
