using Microsoft.Extensions.Options;
using MongoDB.Driver;
using SilkProductManager.Api.Models;

namespace SilkProductManager.Api.Services;

public class ProductService
{
    private readonly IMongoCollection<Product> _productsCollection;

    public ProductService(IOptions<MongoDbSettings> mongoDbSettings)
    {
        var mongoClient = new MongoClient(mongoDbSettings.Value.ConnectionString);
        var mongoDatabase = mongoClient.GetDatabase(mongoDbSettings.Value.DatabaseName);

        _productsCollection = mongoDatabase.GetCollection<Product>(mongoDbSettings.Value.ProductsCollectionName);
    }

    public async Task<List<Product>> GetAsync() =>
        await _productsCollection.Find(_ => true).ToListAsync();

    public async Task<Product?> GetAsync(string id) =>
        await _productsCollection.Find(x => x.Id == id).FirstOrDefaultAsync();

    // Get the next product that is in draft or needs review.
    public async Task<Product?> GetNextUnprocessedAsync() 
    {
        var filter = Builders<Product>.Filter.And(
            Builders<Product>.Filter.Ne(x => x.Barcode, null),
            Builders<Product>.Filter.Or(
                Builders<Product>.Filter.Eq(x => x.Status, "Draft"),
                Builders<Product>.Filter.Exists("status", false)
            )
        );
        return await _productsCollection.Find(filter).FirstOrDefaultAsync();
    }

    public async Task<List<Product>> GetUnprocessedPagedAsync(int page, int limit)
    {
        var filter = Builders<Product>.Filter.Or(
            Builders<Product>.Filter.Eq(x => x.Status, "Draft"),
            Builders<Product>.Filter.Exists("status", false)
        );

        int skip = (page - 1) * limit;

        return await _productsCollection.Find(filter)
            .Skip(skip)
            .Limit(limit)
            .ToListAsync();
    }

    public async Task CreateAsync(Product newProduct) =>
        await _productsCollection.InsertOneAsync(newProduct);

    public async Task UpdateAsync(string id, Product updatedProduct) =>
        await _productsCollection.ReplaceOneAsync(x => x.Id == id, updatedProduct);

    public async Task RemoveAsync(string id) =>
        await _productsCollection.DeleteOneAsync(x => x.Id == id);

    public async Task<List<Product>> SearchAsync(string query)
    {
        var filter = Builders<Product>.Filter.Or(
            Builders<Product>.Filter.Regex(p => p.ProductName, new MongoDB.Bson.BsonRegularExpression(query, "i")),
            Builders<Product>.Filter.Regex(p => p.Barcode, new MongoDB.Bson.BsonRegularExpression(query, "i"))
        );
        return await _productsCollection.Find(filter).Limit(20).ToListAsync();
    }
}
