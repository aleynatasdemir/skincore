namespace Skincore.Api.Models;

// ── Profile Request DTOs ──

public class UpdateProfileRequest
{
    public string? DisplayName { get; set; }
    public string? SkinType { get; set; }
    public string? Username { get; set; }
}

public class CheckUsernameRequest
{
    public string Username { get; set; } = null!;
}

// ── Favorite Request DTOs ──

public class AddFavoriteRequest
{
    public string ProductId { get; set; } = null!;
    public string ProductName { get; set; } = null!;
    public string? ProductBrand { get; set; }
    public string? ProductImageURL { get; set; }
}

// ── Search History Request DTOs ──

public class AddSearchHistoryRequest
{
    public string Query { get; set; } = null!;
    public string? ProductId { get; set; }
    public string? ProductName { get; set; }
    public string? Category { get; set; }
}

// ── Profile Response DTOs ──

public class UserProfileResponse
{
    public string Id { get; set; } = null!;
    public string Email { get; set; } = null!;
    public string? FullName { get; set; }
    public string? SkinType { get; set; }
    public string? Username { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}

public class FavoriteResponse
{
    public string Id { get; set; } = null!;
    public string ProductId { get; set; } = null!;
    public string ProductName { get; set; } = null!;
    public string? ProductBrand { get; set; }
    public string? ProductImageURL { get; set; }
    public DateTime AddedAt { get; set; }
}

public class SearchHistoryResponse
{
    public string Id { get; set; } = null!;
    public string Query { get; set; } = null!;
    public string? ProductId { get; set; }
    public string? ProductName { get; set; }
    public string? Category { get; set; }
    public string? ImageUrl { get; set; }
    public DateTime SearchedAt { get; set; }
}
