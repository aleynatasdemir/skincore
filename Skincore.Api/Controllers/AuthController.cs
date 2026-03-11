using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Skincore.Api.Models;
using Skincore.Api.Services;

namespace Skincore.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private readonly AuthService _authService;

    public AuthController(AuthService authService)
    {
        _authService = authService;
    }

    /// <summary>
    /// E-posta ile kayıt. Doğrulama kodu gönderir.
    /// </summary>
    [HttpPost("register")]
    public async Task<IActionResult> Register([FromBody] RegisterRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Email) || string.IsNullOrWhiteSpace(request.Password))
            return BadRequest(new MessageResponse { Message = "E-posta ve şifre gereklidir." });

        var (success, message) = await _authService.RegisterAsync(request);
        
        if (!success)
            return BadRequest(new MessageResponse { Message = message });

        return Ok(new MessageResponse { Message = message });
    }

    /// <summary>
    /// E-posta doğrulama kodu kontrolü. Başarılı olursa JWT döner.
    /// </summary>
    [HttpPost("verify-email")]
    public async Task<IActionResult> VerifyEmail([FromBody] VerifyEmailRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Email) || string.IsNullOrWhiteSpace(request.Code))
            return BadRequest(new MessageResponse { Message = "E-posta ve doğrulama kodu gereklidir." });

        var (success, message, response) = await _authService.VerifyEmailAsync(request);

        if (!success)
            return BadRequest(new MessageResponse { Message = message });

        return Ok(response);
    }

    /// <summary>
    /// E-posta/şifre ile giriş. Doğrulanmış hesap gerektirir.
    /// </summary>
    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Email) || string.IsNullOrWhiteSpace(request.Password))
            return BadRequest(new MessageResponse { Message = "E-posta ve şifre gereklidir." });

        var (success, message, response) = await _authService.LoginAsync(request);

        if (!success)
            return BadRequest(new MessageResponse { Message = message });

        return Ok(response);
    }

    /// <summary>
    /// Apple Sign In. identityToken ile giriş/kayıt.
    /// </summary>
    [HttpPost("apple")]
    public async Task<IActionResult> AppleSignIn([FromBody] AppleSignInRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.IdentityToken))
            return BadRequest(new MessageResponse { Message = "Apple identity token gereklidir." });

        var (success, message, response) = await _authService.AppleSignInAsync(request);

        if (!success)
            return BadRequest(new MessageResponse { Message = message });

        return Ok(response);
    }

    /// <summary>
    /// Doğrulama kodunu tekrar gönder.
    /// </summary>
    [HttpPost("resend-code")]
    public async Task<IActionResult> ResendCode([FromBody] ResendCodeRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Email))
            return BadRequest(new MessageResponse { Message = "E-posta gereklidir." });

        var (success, message) = await _authService.ResendVerificationCodeAsync(request.Email);

        if (!success)
            return BadRequest(new MessageResponse { Message = message });

        return Ok(new MessageResponse { Message = message });
    }

    /// <summary>
    /// Refresh token ile yeni access token al.
    /// </summary>
    [HttpPost("refresh")]
    public async Task<IActionResult> RefreshToken([FromBody] RefreshTokenRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.RefreshToken))
            return BadRequest(new MessageResponse { Message = "Refresh token gereklidir." });

        var (success, message, response) = await _authService.RefreshTokenAsync(request.RefreshToken);

        if (!success)
            return Unauthorized(new MessageResponse { Message = message });

        return Ok(response);
    }

    /// <summary>
    /// Mevcut kullanıcı bilgilerini getir. JWT gerektirir.
    /// </summary>
    [Authorize]
    [HttpGet("me")]
    public async Task<IActionResult> GetCurrentUser()
    {
        var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (string.IsNullOrEmpty(userId))
            return Unauthorized(new MessageResponse { Message = "Geçersiz token." });

        var user = await _authService.GetUserByIdAsync(userId);
        if (user == null)
            return NotFound(new MessageResponse { Message = "Kullanıcı bulunamadı." });

        return Ok(UserResponse.FromUser(user));
    }
}
