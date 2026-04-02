namespace Skincore.Api.Models;

public class AdminLoginRequest
{
    public string Identifier { get; set; } = null!;
    public string Password { get; set; } = null!;
}

public class AdminAuthResponse
{
    public string AccessToken { get; set; } = null!;
    public AdminSessionUserResponse User { get; set; } = null!;
}

public class AdminSessionUserResponse
{
    public string Id { get; set; } = null!;
    public string Email { get; set; } = null!;
    public string Username { get; set; } = null!;
    public string? FullName { get; set; }
    public bool IsAdmin { get; set; } = true;
    public DateTime CreatedAt { get; set; }
    public DateTime? LastLoginAt { get; set; }

    public static AdminSessionUserResponse FromAdminUser(AdminUser user) => new()
    {
        Id = user.Id,
        Email = user.Email,
        Username = user.Username,
        FullName = user.FullName,
        IsAdmin = true,
        CreatedAt = user.CreatedAt,
        LastLoginAt = user.LastLoginAt
    };
}

