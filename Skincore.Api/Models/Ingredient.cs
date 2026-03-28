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

    [BsonElement("name")]
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

    [BsonElement("ewg_score")]
    [JsonPropertyName("ewg_score")]
    public string? EwgScore { get; set; }

    [BsonElement("functions")]
    [JsonPropertyName("functions")]
    public List<string>? Functions { get; set; }

    [BsonElement("safety_label")]
    [JsonPropertyName("safety_label")]
    public string? SafetyLabel { get; set; }

    [BsonElement("safety_level")]
    [JsonPropertyName("safety_level")]
    public int? SafetyLevel { get; set; }

    [BsonElement("limited_eu")]
    [JsonPropertyName("limited_eu")]
    public bool LimitedEu { get; set; }

    [BsonElement("limited_us")]
    [JsonPropertyName("limited_us")]
    public bool LimitedUs { get; set; }

    [BsonElement("comedogenic")]
    [JsonPropertyName("comedogenic")]
    public object? Comedogenic { get; set; }

    [BsonExtraElements]
    [JsonExtensionData]
    public IDictionary<string, object>? ExtraElements { get; set; }
}
