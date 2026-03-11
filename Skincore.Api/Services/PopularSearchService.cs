using MongoDB.Bson;
using MongoDB.Driver;
using Skincore.Api.Models;

namespace Skincore.Api.Services;

public class PopularSearchService
{
    private readonly IMongoCollection<PopularSearch> _popularSearches;
    private readonly IMongoCollection<Product> _products;

    public PopularSearchService(MongoDbService mongoDbService)
    {
        _popularSearches = mongoDbService.PopularSearchesCollection;
        _products = mongoDbService.ProductsCollection;
    }

    /// <summary>
    /// Ürün arandığında sayacı artır. Yoksa yeni kayıt oluştur.
    /// </summary>
    public async Task IncrementSearchCount(string productId, string productName)
    {
        var filter = Builders<PopularSearch>.Filter.Eq(p => p.ProductId, productId);
        var update = Builders<PopularSearch>.Update
            .Inc(p => p.SearchCount, 1)
            .Set(p => p.ProductName, productName)
            .Set(p => p.LastSearchedAt, DateTime.UtcNow);

        await _popularSearches.UpdateOneAsync(filter, update, new UpdateOptions { IsUpsert = true });
    }

    /// <summary>
    /// En çok aranan ürünleri getir (anasayfa için).
    /// </summary>
    public async Task<List<PopularProductResponse>> GetPopularProducts(int limit = 10)
    {
        var popularSearches = await _popularSearches
            .Find(_ => true)
            .SortByDescending(p => p.SearchCount)
            .Limit(limit)
            .ToListAsync();

        if (popularSearches.Count == 0)
            return new List<PopularProductResponse>();

        var productIds = popularSearches
            .Select(p => ObjectId.Parse(p.ProductId))
            .ToList();

        var productFilter = Builders<Product>.Filter.In("_id", productIds);
        var products = await _products.Find(productFilter).ToListAsync();

        var result = new List<PopularProductResponse>();

        foreach (var search in popularSearches)
        {
            var product = products.FirstOrDefault(p => p.Id == search.ProductId);

            var response = new PopularProductResponse
            {
                ProductId = search.ProductId,
                ProductName = search.ProductName,
                ImageUrl = ExtractFirstImageUrl(product)
            };

            result.Add(response);
        }

        return result;
    }

    public static string? ExtractFirstImageUrl(Product? product)
    {
        if (product?.ExtraElements == null) return null;
        if (!product.ExtraElements.TryGetValue("image_urls", out var imageUrlsObj)) return null;

        if (imageUrlsObj is MongoDB.Bson.BsonArray bsonArray && bsonArray.Count > 0)
        {
            var first = bsonArray[0];
            if (first.IsString) return first.AsString;
            if (first.IsBsonDocument && first.AsBsonDocument.Contains("fileUrl"))
                return first.AsBsonDocument["fileUrl"].AsString;
        }

        return null;
    }
}
