using MongoDB.Driver;
using Skincore.Api.Models;

namespace Skincore.Api.Services;

public class UserProfileService
{
    private readonly IMongoCollection<User> _users;
    private readonly IMongoCollection<Product> _products;

    public UserProfileService(MongoDbService mongoDbService)
    {
        _users = mongoDbService.UsersCollection;
        _products = mongoDbService.ProductsCollection;
    }

    // ==================== PROFİL ====================

    public async Task<UserProfileResponse?> GetProfile(string userId)
    {
        var user = await _users.Find(u => u.Id == userId).FirstOrDefaultAsync();
        if (user == null) return null;

        return MapToProfileResponse(user);
    }

    public async Task<bool> UpdateProfile(string userId, UpdateProfileRequest request)
    {
        var updateDefs = new List<UpdateDefinition<User>>();

        if (request.DisplayName != null)
            updateDefs.Add(Builders<User>.Update.Set(u => u.FullName, request.DisplayName));

        if (request.SkinType != null)
        {
            var validSkinTypes = new[] { "Normal", "Kuru", "Yağlı", "Karma", "Hassas", "Akneye Meyilli", "Olgun" };
            if (!validSkinTypes.Contains(request.SkinType))
            {
                // Geçersiz cilt tipi
                return false;
            }
            updateDefs.Add(Builders<User>.Update.Set(u => u.SkinType, request.SkinType));
        }

        if (request.Username != null)
        {
            var sanitizedUsername = request.Username.Trim();
            // Check if username is already taken by someone else (case-insensitive)
            var existingUser = await _users.Find(u => 
                u.Id != userId && 
                u.Username != null && 
                u.Username.ToLower() == sanitizedUsername.ToLower()
            ).FirstOrDefaultAsync();

            if (existingUser != null)
            {
                return false; // Username is already taken
            }
            
            updateDefs.Add(Builders<User>.Update.Set(u => u.Username, sanitizedUsername));
        }

        if (updateDefs.Count == 0)
            return false;

        updateDefs.Add(Builders<User>.Update.Set(u => u.UpdatedAt, DateTime.UtcNow));

        var combinedUpdate = Builders<User>.Update.Combine(updateDefs);
        var result = await _users.UpdateOneAsync(u => u.Id == userId, combinedUpdate);
        return result.ModifiedCount > 0;
    }

    public async Task<bool> IsUsernameAvailable(string username)
    {
        if (string.IsNullOrWhiteSpace(username)) return false;
        
        var sanitizedUsername = username.Trim().ToLower();
        var count = await _users.CountDocumentsAsync(u => 
            u.Username != null && u.Username.ToLower() == sanitizedUsername);
            
        return count == 0;
    }

    // ==================== FAVORİLER ====================

    public async Task<List<FavoriteResponse>> GetFavorites(string userId)
    {
        var user = await _users.Find(u => u.Id == userId).FirstOrDefaultAsync();
        if (user == null) return new List<FavoriteResponse>();

        // Ürün image_urls'lerini çek
        var productIds = user.Favorites
            .Select(f => f.ProductId)
            .Where(id => !string.IsNullOrEmpty(id))
            .Distinct()
            .Select(MongoDB.Bson.ObjectId.Parse)
            .ToList();

        var productFilter = Builders<Product>.Filter.In("_id", productIds);
        var products = await _products.Find(productFilter).ToListAsync();

        return user.Favorites
            .OrderByDescending(f => f.AddedAt)
            .Select(f =>
            {
                var product = products.FirstOrDefault(p => p.Id == f.ProductId);
                var response = MapToFavoriteResponse(f);
                response.ProductImageURL ??= PopularSearchService.ExtractFirstImageUrl(product);
                return response;
            })
            .ToList();
    }

    public async Task<(bool Success, string Message)> AddFavorite(string userId, AddFavoriteRequest request)
    {
        var user = await _users.Find(u => u.Id == userId).FirstOrDefaultAsync();
        if (user == null) return (false, "Kullanıcı bulunamadı.");

        if (user.Favorites.Any(f => f.ProductId == request.ProductId))
            return (false, "Bu ürün zaten favorilerinizde.");

        var favorite = new FavoriteProduct
        {
            ProductId = request.ProductId,
            ProductName = request.ProductName,
            ProductBrand = request.ProductBrand,
            ProductImageURL = request.ProductImageURL,
            AddedAt = DateTime.UtcNow
        };

        var update = Builders<User>.Update
            .Push(u => u.Favorites, favorite)
            .Set(u => u.UpdatedAt, DateTime.UtcNow);

        await _users.UpdateOneAsync(u => u.Id == userId, update);
        return (true, "Favorilere eklendi.");
    }

    public async Task<(bool Success, string Message)> RemoveFavorite(string userId, string productId)
    {
        var update = Builders<User>.Update
            .PullFilter(u => u.Favorites, f => f.ProductId == productId)
            .Set(u => u.UpdatedAt, DateTime.UtcNow);

        var result = await _users.UpdateOneAsync(u => u.Id == userId, update);

        return result.ModifiedCount > 0
            ? (true, "Favorilerden kaldırıldı.")
            : (false, "Ürün favorilerde bulunamadı.");
    }

