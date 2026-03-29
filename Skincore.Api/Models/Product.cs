using MongoDB.Bson;
using MongoDB.Bson.IO;
using MongoDB.Bson.Serialization;
using MongoDB.Bson.Serialization.Attributes;
using MongoDB.Bson.Serialization.Serializers;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace Skincore.Api.Models;

// ────────────────────────────────────────────────────────────
// Tek bir resim URL'sini temsil eder (JSON'a bu şekilde çıkar)
// ────────────────────────────────────────────────────────────
public class ImageUrlItem
{
    [JsonPropertyName("fileUrl")]
    public string? FileUrl { get; set; }

    [JsonPropertyName("fileName")]
    public string? FileName { get; set; }
}

// ────────────────────────────────────────────────────────────
// MongoDB'den image_urls alanını okuyan custom BSON serializer.
// Karışık format: ["url_string"] veya [{fileUrl, fileName}]
// ────────────────────────────────────────────────────────────
public class ImageUrlListBsonSerializer : SerializerBase<List<ImageUrlItem>?>
{
    public override List<ImageUrlItem>? Deserialize(BsonDeserializationContext context, BsonDeserializationArgs args)
    {
        var bsonType = context.Reader.GetCurrentBsonType();

        if (bsonType == BsonType.Null)
        {
            context.Reader.ReadNull();
            return null;
        }

        if (bsonType != BsonType.Array)
        {
            context.Reader.SkipValue();
            return null;
        }

        var list = new List<ImageUrlItem>();
        context.Reader.ReadStartArray();

        while (context.Reader.ReadBsonType() != BsonType.EndOfDocument)
        {
            var currentType = context.Reader.CurrentBsonType;

            if (currentType == BsonType.String)
            {
                var url = context.Reader.ReadString();
                list.Add(new ImageUrlItem { FileUrl = url });
            }
            else if (currentType == BsonType.Document)
            {
                string? fileUrl = null;
                string? fileName = null;

                context.Reader.ReadStartDocument();
                while (context.Reader.ReadBsonType() != BsonType.EndOfDocument)
                {
                    var fieldName = context.Reader.ReadName();
                    if (fieldName == "fileUrl" && context.Reader.CurrentBsonType == BsonType.String)
                        fileUrl = context.Reader.ReadString();
                    else if (fieldName == "fileName" && context.Reader.CurrentBsonType == BsonType.String)
                        fileName = context.Reader.ReadString();
                    else
                        context.Reader.SkipValue();
                }
                context.Reader.ReadEndDocument();

                list.Add(new ImageUrlItem { FileUrl = fileUrl, FileName = fileName });
            }
            else
            {
                context.Reader.SkipValue();
            }
        }

        context.Reader.ReadEndArray();
        return list.Count > 0 ? list : null;
    }

    public override void Serialize(BsonSerializationContext context, BsonSerializationArgs args, List<ImageUrlItem>? value)
    {
        if (value == null)
        {
            context.Writer.WriteNull();
            return;
        }
        context.Writer.WriteStartArray();
        foreach (var item in value)
        {
            context.Writer.WriteStartDocument();
            context.Writer.WriteName("fileUrl");
            context.Writer.WriteString(item.FileUrl ?? "");
            context.Writer.WriteName("fileName");
            if (item.FileName != null) context.Writer.WriteString(item.FileName);
            else context.Writer.WriteNull();
            context.Writer.WriteEndDocument();
        }
        context.Writer.WriteEndArray();
    }
}

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

    [BsonElement("image_urls")]
    [JsonPropertyName("image_urls")]
    [BsonSerializer(typeof(ImageUrlListBsonSerializer))]
    public List<ImageUrlItem>? ImageUrls { get; set; }

    [BsonElement("embedding")]
    [BsonIgnoreIfNull]
    [JsonIgnore]
    public List<double>? Embedding { get; set; }
}
