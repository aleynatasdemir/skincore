using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using MongoDB.Driver;
using Skincore.Api.Models;

namespace Skincore.Api.Services;

public class AdminAuthService
{
    private readonly MongoDbService _mongoDbService;
    private readonly JwtSettings _jwtSettings;

    public AdminAuthService(
        MongoDbService mongoDbService,
        IOptions<JwtSettings> jwtSettings)
    {
        _mongoDbService = mongoDbService;
        _jwtSettings = jwtSettings.Value;
    }

    public async Task<(bool Success, string Message, AdminAuthResponse? Response)> LoginAsync(AdminLoginRequest request)
    {
        var identifier = request.Identifier.Trim().ToLowerInvariant();

        var admin = await _mongoDbService.AdminUsersCollection
            .Find(a => a.Email == identifier || a.Username == identifier)
            .FirstOrDefaultAsync();

        if (admin == null)
            return (false, "Kullanıcı adı/e-posta veya şifre hatalı.", null);

        if (!admin.IsActive)
            return (false, "Admin hesabı pasif durumda.", null);

        if (string.IsNullOrWhiteSpace(admin.PasswordHash) || !BCrypt.Net.BCrypt.Verify(request.Password, admin.PasswordHash))
            return (false, "Kullanıcı adı/e-posta veya şifre hatalı.", null);

        var update = Builders<AdminUser>.Update
            .Set(a => a.LastLoginAt, DateTime.UtcNow)
            .Set(a => a.UpdatedAt, DateTime.UtcNow);

        await _mongoDbService.AdminUsersCollection.UpdateOneAsync(a => a.Id == admin.Id, update);

        var accessToken = GenerateJwtToken(admin);
        return (true, "Admin girişi başarılı.", new AdminAuthResponse
        {
            AccessToken = accessToken,
            User = AdminSessionUserResponse.FromAdminUser(admin)
        });
    }

    public async Task<AdminUser?> GetAdminByIdAsync(string adminId)
    {
        return await _mongoDbService.AdminUsersCollection
            .Find(a => a.Id == adminId)
            .FirstOrDefaultAsync();
    }

    private string GenerateJwtToken(AdminUser admin)
    {
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_jwtSettings.Secret));
        var credentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var claims = new[]
        {
            new Claim(ClaimTypes.NameIdentifier, admin.Id),
            new Claim(ClaimTypes.Email, admin.Email),
            new Claim(ClaimTypes.Role, "admin"),
            new Claim("admin", "true"),
            new Claim("auth_provider", "admin")
        };

        var token = new JwtSecurityToken(
            issuer: _jwtSettings.Issuer,
            audience: _jwtSettings.Audience,
            claims: claims,
            expires: DateTime.UtcNow.AddMinutes(_jwtSettings.AccessTokenExpirationMinutes),
            signingCredentials: credentials
        );

        return new JwtSecurityTokenHandler().WriteToken(token);
    }
}

