using FuzzySharp;
using MongoDB.Driver;
using Skincore.Api.Models;

namespace Skincore.Api.Services;

public class ProductSearchService
{
    private readonly MongoDbService _mongoDbService;
    private Dictionary<string, string> _productNameToIdMap = new();
    private List<string> _searchableProductNames = new();

    public ProductSearchService(MongoDbService mongoDbService)
    {
        _mongoDbService = mongoDbService;
    }

    public async Task InitializeAsync()
    {
        var projection = Builders<Product>.Projection.Include(p => p.Id).Include(p => p.Name);
        var products = await _mongoDbService.ProductsCollection
            .Find(_ => true)
            .Project<Product>(projection)
            .ToListAsync();

        foreach (var product in products)
        {
            if (!string.IsNullOrWhiteSpace(product.Name) && product.Id != null)
            {
                var lowerName = product.Name.ToLowerInvariant().Trim();
                // Store the first occurrence if there are duplicates
                _productNameToIdMap.TryAdd(lowerName, product.Id);
            }
        }

        _searchableProductNames = _productNameToIdMap.Keys.ToList();
    }

    public async Task<List<Product>> SearchProductsByNameFuzzyAsync(string query, int maxResults = 5)
    {
        if (string.IsNullOrWhiteSpace(query) || _searchableProductNames.Count == 0)
        {
            return new List<Product>();
        }

        var normalizedQuery = query.ToLowerInvariant().Trim();
        
        // Find top N fuzzy matches
        var fuzzyResults = Process.ExtractTop(normalizedQuery, _searchableProductNames, limit: maxResults);
        
        var productIds = new List<string>();
        foreach (var result in fuzzyResults)
        {
            // We can set a reasonable threshold, e.g., score > 60
            if (result.Score > 60 && _productNameToIdMap.TryGetValue(result.Value, out var id))
            {
                productIds.Add(id);
            }
        }

        if (productIds.Count == 0)
        {
            return new List<Product>();
        }

        // Fetch full product details for the matched IDs
        var filter = Builders<Product>.Filter.In(p => p.Id, productIds);
        var matchedProducts = await _mongoDbService.ProductsCollection.Find(filter).ToListAsync();

        // Sort them back according to the fuzzy score order
        return matchedProducts.OrderBy(p => productIds.IndexOf(p.Id!)).ToList();
    }
}
