using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace SilkProductManager.Api.Models;

[BsonIgnoreExtraElements]
public class Product
{
    [BsonId]
    [BsonRepresentation(BsonType.ObjectId)]
    public string? Id { get; set; }

    [BsonElement("name")]
    public string ProductName { get; set; } = null!;

    [BsonElement("barcode")]
    public string Barcode { get; set; } = null!;

    [BsonElement("image")]
    public string? ImageUrl { get; set; }

    [BsonElement("status")]
    public string Status { get; set; } = "Draft"; // Draft, NeedsReview, Published etc.
    
    [BsonElement("content")]
    public string? Content { get; set; }

    [BsonElement("product_ingredients")]
    public List<string>? ProductIngredients { get; set; }
}
