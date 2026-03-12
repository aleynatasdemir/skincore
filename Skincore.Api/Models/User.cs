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

    [BsonElement("username")]
    public string? Username { get; set; }

    [BsonElement("skinType")]
    public string? SkinType { get; set; }

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

    // Favoriler
    [BsonElement("favorites")]
    public List<FavoriteProduct> Favorites { get; set; } = new();

    // Arama Geçmişi
    [BsonElement("searchHistory")]
    public List<SearchHistoryItem> SearchHistory { get; set; } = new();

    // Timestamps
    [BsonElement("createdAt")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [BsonElement("lastLoginAt")]
    public DateTime? LastLoginAt { get; set; }

    [BsonElement("updatedAt")]
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}

public class FavoriteProduct
{
    [BsonElement("id")]
    public string Id { get; set; } = ObjectId.GenerateNewId().ToString();

    [BsonElement("productId")]
    [BsonRepresentation(BsonType.ObjectId)]
    public string ProductId { get; set; } = null!;

    [BsonElement("productName")]
    public string ProductName { get; set; } = null!;

    [BsonElement("productBrand")]
    public string? ProductBrand { get; set; }

    [BsonElement("productImageURL")]
    public string? ProductImageURL { get; set; }

    [BsonElement("addedAt")]
    public DateTime AddedAt { get; set; } = DateTime.UtcNow;
}

public class SearchHistoryItem
{
    [BsonElement("id")]
    public string Id { get; set; } = ObjectId.GenerateNewId().ToString();

    [BsonElement("query")]
    public string Query { get; set; } = null!;

    [BsonElement("productId")]
    [BsonRepresentation(BsonType.ObjectId)]
    public string? ProductId { get; set; }

    [BsonElement("productName")]
    public string? ProductName { get; set; }

    [BsonElement("category")]
    public string? Category { get; set; }

    [BsonElement("searchedAt")]
    public DateTime SearchedAt { get; set; } = DateTime.UtcNow;
}
