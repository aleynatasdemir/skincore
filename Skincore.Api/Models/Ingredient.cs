using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;
using System.Text.Json.Serialization;

namespace Skincore.Api.Models;

[BsonIgnoreExtraElements]
public class IngredientFunction
{
    [BsonElement("name")]
    [JsonPropertyName("name")]
    public string? Name { get; set; }

    [BsonElement("uri")]
    [JsonPropertyName("uri")]
    public string? Uri { get; set; }

    [BsonElement("is_dangerous")]
    [JsonPropertyName("is_dangerous")]
    public bool IsDangerous { get; set; }
}

[BsonIgnoreExtraElements]
public class IngredientMetrics
{
    [BsonElement("safety_level")]
    [JsonPropertyName("safety_level")]
    public int? SafetyLevel { get; set; }

    [BsonElement("safety_label")]
    [JsonPropertyName("safety_label")]
    public string? SafetyLabel { get; set; }

    [BsonElement("ewg_score")]
    [JsonPropertyName("ewg_score")]
    public string? EwgScore { get; set; }

    [BsonElement("comedogenic_rating")]
    [JsonPropertyName("comedogenic_rating")]
    public object? ComedogenicRating { get; set; }
}

[BsonIgnoreExtraElements]
public class Ingredient
{
    [BsonId]
    [BsonRepresentation(BsonType.ObjectId)]
    [JsonPropertyName("id")]
    public string? Id { get; set; }

    [BsonElement("inci_name")]
    [JsonPropertyName("name")]
    public string Name { get; set; } = null!;

    [BsonElement("name_upper")]
    [JsonPropertyName("name_upper")]
    public string? NameUpper { get; set; }

    [BsonElement("aliases")]
    [JsonPropertyName("aliases")]
    public List<string>? Aliases { get; set; }

    [BsonElement("description")]
    [JsonPropertyName("description")]
    public string? Description { get; set; }

    [BsonElement("functions")]
    [JsonPropertyName("functions")]
    public BsonArray? Functions { get; set; }

    [BsonElement("metrics")]
    [JsonPropertyName("metrics")]
    public IngredientMetrics? Metrics { get; set; }

    [BsonElement("skin_compatibility")]
    [JsonPropertyName("skin_compatibility")]
    public object? SkinCompatibility { get; set; }

    [BsonExtraElements]
    [JsonExtensionData]
    public IDictionary<string, object>? ExtraElements { get; set; }
}
