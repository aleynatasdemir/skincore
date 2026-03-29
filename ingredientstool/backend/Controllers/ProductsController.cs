using Microsoft.AspNetCore.Mvc;
using SilkProductManager.Api.Models;
using SilkProductManager.Api.Services;

namespace SilkProductManager.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ProductsController : ControllerBase
{
    private readonly ProductService _productService;

    public ProductsController(ProductService productService)
    {
        _productService = productService;
    }

    [HttpGet]
    public async Task<List<Product>> Get() =>
        await _productService.GetAsync();

    [HttpGet("{id:length(24)}")]
    public async Task<ActionResult<Product>> Get(string id)
    {
        var product = await _productService.GetAsync(id);
        if (product is null) return NotFound();
        return product;
    }

    [HttpGet("next-unprocessed")]
    public async Task<ActionResult<Product>> GetNextUnprocessed()
    {
        var product = await _productService.GetNextUnprocessedAsync();
        
        if (product is null)
        {
            return NotFound(new { message = "İşlenecek ürün bulunamadı." });
        }

        return product;
    }

    [HttpGet("unprocessed-list")]
    public async Task<ActionResult<List<Product>>> GetUnprocessedList([FromQuery] int page = 1, [FromQuery] int limit = 20)
    {
        // Basit pagination (Sayfalama)
        var products = await _productService.GetUnprocessedPagedAsync(page, limit);
        return products;
    }

    [HttpGet("search")]
    public async Task<ActionResult<List<Product>>> Search([FromQuery] string q)
    {
        if (string.IsNullOrWhiteSpace(q)) return BadRequest("Sorgu boş olamaz.");
        var products = await _productService.SearchAsync(q);
        return products;
    }

    public class DraftRequest
    {
        public string? Content { get; set; }
    }

    [HttpPost("{id:length(24)}/draft")]
    public async Task<IActionResult> SaveDraft(string id, [FromBody] DraftRequest draftData)
    {
        var product = await _productService.GetAsync(id);
        if (product is null) return NotFound();

        // Update fields based on provided comma-separated text
        if (!string.IsNullOrWhiteSpace(draftData.Content))
        {
            product.ProductIngredients = draftData.Content
                .Split(new[] { ',' }, StringSplitOptions.RemoveEmptyEntries)
                .Select(i => i.Trim())
                .ToList();
        }

        product.Status = "NeedsReview";

        await _productService.UpdateAsync(id, product);

        return Ok(new { message = "İçerik başarıyla kaydedildi.", product });
    }

    [HttpPost("{id:length(24)}/skip")]
    public async Task<IActionResult> SkipProduct(string id)
    {
        var product = await _productService.GetAsync(id);
        if (product is null) return NotFound();

        product.Status = "Skipped";
        await _productService.UpdateAsync(id, product);

        return Ok(new { message = "Ürün atlandı." });
    }

    [HttpPost("analyze-image")]
    public async Task<IActionResult> AnalyzeImage([FromForm] IFormFile image, [FromForm] string? barcode)
    {
        if (image == null || image.Length == 0)
        {
            return BadRequest("Resim yüklenmedi.");
        }

        // Save uploaded file permanently
        var imagesDir = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "images");
        if (!Directory.Exists(imagesDir))
        {
            Directory.CreateDirectory(imagesDir);
        }

        var fileName = !string.IsNullOrEmpty(barcode) ? $"{barcode}.jpg" : $"{Guid.NewGuid()}.jpg";
        var filePath = Path.Combine(imagesDir, fileName);

        using (var stream = new FileStream(filePath, FileMode.Create))
        {
            await image.CopyToAsync(stream);
        }

        try
        {
            var imageBytes = await System.IO.File.ReadAllBytesAsync(filePath);
            var base64Image = Convert.ToBase64String(imageBytes);

            var apiKey = "CLOUD_VISION_API_KEY";
            var url = $"https://vision.googleapis.com/v1/images:annotate?key={apiKey}";

            var requestBody = new
            {
                requests = new[]
                {
                    new
                    {
                        image = new { content = base64Image },
                        features = new[] { new { type = "DOCUMENT_TEXT_DETECTION" } }
                    }
                }
            };

            using var httpClient = new HttpClient();
            var content = new StringContent(System.Text.Json.JsonSerializer.Serialize(requestBody), System.Text.Encoding.UTF8, "application/json");
            
            var response = await httpClient.PostAsync(url, content);
            var responseString = await response.Content.ReadAsStringAsync();

            if (!response.IsSuccessStatusCode)
            {
                return StatusCode(500, $"Google Vision API Error: {response.StatusCode} - {responseString}");
            }

            string extracted = "";
            using var document = System.Text.Json.JsonDocument.Parse(responseString);
            var root = document.RootElement;
            if (root.TryGetProperty("responses", out var responsesObj) && responsesObj.GetArrayLength() > 0)
            {
                var firstResponse = responsesObj[0];
                if (firstResponse.TryGetProperty("fullTextAnnotation", out var fullText))
                {
                    extracted = fullText.GetProperty("text").GetString() ?? "";
                }
            }

            // Do not cleanup temp file, as we want to save it permanently

            return Ok(new { 
                Message = "Görsel başarıyla kaydedildi ve Google Cloud Vision ile analiz edildi.", 
                ExtractedContent = extracted.Trim(),
                ImageUrl = $"/images/{fileName}"
            });
        }
        catch (Exception ex)
        {
            return StatusCode(500, $"Internal Error: {ex.Message}");
        }
    }
}
