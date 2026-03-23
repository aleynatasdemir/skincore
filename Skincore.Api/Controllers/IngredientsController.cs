using Microsoft.AspNetCore.Mvc;
using MongoDB.Driver;
using Skincore.Api.Models;
using Skincore.Api.Services;

namespace Skincore.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class IngredientsController : ControllerBase
{
    private readonly MongoDbService _mongoDbService;

    public IngredientsController(MongoDbService mongoDbService)
    {
        _mongoDbService = mongoDbService;
    }

    [HttpGet]
    public async Task<ActionResult<List<Ingredient>>> Get(
        [FromQuery] string? search = null,
        [FromQuery] int? minSafety = null,
        [FromQuery] int? maxSafety = null,
        [FromQuery] bool? comedogenic = null,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 50)
    {
        if (page < 1) page = 1;
        if (pageSize < 1 || pageSize > 100) pageSize = 50;

        var builder = Builders<Ingredient>.Filter;
        var filters = new List<FilterDefinition<Ingredient>>();

        if (!string.IsNullOrEmpty(search))
        {
            filters.Add(builder.Regex(i => i.Name, new MongoDB.Bson.BsonRegularExpression(search, "i")));
        }

        if (minSafety.HasValue)
        {
            filters.Add(builder.Gte(i => i.SafetyLevel, minSafety.Value));
        }

        if (maxSafety.HasValue)
        {
            filters.Add(builder.Lte(i => i.SafetyLevel, maxSafety.Value));
        }

        // Comedogenic filtresi: eğer true ise, comedogenic alanı null olmayanları getir
        if (comedogenic.HasValue && comedogenic.Value)
        {
            filters.Add(builder.Ne("comedogenic", BsonNull.Value));
        }

        var filter = filters.Count > 0 ? builder.And(filters) : builder.Empty;

        var ingredients = await _mongoDbService.IngredientsCollection
            .Find(filter)
            .Skip((page - 1) * pageSize)
            .Limit(pageSize)
            .ToListAsync();

        return Ok(ingredients);
    }
}
