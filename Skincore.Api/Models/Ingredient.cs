using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace Skincore.Api.Models;

public class IngredientFunction
{
    [BsonElement("name")]
    public string Name { get; set; } = null!;

    [BsonElement("uri")]
    public string Uri { get; set; } = null!;

    [BsonElement("is_dangerous")]
    public bool IsDangerous { get; set; }
}

[BsonIgnoreExtraElements]
public class Ingredient
{
    [BsonId]
    [BsonRepresentation(BsonType.ObjectId)]
    public string? Id { get; set; }

    [BsonElement("name")]
    public string Name { get; set; } = null!;

    [BsonElement("name_upper")]
    public string? NameUpper { get; set; }

    [BsonElement("cas_number")]
    public string? CasNumber { get; set; }

    [BsonElement("comedogenic")]
    public string? Comedogenic { get; set; }

    [BsonElement("description")]
    public string? Description { get; set; }

    [BsonElement("ewg_score")]
    public string? EwgScore { get; set; }

    [BsonElement("functions")]
    public List<IngredientFunction>? Functions { get; set; }

    [BsonElement("groups")]
    public List<string>? Groups { get; set; }

    [BsonElement("limited_eu")]
    public bool? LimitedEu { get; set; }

    [BsonElement("limited_us")]
    public bool? LimitedUs { get; set; }

    [BsonElement("safety_label")]
    public string? SafetyLabel { get; set; }

    [BsonElement("safety_level")]
    public int? SafetyLevel { get; set; }

    [BsonElement("safetymakeup_id")]
    public string? SafetymakeupId { get; set; }

    [BsonElement("safetymakeup_url")]
    public string? SafetymakeupUrl { get; set; }

    [BsonElement("updated_at")]
    public string? UpdatedAt { get; set; }

    [BsonElement("uri")]
    public string? Uri { get; set; }

    [BsonElement("aliases")]
    public List<string>? Aliases { get; set; }
}
