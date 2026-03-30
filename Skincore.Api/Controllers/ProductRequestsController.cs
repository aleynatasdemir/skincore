using System.Security.Claims;
using Microsoft.AspNetCore.Mvc;
using MongoDB.Driver;
using Skincore.Api.Models;
using Skincore.Api.Services;

namespace Skincore.Api.Controllers;

[ApiController]
[Route("api/product-requests")]
public class ProductRequestsController : ControllerBase
{
    private readonly MongoDbService _mongoDbService;
    private readonly IWebHostEnvironment _env;
    private readonly ILogger<ProductRequestsController> _logger;

    private static readonly string[] AllowedExtensions = [".jpg", ".jpeg", ".png", ".heic"];

    public ProductRequestsController(
        MongoDbService mongoDbService,
        IWebHostEnvironment env,
        ILogger<ProductRequestsController> logger)
    {
        _mongoDbService = mongoDbService;
        _env = env;
        _logger = logger;
    }

    /// <summary>
    /// POST /api/product-requests
    /// Kullanıcı bulamadığı ürünü ön yüz + içerik fotoğrafı ve marka adıyla gönderir.
    /// </summary>
    [HttpPost]
    [Consumes("multipart/form-data")]
    public async Task<IActionResult> Submit(
        [FromForm] string brandName,
        [FromForm] string? productName,
        IFormFile? frontImage,
        IFormFile? ingredientsImage)
    {
        if (string.IsNullOrWhiteSpace(brandName))
            return BadRequest(new MessageResponse { Message = "Marka adı gereklidir." });

        if (frontImage == null && ingredientsImage == null)
            return BadRequest(new MessageResponse { Message = "En az bir fotoğraf ekleyin." });

        var uploadDir = Path.Combine(_env.WebRootPath, "uploads", "product-requests");
        Directory.CreateDirectory(uploadDir);

        var frontImageUrl = await SaveImageAsync(frontImage, uploadDir);
        var ingredientsImageUrl = await SaveImageAsync(ingredientsImage, uploadDir);

        var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;

        var request = new ProductRequest
        {
            UserId = userId,
            BrandName = brandName.Trim(),
            ProductName = productName?.Trim(),
            FrontImageUrl = frontImageUrl,
            IngredientsImageUrl = ingredientsImageUrl,
            Status = "pending",
            CreatedAt = DateTime.UtcNow
        };

        await _mongoDbService.ProductRequestsCollection.InsertOneAsync(request);

        _logger.LogInformation("Product request submitted: {Brand} by user {UserId}", brandName, userId ?? "anonymous");

        return Ok(new MessageResponse { Message = "Ürün talebiniz alındı. En kısa sürede inceleyip veritabanına ekleyeceğiz." });
    }

    private async Task<string?> SaveImageAsync(IFormFile? file, string uploadDir)
    {
        if (file == null || file.Length == 0) return null;

        var extension = Path.GetExtension(file.FileName).ToLowerInvariant();
        if (!AllowedExtensions.Contains(extension)) return null;

        var fileName = $"{Guid.NewGuid()}{extension}";
        var filePath = Path.Combine(uploadDir, fileName);

        await using var stream = new FileStream(filePath, FileMode.Create);
        await file.CopyToAsync(stream);

        var baseUrl = $"{Request.Scheme}://{Request.Host}{Request.PathBase}";
        return $"{baseUrl}/uploads/product-requests/{fileName}";
    }
}
