using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;
using System.Text.Json.Serialization;

namespace Skincore.Api.Models;

[BsonIgnoreExtraElements]
public class Product
{
    [BsonId]
    [BsonRepresentation(BsonType.ObjectId)]
    [JsonPropertyName("id")]
    public string? Id { get; set; }

    [BsonElement("name")]
    [JsonPropertyName("name")]
    public string Name { get; set; } = null!;

    [BsonElement("barcode")]
    [JsonPropertyName("barcode")]
    public string? Barcode { get; set; }

    [BsonElement("product_ingredients")]
    [JsonPropertyName("product_ingredients")]
    public List<string>? ProductIngredients { get; set; }

    [BsonElement("brand")]
    [JsonPropertyName("brand")]
    public string? Brand { get; set; }

    [BsonElement("ocr_text")]
    [JsonPropertyName("ocr_text")]
    public string? OcrText { get; set; }

    [BsonExtraElements]
    [JsonExtensionData]
    public IDictionary<string, object>? ExtraElements { get; set; }
}
