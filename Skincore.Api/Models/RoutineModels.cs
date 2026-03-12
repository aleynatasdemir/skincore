using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace Skincore.Api.Models;

public class Routine
{
    [BsonId]
    [BsonRepresentation(BsonType.ObjectId)]
    public string Id { get; set; } = null!;

    [BsonElement("userId")]
    [BsonRepresentation(BsonType.ObjectId)]
    public string UserId { get; set; } = null!;

    [BsonElement("userName")]
    public string UserName { get; set; } = null!;

    [BsonElement("title")]
    public string Title { get; set; } = null!;

    [BsonElement("description")]
    public string? Description { get; set; }

    [BsonElement("skinType")]
    public string? SkinType { get; set; }

    [BsonElement("focus")]
    public string? Focus { get; set; }

    [BsonElement("routineType")]
    public string? RoutineType { get; set; }

    [BsonElement("tags")]
    public List<string> Tags { get; set; } = new();

    [BsonElement("coverImageUrl")]
    public string? CoverImageUrl { get; set; }

    [BsonElement("products")]
    public List<RoutineProduct> Products { get; set; } = new();

    [BsonElement("likes")]
    public List<string> Likes { get; set; } = new();

    [BsonElement("comments")]
    public List<RoutineComment> Comments { get; set; } = new();

    [BsonElement("createdAt")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [BsonElement("updatedAt")]
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}

public class RoutineProduct
{
    [BsonElement("productId")]
    [BsonRepresentation(BsonType.ObjectId)]
    public string ProductId { get; set; } = null!;

    [BsonElement("name")]
    public string Name { get; set; } = null!;

    [BsonElement("brand")]
    public string? Brand { get; set; }

    [BsonElement("imageUrl")]
    public string? ImageUrl { get; set; }
}

public class RoutineComment
{
    [BsonElement("id")]
    public string Id { get; set; } = ObjectId.GenerateNewId().ToString();

    [BsonElement("userId")]
    [BsonRepresentation(BsonType.ObjectId)]
    public string UserId { get; set; } = null!;

    [BsonElement("userName")]
    public string UserName { get; set; } = null!;

    [BsonElement("text")]
    public string Text { get; set; } = null!;

    [BsonElement("createdAt")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

// ── Routine Request DTOs ──

public class CreateRoutineRequest
{
    public string Title { get; set; } = null!;
    public string? Description { get; set; }
    public string? SkinType { get; set; }
    public string? Focus { get; set; }
    public string? RoutineType { get; set; }
    public List<string>? Tags { get; set; }
    public string? CoverImageUrl { get; set; }
    public List<RoutineProductRequest>? Products { get; set; }
}

public class RoutineProductRequest
{
    public string ProductId { get; set; } = null!;
    public string Name { get; set; } = null!;
    public string? Brand { get; set; }
    public string? ImageUrl { get; set; }
}

public class AddRoutineCommentRequest
{
    public string Text { get; set; } = null!;
}

// ── Routine Response DTOs ──

public class RoutineFeedItemResponse
{
    public string Id { get; set; } = null!;
    public string UserName { get; set; } = null!;
    public string? SkinType { get; set; }
    public string? Focus { get; set; }
    public string Title { get; set; } = null!;
    public string? Description { get; set; }
    public string? CoverImageUrl { get; set; }
    public List<string> Tags { get; set; } = new();
    public int LikeCount { get; set; }
    public int CommentCount { get; set; }
    public bool HasLiked { get; set; }
    public List<RoutineProductResponse> Products { get; set; } = new();
    public DateTime CreatedAt { get; set; }
}

public class RoutineDetailResponse
{
    public string Id { get; set; } = null!;
    public string UserName { get; set; } = null!;
    public string? SkinType { get; set; }
    public string? Focus { get; set; }
    public string Title { get; set; } = null!;
    public string? Description { get; set; }
    public string? CoverImageUrl { get; set; }
    public string? RoutineType { get; set; }
    public List<string> Tags { get; set; } = new();
    public int LikeCount { get; set; }
    public int CommentCount { get; set; }
    public bool HasLiked { get; set; }
    public DateTime CreatedAt { get; set; }
    public List<RoutineProductResponse> Products { get; set; } = new();
    public List<RoutineCommentResponse> Comments { get; set; } = new();
}

public class RoutineProductResponse
{
    public string ProductId { get; set; } = null!;
    public string Name { get; set; } = null!;
    public string? Brand { get; set; }
    public string? ImageUrl { get; set; }
}

public class RoutineCommentResponse
{
    public string Id { get; set; } = null!;
    public string UserName { get; set; } = null!;
    public string Text { get; set; } = null!;
    public DateTime CreatedAt { get; set; }
}

public class ToggleLikeResponse
{
    public bool IsLiked { get; set; }
    public int LikeCount { get; set; }
}
