using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace Skincore.Api.Models;

public class ProductRequest
{
    [BsonId]
    [BsonRepresentation(BsonType.ObjectId)]
    public string Id { get; set; } = null!;

    [BsonElement("userId")]
    public string? UserId { get; set; }

    [BsonElement("brandName")]
    public string BrandName { get; set; } = null!;

    [BsonElement("productName")]
    public string? ProductName { get; set; }

    [BsonElement("frontImageUrl")]
    public string? FrontImageUrl { get; set; }

    [BsonElement("ingredientsImageUrl")]
    public string? IngredientsImageUrl { get; set; }

    [BsonElement("status")]
    public string Status { get; set; } = "pending"; // pending, reviewed, added

    [BsonElement("createdAt")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
