using Microsoft.AspNetCore.Mvc;
using MongoDB.Driver;
using Skincore.Api.Models;
using Skincore.Api.Services;

namespace Skincore.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ProductsController : ControllerBase
{
    private readonly MongoDbService _mongoDbService;
    private readonly IngredientMatchingService _matchingService;
    private readonly ProductSearchService _productSearchService;

    public ProductsController(
        MongoDbService mongoDbService, 
        IngredientMatchingService matchingService,
        ProductSearchService productSearchService)
    {
        _mongoDbService = mongoDbService;
        _matchingService = matchingService;
        _productSearchService = productSearchService;
    }

    [HttpGet("search/name")]
    public async Task<ActionResult<List<Product>>> SearchByNameFuzzy([FromQuery] string query, [FromQuery] int maxResults = 5)
    {
        if (string.IsNullOrWhiteSpace(query))
        {
            return BadRequest("Query parameter is required.");
        }

        var results = await _productSearchService.SearchProductsByNameFuzzyAsync(query, maxResults);
        return Ok(results);
    }

    [HttpGet("search/barcode")]
    public async Task<ActionResult<Product>> SearchByBarcodeExact([FromQuery] string barcode)
    {
        if (string.IsNullOrWhiteSpace(barcode))
        {
            return BadRequest("Barcode parameter is required.");
        }

        var product = await _mongoDbService.ProductsCollection
            .Find(p => p.Barcode == barcode)
            .FirstOrDefaultAsync();

        if (product == null)
            return NotFound(new { message = "Product not found with the given barcode." });

        return Ok(product);
    }

    [HttpGet]
    public async Task<ActionResult<List<Product>>> Get(
        [FromQuery] string? search = null,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20)
    {
        if (page < 1) page = 1;
        if (pageSize < 1 || pageSize > 100) pageSize = 20;

        var filter = string.IsNullOrEmpty(search) 
            ? Builders<Product>.Filter.Empty 
            : Builders<Product>.Filter.Regex(p => p.Name, new MongoDB.Bson.BsonRegularExpression(search, "i"));

        var products = await _mongoDbService.ProductsCollection
            .Find(filter)
            .Skip((page - 1) * pageSize)
            .Limit(pageSize)
            .ToListAsync();

        return Ok(products);
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<ProductWithEnrichedIngredients>> GetProductWithIngredients(string id)
    {
        var product = await _mongoDbService.ProductsCollection
            .Find(p => p.Id == id)
            .FirstOrDefaultAsync();

        if (product == null)
            return NotFound();

        var enrichedProduct = new ProductWithEnrichedIngredients(product);

        if (product.ProductIngredients != null && product.ProductIngredients.Count > 0)
        {
            foreach (var ingredientStr in product.ProductIngredients)
            {
                var matchResult = _matchingService.MatchIngredient(ingredientStr);
                enrichedProduct.EnrichedIngredients.Add(matchResult);
            }
        }

        return Ok(enrichedProduct);
    }
}
