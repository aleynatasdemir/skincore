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
    private readonly NotificationService _notificationService;

    public AuthController(AuthService authService, NotificationService notificationService)
    {
        _authService = authService;
        _notificationService = notificationService;
    }

    /// <summary>
    /// Sadece test amaçlıdır. Girilen FCM Token'a bildirim atar.
    /// </summary>
    [HttpPost("test-notification")]
    public async Task<IActionResult> SendTestNotification([FromBody] TestNotificationRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.FcmToken))
            return BadRequest(new MessageResponse { Message = "Token gerekli!" });

        bool success = await _notificationService.SendPushNotificationAsync(
            request.FcmToken, 
            "✨ Test Başarılı!", 
            "API üzerinden gönderilen ilk bildirim! Skincore harika çalışıyor 🚀"
        );
        
        if (success)
            return Ok(new MessageResponse { Message = "Bildirim başarıyla cihaza gönderildi!" });
        
        return BadRequest(new MessageResponse { Message = "Bildirim gönderilemedi, detaylar konsolda olabilir." });
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
    /// Şifre sıfırlama kodu gönder.
    /// </summary>
    [HttpPost("forgot-password")]
    public async Task<IActionResult> ForgotPassword([FromBody] ForgotPasswordRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Email))
            return BadRequest(new MessageResponse { Message = "E-posta gereklidir." });

        var (success, message) = await _authService.ForgotPasswordAsync(request.Email);

        if (!success)
            return BadRequest(new MessageResponse { Message = message });

        return Ok(new MessageResponse { Message = message });
    }

    /// <summary>
    /// Şifre sıfırlama kodunu doğrula ve yeni şifreyi kaydet.
    /// </summary>
    [HttpPost("reset-password")]
    public async Task<IActionResult> ResetPassword([FromBody] ResetPasswordRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Email) ||
            string.IsNullOrWhiteSpace(request.Code) ||
            string.IsNullOrWhiteSpace(request.NewPassword))
            return BadRequest(new MessageResponse { Message = "E-posta, kod ve yeni şifre gereklidir." });

        var (success, message) = await _authService.ResetPasswordAsync(request);

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
    /// Kullanıcının Push Notification (FCM) token'ını günceller.
    /// </summary>
    [Authorize]
    [HttpPut("fcm-token")]
    public async Task<IActionResult> UpdateFcmToken([FromBody] UpdateFcmTokenRequest request)
    {
        var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (string.IsNullOrEmpty(userId))
            return Unauthorized(new MessageResponse { Message = "Geçersiz token." });

        if (string.IsNullOrWhiteSpace(request.FcmToken))
            return BadRequest(new MessageResponse { Message = "FCM token gereklidir." });

        var (success, message) = await _authService.UpdateFcmTokenAsync(userId, request.FcmToken, request.Language);

        if (!success)
            return BadRequest(new MessageResponse { Message = message });

        return Ok(new MessageResponse { Message = message });
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
