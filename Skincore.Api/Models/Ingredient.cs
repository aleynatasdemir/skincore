using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;
using System.Text.Json.Serialization;

namespace Skincore.Api.Models;

[BsonIgnoreExtraElements]
public class Ingredient
{
    [BsonId]
    [BsonRepresentation(BsonType.ObjectId)]
    [JsonPropertyName("id")]
    public string? Id { get; set; }

    [BsonElement("inci_name")]
    [JsonPropertyName("inci_name")]
    public string? INCIName { get; set; }

    [BsonElement("name")]
    [JsonPropertyName("name")]
    public string? Name { get; set; }

    [BsonElement("name_upper")]
    [JsonPropertyName("name_upper")]
    public string? NameUpper { get; set; }

    [BsonElement("aliases")]
    [JsonPropertyName("aliases")]
    public List<string>? Aliases { get; set; }

    [BsonElement("description")]
    [JsonPropertyName("description")]
    public string? Description { get; set; }

    [BsonIgnore]
    [JsonPropertyName("ewg_score")]
    public string? EwgScore => Metrics?.EwgScore;

    [BsonElement("functions")]
    [JsonPropertyName("functions")]
    public List<string>? Functions { get; set; }

    [BsonElement("metrics")]
    [JsonPropertyName("metrics")]
    public IngredientMetrics? Metrics { get; set; }

    [BsonElement("limited_eu")]
    [JsonPropertyName("limited_eu")]
    public bool LimitedEu { get; set; }

    [BsonElement("limited_us")]
    [JsonPropertyName("limited_us")]
    public bool LimitedUs { get; set; }

    [BsonElement("comedogenic")]
    [JsonPropertyName("comedogenic")]
    public object? Comedogenic { get; set; }

<<<<<<< HEAD
    [BsonElement("inci_name")]
    [JsonPropertyName("inci_name")]
    public string? InciName { get; set; }
=======
    [BsonElement("comedogenic_rating")]
    [JsonPropertyName("comedogenic_rating")]
    public int? ComedogenicRating { get; set; }

    // We can map the nested structure by creating a sub-class or custom deserialization
    [BsonElement("skin_compatibility")]
    [JsonPropertyName("skin_compatibility")]
    public SkinCompatibility? SkinCompatibility { get; set; }
>>>>>>> cb7449ce (ingredients sayfası düzeltildi)

    [BsonExtraElements]
    [JsonExtensionData]
    public IDictionary<string, object>? ExtraElements { get; set; }

    // Convenience properties for direct access
    [BsonIgnore]
    [JsonIgnore]
    public string? SafetyLabel => Metrics?.SafetyLabel;

    [BsonIgnore]
    [JsonIgnore]
    public int? SafetyLevel => Metrics?.SafetyLevel;
}

public class SkinCompatibility
{
    [BsonElement("good_for")]
    [JsonPropertyName("good_for")]
    public List<string>? GoodFor { get; set; }

    [BsonElement("bad_for")]
    [JsonPropertyName("bad_for")]
    public List<string>? BadFor { get; set; }
}

// Inner class for metrics
public class IngredientMetrics
{
    [BsonElement("safety_label")]
    [JsonPropertyName("safety_label")]
    public string? SafetyLabel { get; set; }

    [BsonElement("safety_level")]
    [JsonPropertyName("safety_level")]
    public int? SafetyLevel { get; set; }

    [BsonElement("comedogenic_rating")]
    [JsonPropertyName("comedogenic_rating")]
    public int? ComedogenicRating { get; set; }

    [BsonElement("ewg_score")]
    [JsonPropertyName("ewg_score")]
    public string? EwgScore { get; set; }
}
