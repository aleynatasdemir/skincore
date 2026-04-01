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

    public async Task<bool> SendPasswordResetEmailAsync(string toEmail, string code)
    {
        try
        {
            var emailBody = new
            {
                from = $"{_settings.FromName} <{_settings.FromEmail}>",
                to = new[] { toEmail },
                subject = "SkinCore - Şifre Sıfırlama Kodu",
                html = GetPasswordResetEmailHtml(code)
            };

            var json = JsonSerializer.Serialize(emailBody);
            var content = new StringContent(json, Encoding.UTF8, "application/json");

            var response = await _httpClient.PostAsync("/emails", content);

            if (response.IsSuccessStatusCode)
            {
                _logger.LogInformation("Password reset email sent to {Email}", toEmail);
                return true;
            }

            var errorBody = await response.Content.ReadAsStringAsync();
            _logger.LogError("Failed to send password reset email to {Email}. Status: {Status}, Body: {Body}",
                toEmail, response.StatusCode, errorBody);
            return false;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Exception while sending password reset email to {Email}", toEmail);
            return false;
        }
    }

    private static string GetPasswordResetEmailHtml(string code)
    {
        return $$"""
        <!DOCTYPE html>
        <html lang="tr">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Skincore Şifre Sıfırlama</title>
            <style>
                /* E-posta istemcileri için sıfırlamalar */
                body, table, td, a { -webkit-text-size-adjust: 100%; -ms-text-size-adjust: 100%; }
                table, td { mso-table-lspace: 0pt; mso-table-rspace: 0pt; }
                img { -ms-interpolation-mode: bicubic; }
                
                /* Genel Stil */
                body {
                    margin: 0;
                    padding: 0;
                    background-color: #FFFFFF;
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
                    -webkit-font-smoothing: antialiased;
                }
            </style>
        </head>
        <body style="margin: 0; padding: 0; background-color: #FFFFFF;">
        
            <table border="0" cellpadding="0" cellspacing="0" width="100%" style="max-width: 600px; margin: 0 auto; background-color: #FFFFFF;">
                
                <tr>
                    <td align="center" style="background-color: #DDA9B1; padding: 40px 20px;">
                        <h1 style="margin: 0; font-size: 28px; font-weight: 800; color: #FFFFFF; letter-spacing: -1px;">Skincore</h1>
                    </td>
                </tr>
        
                <tr>
                    <td align="left" style="padding: 40px 30px 20px 30px;">
                        <h2 style="margin: 0 0 15px 0; font-size: 20px; font-weight: 700; color: #1A1A1A;">Şifreni mi unuttun?</h2>
                        <p style="margin: 0 0 30px 0; font-size: 16px; line-height: 1.6; color: #4A4A4A;">
                            Şifrenizi sıfırlamak için aşağıdaki 6 haneli kodu uygulamanın şifre sıfırlama ekranına girebilirsin:
                        </p>
                    </td>
                </tr>
        
                <tr>
                    <td align="center" style="padding: 0 30px 40px 30px;">
                        <table border="0" cellpadding="0" cellspacing="0" style="width: 100%; max-width: 300px;">
                            <tr>
                                <td align="center" style="background-color: #FFF5F7; border: 2px dashed #DDA9B1; border-radius: 12px; padding: 25px 10px;">
                                    <div style="font-size: 36px; font-weight: 800; color: #DDA9B1; letter-spacing: 8px;">
                                        {{code}}
                                    </div>
                                </td>
                            </tr>
                        </table>
                    </td>
                </tr>
        
                <tr>
                    <td align="center" style="padding: 20px 30px; border-top: 1px solid #EEEEEE;">
                        <p style="margin: 0; font-size: 13px; line-height: 1.5; color: #999999;">
                            Bu kod 10 dakika boyunca geçerlidir.<br>
                            Eğer bu talebi sen yapmadıysan, şifren değiştirilmemiştir ve bu e-postayı görmezden gelebilirsin.
                        </p>
                        <p style="margin: 15px 0 0 0; font-size: 12px; color: #A0A0A0;">
                            &copy; 2026 Skincore. Otomatik sistem e-postasıdır.
                        </p>
                    </td>
                </tr>
        
            </table>
        
        </body>
        </html>
        """;
    }

    private static string GetVerificationEmailHtml(string code)
    {
        return $$"""
        <!DOCTYPE html>
        <html lang="tr">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Skincore Doğrulama Kodu</title>
            <style>
                /* E-posta istemcileri için sıfırlamalar */
                body, table, td, a { -webkit-text-size-adjust: 100%; -ms-text-size-adjust: 100%; }
                table, td { mso-table-lspace: 0pt; mso-table-rspace: 0pt; }
                img { -ms-interpolation-mode: bicubic; }
                
                /* Genel Stil */
                body {
                    margin: 0;
                    padding: 0;
                    background-color: #FFFFFF;
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
                    -webkit-font-smoothing: antialiased;
                }
            </style>
        </head>
        <body style="margin: 0; padding: 0; background-color: #FFFFFF;">
        
            <table border="0" cellpadding="0" cellspacing="0" width="100%" style="max-width: 600px; margin: 0 auto; background-color: #FFFFFF;">
                
                <tr>
                    <td align="center" style="background-color: #DDA9B1; padding: 40px 20px;">
                        <h1 style="margin: 0; font-size: 28px; font-weight: 800; color: #FFFFFF; letter-spacing: -1px;">Skincore</h1>
                    </td>
                </tr>
        
                <tr>
                    <td align="left" style="padding: 40px 30px 20px 30px;">
                        <h2 style="margin: 0 0 15px 0; font-size: 20px; font-weight: 700; color: #1A1A1A;">Neredeyse hazırsın!</h2>
                        <p style="margin: 0 0 30px 0; font-size: 16px; line-height: 1.6; color: #4A4A4A;">
                            E-posta adresini doğrulamak ve Skincore dünyasına giriş yapmak için aşağıdaki 6 haneli kodu uygulamadaki ilgili alana girmen yeterli:
                        </p>
                    </td>
                </tr>
        
                <tr>
                    <td align="center" style="padding: 0 30px 40px 30px;">
                        <table border="0" cellpadding="0" cellspacing="0" style="width: 100%; max-width: 300px;">
                            <tr>
                                <td align="center" style="background-color: #FFF5F7; border: 2px dashed #DDA9B1; border-radius: 12px; padding: 25px 10px;">
                                    <div style="font-size: 36px; font-weight: 800; color: #DDA9B1; letter-spacing: 8px;">
                                        {{code}}
                                    </div>
                                </td>
                            </tr>
                        </table>
                    </td>
                </tr>
        
                <tr>
                    <td align="center" style="padding: 20px 30px; border-top: 1px solid #EEEEEE;">
                        <p style="margin: 0; font-size: 13px; line-height: 1.5; color: #999999;">
                            Bu kod 10 dakika boyunca geçerlidir.<br>
                            Eğer bu talebi sen yapmadıysan, bu e-postayı görmezden gelebilirsin.
                        </p>
                        <p style="margin: 15px 0 0 0; font-size: 12px; color: #A0A0A0;">
                            &copy; 2026 Skincore. Otomatik sistem e-postasıdır.
                        </p>
                    </td>
                </tr>
        
            </table>
        
        </body>
        </html>
        """;
    }
}