    public async Task<(bool IsFavorite, string Message)> ToggleFavorite(string userId, AddFavoriteRequest request)
    {
        var user = await _users.Find(u => u.Id == userId).FirstOrDefaultAsync();
        if (user == null) return (false, "Kullanıcı bulunamadı.");

        if (user.Favorites.Any(f => f.ProductId == request.ProductId))
        {
            await RemoveFavorite(userId, request.ProductId);
            return (false, "Favorilerden kaldırıldı.");
        }
        else
        {
            await AddFavorite(userId, request);
            return (true, "Favorilere eklendi.");
        }
    }

    public async Task<bool> IsFavorite(string userId, string productId)
    {
        var filter = Builders<User>.Filter.And(
            Builders<User>.Filter.Eq(u => u.Id, userId),
            Builders<User>.Filter.ElemMatch(u => u.Favorites, f => f.ProductId == productId)
        );

        var count = await _users.CountDocumentsAsync(filter);
        return count > 0;
    }

    // ==================== ARAMA GEÇMİŞİ ====================

    public async Task<List<SearchHistoryResponse>> GetSearchHistory(string userId, int limit = 20)
    {
        var user = await _users.Find(u => u.Id == userId).FirstOrDefaultAsync();
        if (user == null) return new List<SearchHistoryResponse>();

        var items = user.SearchHistory
            .OrderByDescending(s => s.SearchedAt)
            .Take(limit)
            .ToList();

        // Ürün image_urls'lerini çek
        var productIds = items
            .Where(s => !string.IsNullOrEmpty(s.ProductId))
            .Select(s => MongoDB.Bson.ObjectId.Parse(s.ProductId!))
            .Distinct()
            .ToList();

        var products = new List<Product>();
        if (productIds.Count > 0)
        {
            var productFilter = Builders<Product>.Filter.In("_id", productIds);
            products = await _products.Find(productFilter).ToListAsync();
        }

        return items.Select(s =>
        {
            var response = MapToSearchHistoryResponse(s);
            if (!string.IsNullOrEmpty(s.ProductId))
            {
                var product = products.FirstOrDefault(p => p.Id == s.ProductId);
                response.ImageUrl = PopularSearchService.ExtractFirstImageUrl(product);
            }
            return response;
        }).ToList();
    }

    public async Task AddSearchHistory(string userId, AddSearchHistoryRequest request)
    {
        // Aynı query varsa kaldır (tekrar en üste eklenecek)
        var pullUpdate = Builders<User>.Update
            .PullFilter(u => u.SearchHistory, s => s.Query.ToLower() == request.Query.ToLower());
        await _users.UpdateOneAsync(u => u.Id == userId, pullUpdate);

        var item = new SearchHistoryItem
        {
            Query = request.Query,
            ProductId = request.ProductId,
            ProductName = request.ProductName,
            Category = request.Category,
            SearchedAt = DateTime.UtcNow
        };

        // Maximum 50 kayıt tut
        var user = await _users.Find(u => u.Id == userId).FirstOrDefaultAsync();
        if (user != null && user.SearchHistory.Count >= 50)
        {
            var oldest = user.SearchHistory.OrderBy(s => s.SearchedAt).First();
            var removeOldest = Builders<User>.Update
                .PullFilter(u => u.SearchHistory, s => s.Id == oldest.Id);
            await _users.UpdateOneAsync(u => u.Id == userId, removeOldest);
        }

        var update = Builders<User>.Update
            .Push(u => u.SearchHistory, item)
            .Set(u => u.UpdatedAt, DateTime.UtcNow);

        await _users.UpdateOneAsync(u => u.Id == userId, update);
    }

    public async Task<bool> DeleteSearchHistoryItem(string userId, string itemId)
    {
        var update = Builders<User>.Update
            .PullFilter(u => u.SearchHistory, s => s.Id == itemId)
            .Set(u => u.UpdatedAt, DateTime.UtcNow);

        var result = await _users.UpdateOneAsync(u => u.Id == userId, update);
        return result.ModifiedCount > 0;
    }

    public async Task ClearSearchHistory(string userId)
    {
        var update = Builders<User>.Update
            .Set(u => u.SearchHistory, new List<SearchHistoryItem>())
            .Set(u => u.UpdatedAt, DateTime.UtcNow);

        await _users.UpdateOneAsync(u => u.Id == userId, update);
    }

    // ==================== MAPPERS ====================

    private static UserProfileResponse MapToProfileResponse(User user) => new()
    {
        Id = user.Id,
        Email = user.Email,
        FullName = user.FullName,
        SkinType = user.SkinType,
        Username = user.Username,
        CreatedAt = user.CreatedAt,
        UpdatedAt = user.UpdatedAt
    };

    private static FavoriteResponse MapToFavoriteResponse(FavoriteProduct f) => new()
    {
        Id = f.Id,
        ProductId = f.ProductId,
        ProductName = f.ProductName,
        ProductBrand = f.ProductBrand,
        ProductImageURL = f.ProductImageURL,
        AddedAt = f.AddedAt
    };

    private static SearchHistoryResponse MapToSearchHistoryResponse(SearchHistoryItem s) => new()
    {
        Id = s.Id,
        Query = s.Query,
        ProductId = s.ProductId,
        ProductName = s.ProductName,
        Category = s.Category,
        SearchedAt = s.SearchedAt
    };
}
