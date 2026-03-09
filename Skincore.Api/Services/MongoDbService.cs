using Microsoft.Extensions.Options;
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
}
