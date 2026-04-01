using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Google.Apis.Auth.OAuth2;

namespace Skincore.Api.Services;

public class NotificationService
{
    private readonly ILogger<NotificationService> _logger;
    private readonly bool _isFirebaseInitialized;

    public NotificationService(ILogger<NotificationService> logger)
    {
        _logger = logger;
        
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

    public async Task<bool> SendPushNotificationAsync(string fcmToken, string title, string body, Dictionary<string, string>? data = null)
    {
        if (!_isFirebaseInitialized)
        {
            _logger.LogWarning("Cannot send push notification because Firebase is not initialized.");
            return false;
        }

        if (string.IsNullOrEmpty(fcmToken))
        {
            _logger.LogWarning("Cannot send push notification to an empty FCM token.");
            return false;
        }

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
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, $"Error sending push notification to {fcmToken}");
            return false;
        }
    }
}
