using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace Skincore.Api.Models;

public class User
{
    [BsonId]
    [BsonRepresentation(BsonType.ObjectId)]
    public string Id { get; set; } = null!;

    [BsonElement("email")]
    public string Email { get; set; } = null!;

    [BsonElement("passwordHash")]
    public string? PasswordHash { get; set; }

    [BsonElement("fullName")]
    public string? FullName { get; set; }

    // Apple Sign In
    [BsonElement("appleUserId")]
    public string? AppleUserId { get; set; }

    [BsonElement("authProvider")]
    public string AuthProvider { get; set; } = "email"; // "email" or "apple"

    // Email Verification
    [BsonElement("isEmailVerified")]
    public bool IsEmailVerified { get; set; }

    [BsonElement("verificationCode")]
    public string? VerificationCode { get; set; }

    [BsonElement("verificationCodeExpiry")]
    public DateTime? VerificationCodeExpiry { get; set; }

    [BsonElement("verificationAttempts")]
    public int VerificationAttempts { get; set; }

    // Refresh Token
    [BsonElement("refreshToken")]
    public string? RefreshToken { get; set; }

    [BsonElement("refreshTokenExpiry")]
    public DateTime? RefreshTokenExpiry { get; set; }

    // Timestamps
    [BsonElement("createdAt")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [BsonElement("lastLoginAt")]
    public DateTime? LastLoginAt { get; set; }
}
