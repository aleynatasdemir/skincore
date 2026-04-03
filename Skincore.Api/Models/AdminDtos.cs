namespace Skincore.Api.Models;

public class AdminUserResponse
{
    public string Id { get; set; } = null!;
    public string Email { get; set; } = null!;
    public string? FullName { get; set; }
    public string? Username { get; set; }
    public string? ProfileImageUrl { get; set; }
    public string AuthProvider { get; set; } = null!;
    public bool IsEmailVerified { get; set; }
    public bool IsAdmin { get; set; }
    public bool IsBanned { get; set; }
    public string? BanReason { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? LastLoginAt { get; set; }

    public static AdminUserResponse FromUser(User user) => new()
    {
        Id = user.Id,
        Email = user.Email,
        FullName = user.FullName,
        Username = user.Username,
        ProfileImageUrl = user.ProfileImageUrl,
        AuthProvider = user.AuthProvider,
        IsEmailVerified = user.IsEmailVerified,
        IsAdmin = user.IsAdmin,
        IsBanned = user.IsBanned,
        BanReason = user.BanReason,
        CreatedAt = user.CreatedAt,
        LastLoginAt = user.LastLoginAt
    };
}

public class BanRequest
{
    public string? Reason { get; set; }
}

public class ApproveProductRequestBody
{
    public string Name { get; set; } = null!;
    public string? Barcode { get; set; }
    public string? Brand { get; set; }
    public string? ImageUrl { get; set; }
    public string? IngredientsText { get; set; } // virgülle ayrılmış içerik listesi
    public string? OcrText { get; set; }
}

public class BroadcastNotificationRequest
{
    public string Title { get; set; } = null!;
    public string Body { get; set; } = null!;
}

public static class NotificationAudience
{
    public const string AllUsers = "all_users";
    public const string SpecificUser = "specific_user";
    public const string AdminStaff = "admin_staff";
}

public class SendNotificationRequest
{
    public string Audience { get; set; } = NotificationAudience.AllUsers;
    public string? RecipientUserId { get; set; }
    public string Title { get; set; } = null!;
    public string Body { get; set; } = null!;
    public string? TitleTr { get; set; }
    public string? BodyTr { get; set; }
    public string? TitleEn { get; set; }
    public string? BodyEn { get; set; }
}

public class OcrExtractRequest
{
    public string? ImageUrl { get; set; }
    public string? ImageBase64 { get; set; }
}

public class UpdateIngredientsBody
{
    public string? Content { get; set; }
}

public class OcrExtractResponse
{
    public string Text { get; set; } = string.Empty;
    public double? Confidence { get; set; }
    public int CharacterCount { get; set; }
}

public class AdminProductRequestResponse
{
    public string Id { get; set; } = null!;
    public string? UserId { get; set; }
    public string BrandName { get; set; } = null!;
    public string? ProductName { get; set; }
    public string? FrontImageUrl { get; set; }
    public string? IngredientsImageUrl { get; set; }
    public string Status { get; set; } = null!;
    public DateTime CreatedAt { get; set; }

    public static AdminProductRequestResponse FromRequest(ProductRequest r) => new()
    {
        Id = r.Id,
        UserId = r.UserId,
        BrandName = r.BrandName,
        ProductName = r.ProductName,
        FrontImageUrl = r.FrontImageUrl,
        IngredientsImageUrl = r.IngredientsImageUrl,
        Status = r.Status,
        CreatedAt = r.CreatedAt
    };
}

public class AdminNotificationLogResponse
{
    public string Id { get; set; } = null!;
    public string? RecipientUserId { get; set; }
    public string Title { get; set; } = null!;
    public string Body { get; set; } = null!;
    public string Type { get; set; } = null!;
    public bool Success { get; set; }
    public DateTime SentAt { get; set; }
}

public class AdminRoutineResponse
{
    public string Id { get; set; } = null!;
    public string UserId { get; set; } = null!;
    public string UserName { get; set; } = null!;
    public string Title { get; set; } = null!;
    public string? Description { get; set; }
    public int LikeCount { get; set; }
    public int CommentCount { get; set; }
    public DateTime CreatedAt { get; set; }

    public static AdminRoutineResponse FromRoutine(Routine r) => new()
    {
        Id = r.Id,
        UserId = r.UserId,
        UserName = r.UserName,
        Title = r.Title,
        Description = r.Description,
        LikeCount = r.Likes.Count,
        CommentCount = r.Comments.Count,
        CreatedAt = r.CreatedAt
    };
}

public class AdminRoutineCommentResponse
{
    public string Id { get; set; } = null!;
    public string UserId { get; set; } = null!;
    public string UserName { get; set; } = null!;
    public string Text { get; set; } = null!;
    public string? UserProfileImageUrl { get; set; }
    public DateTime CreatedAt { get; set; }
}

public class EmbedProductRequest
{
    public string? ImageBase64 { get; set; }
    public string? ImageUrl { get; set; }   // sunucu tarafında indirilir
    public string? Barcode { get; set; }
}
