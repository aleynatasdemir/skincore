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
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 50)
    {
        if (page < 1) page = 1;
        if (pageSize < 1 || pageSize > 100) pageSize = 50;

        var filter = string.IsNullOrEmpty(search) 
            ? Builders<Ingredient>.Filter.Empty 
            : Builders<Ingredient>.Filter.Regex(i => i.Name, new MongoDB.Bson.BsonRegularExpression(search, "i"));

        var ingredients = await _mongoDbService.IngredientsCollection
            .Find(filter)
            .Skip((page - 1) * pageSize)
            .Limit(pageSize)
            .ToListAsync();

        return Ok(ingredients);
    }
}
