using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace Skincore.Api.Models;

[BsonIgnoreExtraElements]
public class Product
{
    [BsonId]
    [BsonRepresentation(BsonType.ObjectId)]
    public string? Id { get; set; }

    [BsonElement("name")]
    public string Name { get; set; } = null!;

    [BsonElement("brand")]
    public string? Brand { get; set; }

    [BsonElement("description")]
    public string? Description { get; set; }

    [BsonElement("price")]
    public string? Price { get; set; }

    [BsonElement("rating")]
    public string? Rating { get; set; }

    [BsonElement("review_count")]
    public string? ReviewCount { get; set; }
    
    [BsonElement("barcode")]
    public string? Barcode { get; set; }

    [BsonElement("image_urls")]
    public List<string>? ImageUrls { get; set; }

    [BsonElement("product_ingredients")]
    public List<string>? ProductIngredients { get; set; }
    
    [BsonElement("categories")]
    public List<string>? Categories { get; set; }
}
