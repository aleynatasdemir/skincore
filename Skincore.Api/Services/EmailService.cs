using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Options;
using Skincore.Api.Models;

namespace Skincore.Api.Services;

public class EmailService
{
    private readonly HttpClient _httpClient;
    private readonly ResendSettings _settings;
    private readonly ILogger<EmailService> _logger;

    public EmailService(IOptions<ResendSettings> settings, ILogger<EmailService> logger)
    {
        _settings = settings.Value;
        _logger = logger;
        _httpClient = new HttpClient
        {
            BaseAddress = new Uri("https://api.resend.com")
        };
        _httpClient.DefaultRequestHeaders.Authorization = 
            new AuthenticationHeaderValue("Bearer", _settings.ApiKey);
    }

    public async Task<bool> SendVerificationEmailAsync(string toEmail, string code)
    {
        try
        {
            var emailBody = new
            {
                from = $"{_settings.FromName} <{_settings.FromEmail}>",
                to = new[] { toEmail },
                subject = "SkinCore - E-posta Doğrulama Kodu",
                html = GetVerificationEmailHtml(code)
            };

            var json = JsonSerializer.Serialize(emailBody);
            var content = new StringContent(json, Encoding.UTF8, "application/json");

            var response = await _httpClient.PostAsync("/emails", content);

            if (response.IsSuccessStatusCode)
            {
                _logger.LogInformation("Verification email sent to {Email}", toEmail);
                return true;
            }

            var errorBody = await response.Content.ReadAsStringAsync();
            _logger.LogError("Failed to send email to {Email}. Status: {Status}, Body: {Body}", 
                toEmail, response.StatusCode, errorBody);
            return false;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Exception while sending email to {Email}", toEmail);
            return false;
        }
    }

    private static string GetVerificationEmailHtml(string code)
    {
        return $"""
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
        </head>
        <body style="margin:0;padding:0;background-color:#f4f4f7;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
            <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color:#f4f4f7;padding:40px 0;">
                <tr>
                    <td align="center">
                        <table role="presentation" width="420" cellspacing="0" cellpadding="0" style="background-color:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 2px 8px rgba(0,0,0,0.08);">
                            <tr>
                                <td style="background:linear-gradient(135deg,#6366f1,#8b5cf6);padding:32px;text-align:center;">
                                    <h1 style="margin:0;color:#ffffff;font-size:24px;font-weight:700;">SkinCore</h1>
                                </td>
                            </tr>
                            <tr>
                                <td style="padding:32px;">
                                    <h2 style="margin:0 0 12px;color:#1a1a2e;font-size:20px;">E-posta Doğrulama</h2>
                                    <p style="margin:0 0 24px;color:#6b7280;font-size:15px;line-height:1.5;">
                                        Hesabınızı doğrulamak için aşağıdaki kodu uygulamada girin. Kod <strong>10 dakika</strong> geçerlidir.
                                    </p>
                                    <div style="background-color:#f0f0ff;border:2px dashed #6366f1;border-radius:8px;padding:20px;text-align:center;margin-bottom:24px;">
                                        <span style="font-size:32px;font-weight:700;letter-spacing:8px;color:#6366f1;">{code}</span>
                                    </div>
                                    <p style="margin:0;color:#9ca3af;font-size:13px;line-height:1.5;">
                                        Bu işlemi siz yapmadıysanız bu e-postayı görmezden gelebilirsiniz.
                                    </p>
                                </td>
                            </tr>
                            <tr>
                                <td style="background-color:#f9fafb;padding:16px 32px;text-align:center;">
                                    <p style="margin:0;color:#9ca3af;font-size:12px;">© 2026 SkinCore</p>
                                </td>
                            </tr>
                        </table>
                    </td>
                </tr>
            </table>
        </body>
        </html>
        """;
    }
}
