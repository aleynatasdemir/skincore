using Microsoft.Extensions.Options;
using MongoDB.Bson;
using MongoDB.Driver;
using Skincore.Api.Models;

namespace Skincore.Api.Services;

public class MongoDbService
{
    private readonly IMongoDatabase _database;

    public MongoDbService(IOptions<MongoDBSettings> settings)
    {
        var client = new MongoClient(settings.Value.ConnectionString);
        _database = client.GetDatabase(settings.Value.DatabaseName);
    }

    public IMongoCollection<Product> ProductsCollection => 
        _database.GetCollection<Product>("products");

    public IMongoCollection<Ingredient> IngredientsCollection => 
        _database.GetCollection<Ingredient>("ingredients");

    public IMongoCollection<User> UsersCollection => 
        _database.GetCollection<User>("users");

    public IMongoCollection<Routine> RoutinesCollection =>
        _database.GetCollection<Routine>("routines");

    public IMongoCollection<PopularSearch> PopularSearchesCollection =>
        _database.GetCollection<PopularSearch>("popular_searches");

    public IMongoCollection<ProductRequest> ProductRequestsCollection =>
        _database.GetCollection<ProductRequest>("product_requests");

    public async Task CreateIndexesAsync()
    {
        // Drop old problematic index if it exists
        try { await UsersCollection.Indexes.DropOneAsync("appleUserId_1"); }
        catch { /* Index may not exist */ }

        var emailIndex = new CreateIndexModel<User>(
            Builders<User>.IndexKeys.Ascending(u => u.Email),
            new CreateIndexOptions { Unique = true });

        // AppleUserId index for fast lookup (not unique - uniqueness handled in app logic)
        var appleUserIdIndex = new CreateIndexModel<User>(
            Builders<User>.IndexKeys.Ascending(u => u.AppleUserId));

        await UsersCollection.Indexes.CreateManyAsync(new[] { emailIndex, appleUserIdIndex });
    }
}
