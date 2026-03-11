using Microsoft.AspNetCore.Mvc;
using Skincore.Api.Models;
using Skincore.Api.Services;

namespace Skincore.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class PopularController : ControllerBase
{
    private readonly PopularSearchService _popularSearchService;

    public PopularController(PopularSearchService popularSearchService)
    {
        _popularSearchService = popularSearchService;
    }

    /// <summary>
    /// GET /api/popular?limit=10 - En çok aranan ürünleri getir (anasayfa)
    /// Ürün ismi ve fotoğrafı döner.
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> GetPopularProducts([FromQuery] int limit = 10)
    {
        if (limit < 1 || limit > 50)
            limit = 10;

        var products = await _popularSearchService.GetPopularProducts(limit);
        return Ok(products);
    }
}
