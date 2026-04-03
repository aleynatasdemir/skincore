using System.Net.Http.Json;
using System.Text.Json;
using Skincore.Api.Models;

namespace Skincore.Api.Services;

public class GoogleVisionOcrService
{
    private const string VisionEndpoint = "https://vision.googleapis.com/v1/images:annotate";

    private readonly HttpClient _httpClient;
    private readonly IConfiguration _configuration;
    private readonly ILogger<GoogleVisionOcrService> _logger;

    public GoogleVisionOcrService(
        HttpClient httpClient,
        IConfiguration configuration,
        ILogger<GoogleVisionOcrService> logger)
    {
        _httpClient = httpClient;
        _configuration = configuration;
        _logger = logger;
    }

    public async Task<(bool Success, string Message, OcrExtractResponse? Data)> ExtractTextFromBase64Async(string imageBase64, CancellationToken cancellationToken = default)
    {
        var apiKey = _configuration["GoogleVisionApiKey"] ?? _configuration["GoogleApiKey"];
        if (string.IsNullOrWhiteSpace(apiKey) || apiKey == "YOUR_GOOGLE_API_KEY_HERE")
            return (false, "Google Vision API key ayarlanmamış.", null);

        if (string.IsNullOrWhiteSpace(imageBase64))
            return (false, "Resim içeriği boş.", null);

        var payload = new
        {
            requests = new[]
            {
                new
                {
                    image = new { content = imageBase64 },
                    features = new[] { new { type = "DOCUMENT_TEXT_DETECTION", maxResults = 1 } }
                }
            }
        };

        using var visionRequest = new HttpRequestMessage(HttpMethod.Post, $"{VisionEndpoint}?key={Uri.EscapeDataString(apiKey)}")
        {
            Content = JsonContent.Create(payload)
        };

        HttpResponseMessage visionResponse;
        try { visionResponse = await _httpClient.SendAsync(visionRequest, cancellationToken); }
        catch (Exception ex) { _logger.LogError(ex, "Google Vision API isteği başarısız oldu."); return (false, "Google Vision API isteği başarısız oldu.", null); }

        var body = await visionResponse.Content.ReadAsStringAsync(cancellationToken);
        if (!visionResponse.IsSuccessStatusCode)
        {
            _logger.LogError("Google Vision API hata döndü. Status: {StatusCode}, Body: {Body}", visionResponse.StatusCode, body);
            return (false, "Google Vision API OCR işlemi başarısız oldu.", null);
        }

        try
        {
            using var document = JsonDocument.Parse(body);
            var root = document.RootElement;
            if (!root.TryGetProperty("responses", out var responses) || responses.GetArrayLength() == 0)
                return (false, "OCR cevabı boş döndü.", null);

            var first = responses[0];
            if (first.TryGetProperty("error", out var errorProp))
            {
                var message = errorProp.TryGetProperty("message", out var msg) ? msg.GetString() : "Google Vision hata döndürdü.";
                return (false, message ?? "Google Vision hata döndürdü.", null);
            }

            var extracted = ExtractText(first);
            if (string.IsNullOrWhiteSpace(extracted)) return (false, "Resimde okunabilir metin bulunamadı.", null);

            return (true, "OCR başarılı.", new OcrExtractResponse { Text = extracted, Confidence = ExtractConfidence(first), CharacterCount = extracted.Length });
        }
        catch (Exception ex) { _logger.LogError(ex, "OCR cevabı parse edilemedi."); return (false, "OCR cevabı işlenemedi.", null); }
    }

    public async Task<(bool Success, string Message, OcrExtractResponse? Data)> ExtractTextFromImageUrlAsync(
        string imageUrl,
        CancellationToken cancellationToken = default)
    {
        var apiKey = _configuration["GoogleVisionApiKey"] ?? _configuration["GoogleApiKey"];
        if (string.IsNullOrWhiteSpace(apiKey) || apiKey == "YOUR_GOOGLE_API_KEY_HERE")
            return (false, "Google Vision API key ayarlanmamış.", null);

        if (!Uri.TryCreate(imageUrl, UriKind.Absolute, out var uri))
            return (false, "Geçersiz resim URL'si.", null);

        byte[] imageBytes;
        try
        {
            imageBytes = await _httpClient.GetByteArrayAsync(uri, cancellationToken);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "OCR için resim indirilemedi: {ImageUrl}", imageUrl);
            return (false, "OCR için resim indirilemedi.", null);
        }

