using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace Skincore.Api.Models;

public class ModerationRequest
{
    [BsonId]
    [BsonRepresentation(BsonType.ObjectId)]
    public string Id { get; set; } = null!;

    [BsonElement("productId")]
    public string ProductId { get; set; } = null!;

    [BsonElement("userId")]
    public string UserId { get; set; } = null!;

    [BsonElement("note")]
    public string? Note { get; set; }

    // Kullanıcının yüklediği görseller (ön yüz, arka yüz/içerik)
    [BsonElement("frontImageUrl")]
    public string? FrontImageUrl { get; set; }

    [BsonElement("backImageUrl")]
    public string? BackImageUrl { get; set; }

    // pending | reviewed | resolved
    [BsonElement("status")]
    public string Status { get; set; } = "pending";

    // Admin notlar veya düzenleme notu
    [BsonElement("adminNote")]
    public string? AdminNote { get; set; }

    [BsonElement("createdAt")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [BsonElement("updatedAt")]
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}
