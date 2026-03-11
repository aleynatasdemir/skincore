using FuzzySharp;
using MongoDB.Driver;
using Skincore.Api.Models;

namespace Skincore.Api.Services;

public class ProductSearchService
{
    private readonly MongoDbService _mongoDbService;

    // Her ürün için aranabilir string → product Id map
    // Aynı ürün birden fazla key ile eşleşebilir (name + ocr_text + brand)
    private List<(string SearchKey, string ProductId)> _searchIndex = new();

    public ProductSearchService(MongoDbService mongoDbService)
    {
        _mongoDbService = mongoDbService;
    }

    public async Task InitializeAsync()
    {
        var projection = Builders<Product>.Projection
            .Include(p => p.Id)
            .Include(p => p.Name)
            .Include(p => p.Brand)
            .Include(p => p.OcrText);

        var products = await _mongoDbService.ProductsCollection
            .Find(_ => true)
            .Project<Product>(projection)
            .ToListAsync();

        _searchIndex.Clear();

        foreach (var product in products)
        {
            if (product.Id == null) continue;

            // 1. Ürün adı
            if (!string.IsNullOrWhiteSpace(product.Name))
                _searchIndex.Add((product.Name.ToLowerInvariant().Trim(), product.Id));

            // 2. ocr_text — etiket üzerindeki orijinal yazı
            if (!string.IsNullOrWhiteSpace(product.OcrText))
                _searchIndex.Add((product.OcrText.ToLowerInvariant().Trim(), product.Id));

            // 3. Marka adı (bonus — marka ile arama yapılabilsin)
            if (!string.IsNullOrWhiteSpace(product.Brand))
            {
                var brandPlusName = $"{product.Brand} {product.Name}".ToLowerInvariant().Trim();
                _searchIndex.Add((brandPlusName, product.Id));
            }
        }
    }

    public async Task<List<Product>> SearchProductsByNameFuzzyAsync(string query, int maxResults = 5)
    {
        if (string.IsNullOrWhiteSpace(query) || _searchIndex.Count == 0)
            return new List<Product>();

        var normalizedQuery = query.ToLowerInvariant().Trim();
        var searchKeys = _searchIndex.Select(x => x.SearchKey).ToList();

        // Fuzzy eşleştirme — tüm key'ler üzerinde
        var fuzzyResults = Process.ExtractTop(normalizedQuery, searchKeys, limit: maxResults * 3);

        // Score > 55 olanları al, product Id'ye çevir, tekrar edenleri kaldır
        var seenIds = new HashSet<string>();
        var productIds = new List<(string Id, int Score)>();

        foreach (var result in fuzzyResults)
        {
            if (result.Score < 55) continue;

            // Index üzerinden hangi product'a ait bul
            var match = _searchIndex.FirstOrDefault(x => x.SearchKey == result.Value);
            if (match.ProductId == null) continue;

            if (seenIds.Add(match.ProductId))
                productIds.Add((match.ProductId, result.Score));
        }

        // Score'a göre sırala, maxResults'a kırp
        var orderedIds = productIds
            .OrderByDescending(x => x.Score)
            .Take(maxResults)
            .Select(x => x.Id)
            .ToList();

        if (orderedIds.Count == 0)
            return new List<Product>();

        var filter = Builders<Product>.Filter.In(p => p.Id, orderedIds);
        var matchedProducts = await _mongoDbService.ProductsCollection.Find(filter).ToListAsync();

        return matchedProducts.OrderBy(p => orderedIds.IndexOf(p.Id!)).ToList();
    }
}
