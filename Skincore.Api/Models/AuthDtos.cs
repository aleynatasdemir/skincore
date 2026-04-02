namespace Skincore.Api.Models;

// ── Request DTOs ──

public class RegisterRequest
{
    public string Email { get; set; } = null!;
    public string Password { get; set; } = null!;
    public string? FullName { get; set; }
}

public class LoginRequest
{
    public string Email { get; set; } = null!;
    public string Password { get; set; } = null!;
}

public class VerifyEmailRequest
{
    public string Email { get; set; } = null!;
    public string Code { get; set; } = null!;
}

public class AppleSignInRequest
{
    public string IdentityToken { get; set; } = null!;
    public string? FullName { get; set; }
    public string? Email { get; set; }
}

public class ResendCodeRequest
{
    public string Email { get; set; } = null!;
}

public class RefreshTokenRequest
{
    public string RefreshToken { get; set; } = null!;
}

public class ForgotPasswordRequest
{
    public string Email { get; set; } = null!;
}

public class ResetPasswordRequest
{
    public string Email { get; set; } = null!;
    public string Code { get; set; } = null!;
    public string NewPassword { get; set; } = null!;
}

public class UpdateFcmTokenRequest
{
    public string FcmToken { get; set; } = null!;
    public string? Language { get; set; }
}

public class TestNotificationRequest
{
    public string FcmToken { get; set; } = null!;
}

// ── Response DTOs ──

public class AuthResponse
{
    public string AccessToken { get; set; } = null!;
    public string RefreshToken { get; set; } = null!;
    public UserResponse User { get; set; } = null!;
}

public class UserResponse
{
    public string Id { get; set; } = null!;
    public string Email { get; set; } = null!;
    public string? FullName { get; set; }
    public string? Username { get; set; }
    public string? ProfileImageUrl { get; set; }
    public string AuthProvider { get; set; } = null!;
    public bool IsEmailVerified { get; set; }
    public DateTime CreatedAt { get; set; }

    public static UserResponse FromUser(User user) => new()
    {
        Id = user.Id,
        Email = user.Email,
        FullName = user.FullName,
        Username = user.Username,
        ProfileImageUrl = user.ProfileImageUrl,
        AuthProvider = user.AuthProvider,
        IsEmailVerified = user.IsEmailVerified,
        CreatedAt = user.CreatedAt
    };
}

public class MessageResponse
{
    public string Message { get; set; } = null!;
}

public class ChangePasswordRequest
{
    public string CurrentPassword { get; set; } = null!;
    public string NewPassword { get; set; } = null!;
}
