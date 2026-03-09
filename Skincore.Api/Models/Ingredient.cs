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

    [BsonElement("aliases")]
    [JsonPropertyName("aliases")]
    public List<string>? Aliases { get; set; }

    [BsonExtraElements]
    [JsonExtensionData]
    public IDictionary<string, object>? ExtraElements { get; set; }
}