        if (imageBytes.Length == 0)
            return (false, "Resim içeriği boş.", null);

        var payload = new
        {
            requests = new[]
            {
                new
                {
                    image = new { content = Convert.ToBase64String(imageBytes) },
                    features = new[]
                    {
                        new { type = "DOCUMENT_TEXT_DETECTION", maxResults = 1 }
                    }
                }
            }
        };

        using var visionRequest = new HttpRequestMessage(
            HttpMethod.Post,
            $"{VisionEndpoint}?key={Uri.EscapeDataString(apiKey)}")
        {
            Content = JsonContent.Create(payload)
        };

        HttpResponseMessage visionResponse;
        try
        {
            visionResponse = await _httpClient.SendAsync(visionRequest, cancellationToken);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Google Vision API isteği başarısız oldu.");
            return (false, "Google Vision API isteği başarısız oldu.", null);
        }

        var body = await visionResponse.Content.ReadAsStringAsync(cancellationToken);
        if (!visionResponse.IsSuccessStatusCode)
        {
            _logger.LogError("Google Vision API hata döndü. Status: {StatusCode}, Body: {Body}", visionResponse.StatusCode, body);
            return (false, "Google Vision API OCR işlemi başarısız oldu.", null);
        }

        try
        {
            using var document = JsonDocument.Parse(body);
            var root = document.RootElement;
            if (!root.TryGetProperty("responses", out var responses) || responses.GetArrayLength() == 0)
                return (false, "OCR cevabı boş döndü.", null);

            var first = responses[0];
            if (first.TryGetProperty("error", out var errorProp))
            {
                var message = errorProp.TryGetProperty("message", out var msg)
                    ? msg.GetString()
                    : "Google Vision hata döndürdü.";
                return (false, message ?? "Google Vision hata döndürdü.", null);
            }

            var extracted = ExtractText(first);
            if (string.IsNullOrWhiteSpace(extracted))
                return (false, "Resimde okunabilir metin bulunamadı.", null);

            return (true, "OCR başarılı.", new OcrExtractResponse
            {
                Text = extracted,
                Confidence = ExtractConfidence(first),
                CharacterCount = extracted.Length
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "OCR cevabı parse edilemedi.");
            return (false, "OCR cevabı işlenemedi.", null);
        }
    }

    private static string ExtractText(JsonElement responseItem)
    {
        if (responseItem.TryGetProperty("fullTextAnnotation", out var fullText) &&
            fullText.TryGetProperty("text", out var text) &&
            text.ValueKind == JsonValueKind.String)
        {
            return text.GetString()?.Trim() ?? string.Empty;
        }

        if (responseItem.TryGetProperty("textAnnotations", out var textAnnotations) &&
            textAnnotations.ValueKind == JsonValueKind.Array &&
            textAnnotations.GetArrayLength() > 0 &&
            textAnnotations[0].TryGetProperty("description", out var description) &&
            description.ValueKind == JsonValueKind.String)
        {
            return description.GetString()?.Trim() ?? string.Empty;
        }

        return string.Empty;
    }

    private static double? ExtractConfidence(JsonElement responseItem)
    {
        if (!responseItem.TryGetProperty("fullTextAnnotation", out var fullText))
            return null;

        if (!fullText.TryGetProperty("pages", out var pages) || pages.ValueKind != JsonValueKind.Array)
            return null;

        var values = new List<double>();
        foreach (var page in pages.EnumerateArray())
        {
            if (page.TryGetProperty("confidence", out var c) && c.TryGetDouble(out var d))
                values.Add(d);
        }

        if (values.Count == 0) return null;
        var avg = values.Average() * 100d;
        return Math.Round(avg, 1);
    }
}

