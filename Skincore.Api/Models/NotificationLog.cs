using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace Skincore.Api.Models;

public class NotificationLog
{
    [BsonId]
    [BsonRepresentation(BsonType.ObjectId)]
    public string Id { get; set; } = null!;

    [BsonElement("recipientUserId")]
    public string? RecipientUserId { get; set; }

    [BsonElement("fcmToken")]
    public string? FcmToken { get; set; }

    [BsonElement("title")]
    public string Title { get; set; } = null!;

    [BsonElement("body")]
    public string Body { get; set; } = null!;

    [BsonElement("type")]
    public string Type { get; set; } = "system"; // like, comment, broadcast, system

    [BsonElement("success")]
    public bool Success { get; set; }

    [BsonElement("sentAt")]
    public DateTime SentAt { get; set; } = DateTime.UtcNow;
}
