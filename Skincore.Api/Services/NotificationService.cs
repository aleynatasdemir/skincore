using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Google.Apis.Auth.OAuth2;
using Skincore.Api.Models;

namespace Skincore.Api.Services;

public class NotificationService
{
    private readonly ILogger<NotificationService> _logger;
    private readonly MongoDbService _mongoDbService;
    private readonly bool _isFirebaseInitialized;

    public NotificationService(ILogger<NotificationService> logger, MongoDbService mongoDbService)
    {
        _logger = logger;
        _mongoDbService = mongoDbService;

        if (FirebaseApp.DefaultInstance == null)
        {
            var credentialPath = Path.Combine(Directory.GetCurrentDirectory(), "firebase-adminsdk.json");
            if (File.Exists(credentialPath))
            {
                FirebaseApp.Create(new AppOptions()
                {
                    Credential = GoogleCredential.FromJson(File.ReadAllText(credentialPath))
                });
                _isFirebaseInitialized = true;
                _logger.LogInformation("Firebase Admin SDK initialized successfully.");
            }
            else
            {
                _logger.LogWarning($"Firebase credential file not found at {credentialPath}. Push notifications will be disabled.");
                _isFirebaseInitialized = false;
            }
        }
        else
        {
            _isFirebaseInitialized = true;
        }
    }

    public async Task<bool> SendPushNotificationAsync(string fcmToken, string title, string body, Dictionary<string, string>? data = null, string? recipientUserId = null, string type = "system")
    {
        bool success = false;

        if (!_isFirebaseInitialized)
        {
            _logger.LogWarning("Cannot send push notification because Firebase is not initialized.");
        }
        else if (string.IsNullOrEmpty(fcmToken))
        {
            _logger.LogWarning("Cannot send push notification to an empty FCM token.");
        }
        else
        {
            try
            {
                var message = new Message()
                {
                    Token = fcmToken,
                    Notification = new Notification()
                    {
                        Title = title,
                        Body = body
                    },
                    Data = data ?? new Dictionary<string, string>()
                };

                string response = await FirebaseMessaging.DefaultInstance.SendAsync(message);
                _logger.LogInformation($"Successfully sent message: {response}");
                success = true;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error sending push notification to {fcmToken}");
            }
        }

        // Her durumda log at
        try
        {
            await _mongoDbService.NotificationLogsCollection.InsertOneAsync(new NotificationLog
            {
                RecipientUserId = recipientUserId,
                FcmToken = fcmToken,
                Title = title,
                Body = body,
                Type = type,
                Success = success,
                SentAt = DateTime.UtcNow
            });
        }
        catch { /* log hatası kritik değil */ }

        return success;
    }
}
