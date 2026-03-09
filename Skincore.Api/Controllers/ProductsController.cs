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

    public ProductsController(MongoDbService mongoDbService, IngredientMatchingService matchingService)
    {
        _mongoDbService = mongoDbService;
        _matchingService = matchingService;
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
