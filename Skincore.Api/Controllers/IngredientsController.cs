using Microsoft.AspNetCore.Mvc;
using MongoDB.Bson;
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
        [FromQuery] string? safetyLabel = null,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 5000)
    {
        if (page < 1) page = 1;
        if (pageSize < 1 || pageSize > 10000) pageSize = 5000;

        var builder = Builders<Ingredient>.Filter;
        var filters = new List<FilterDefinition<Ingredient>>();

        if (!string.IsNullOrEmpty(search))
        {
            filters.Add(builder.Regex(i => i.InciName, new MongoDB.Bson.BsonRegularExpression(search, "i")));
        }

        if (minSafety.HasValue && minSafety >= 0)
        {
            filters.Add(builder.Gte("metrics.safety_level", minSafety.Value));
        }

        if (maxSafety.HasValue && maxSafety >= 0)
        {
            filters.Add(builder.Lte("metrics.safety_level", maxSafety.Value));
        }

        // Comedogenic filtresi: comedogenic_rating >= 1 olan ingredient'lar
        if (comedogenic.HasValue && comedogenic.Value)
        {
            filters.Add(builder.Gte("metrics.comedogenic_rating", 1));
        }

        if (!string.IsNullOrEmpty(safetyLabel))
        {
            filters.Add(builder.Eq("metrics.safety_label", safetyLabel));
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
