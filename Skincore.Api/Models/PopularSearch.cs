using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace Skincore.Api.Models;

public class PopularSearch
{
    [BsonId]
    [BsonRepresentation(BsonType.ObjectId)]
    public string Id { get; set; } = null!;

    [BsonElement("productId")]
    [BsonRepresentation(BsonType.ObjectId)]
    public string ProductId { get; set; } = null!;

    [BsonElement("productName")]
    public string ProductName { get; set; } = null!;

    [BsonElement("searchCount")]
    public int SearchCount { get; set; }

    [BsonElement("lastSearchedAt")]
    public DateTime LastSearchedAt { get; set; } = DateTime.UtcNow;
}

// Response DTO
public class PopularProductResponse
{
    public string ProductId { get; set; } = null!;
    public string ProductName { get; set; } = null!;
    public string? ImageUrl { get; set; }
}
