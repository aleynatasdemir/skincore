using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Skincore.Api.Models;
using Skincore.Api.Services;

namespace Skincore.Api.Controllers;

[ApiController]
[Route("api/admin-auth")]
public class AdminAuthController : ControllerBase
{
    private readonly AdminAuthService _adminAuthService;

    public AdminAuthController(AdminAuthService adminAuthService)
    {
        _adminAuthService = adminAuthService;
    }

    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] AdminLoginRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Identifier) || string.IsNullOrWhiteSpace(request.Password))
            return BadRequest(new MessageResponse { Message = "Kullanıcı adı/e-posta ve şifre gereklidir." });

        var (success, message, response) = await _adminAuthService.LoginAsync(request);
        if (!success || response == null)
            return BadRequest(new MessageResponse { Message = message });

        return Ok(response);
    }

    [Authorize]
    [HttpGet("me")]
    public async Task<IActionResult> Me()
    {
        var adminId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (string.IsNullOrWhiteSpace(adminId))
            return Unauthorized(new MessageResponse { Message = "Geçersiz token." });

        var admin = await _adminAuthService.GetAdminByIdAsync(adminId);
        if (admin == null)
            return NotFound(new MessageResponse { Message = "Admin bulunamadı." });

        return Ok(AdminSessionUserResponse.FromAdminUser(admin));
    }
}

