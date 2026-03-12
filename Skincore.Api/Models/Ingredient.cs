using MongoDB.Bson;
using MongoDB.Bson.IO;
using MongoDB.Bson.Serialization;
using MongoDB.Bson.Serialization.Attributes;
using MongoDB.Bson.Serialization.Serializers;
using System.Text.Json.Serialization;

namespace Skincore.Api.Models;

public class FunctionListBsonSerializer : SerializerBase<List<string>?>
{
    public override List<string>? Deserialize(BsonDeserializationContext context, BsonDeserializationArgs args)
    {
        var bsonType = context.Reader.GetCurrentBsonType();
        if (bsonType == BsonType.Null) { context.Reader.ReadNull(); return null; }
        if (bsonType != BsonType.Array) { context.Reader.SkipValue(); return null; }

        var list = new List<string>();
        context.Reader.ReadStartArray();
        while (context.Reader.ReadBsonType() != BsonType.EndOfDocument)
        {
            var currentType = context.Reader.CurrentBsonType;
            if (currentType == BsonType.String)
                list.Add(context.Reader.ReadString());
            else if (currentType == BsonType.Document)
            {
                string? name = null;
                context.Reader.ReadStartDocument();
                while (context.Reader.ReadBsonType() != BsonType.EndOfDocument)
                {
                    var fieldName = context.Reader.ReadName();
                    if (fieldName == "name" && context.Reader.CurrentBsonType == BsonType.String)
                        name = context.Reader.ReadString();
                    else
                        context.Reader.SkipValue();
                }
                context.Reader.ReadEndDocument();
                if (name != null) list.Add(name);
            }
            else context.Reader.SkipValue();
        }
        context.Reader.ReadEndArray();
        return list;
    }
}

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
    public object? IsDangerous { get; set; } // Changed to object? to handle string/bool mix
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
    [BsonSerializer(typeof(FunctionListBsonSerializer))]
    public List<string>? Functions { get; set; }

    [BsonElement("metrics")]
    [JsonPropertyName("metrics")]
    public IngredientMetrics? Metrics { get; set; }

    [BsonElement("skin_compatibility")]
    [JsonPropertyName("skin_compatibility")]
    public object? SkinCompatibility { get; set; }
}
