using MongoDB.Bson;
using MongoDB.Driver;
using Skincore.Api.Models;

namespace Skincore.Api.Services;

public class SocialRoutinesService
{
    private readonly IMongoCollection<Routine> _routines;
    private readonly IMongoCollection<User> _users;

    public SocialRoutinesService(MongoDbService mongoDbService)
    {
        _routines = mongoDbService.RoutinesCollection;
        _users = mongoDbService.UsersCollection;
    }

    public async Task<List<RoutineFeedItemResponse>> GetFeed(string userId, int limit = 20, string? search = null)
    {
        var filter = Builders<Routine>.Filter.Empty;

        if (!string.IsNullOrWhiteSpace(search))
        {
            var regex = new BsonRegularExpression(search, "i");
            filter = Builders<Routine>.Filter.Or(
                Builders<Routine>.Filter.Regex(r => r.Title, regex),
                Builders<Routine>.Filter.Regex(r => r.UserName, regex),
                Builders<Routine>.Filter.Regex(r => r.Description, regex)
            );
        }

        var routines = await _routines
            .Find(filter)
            .SortByDescending(r => r.CreatedAt)
            .Limit(limit)
            .ToListAsync();

        return routines.Select(r => MapToFeed(r, userId)).ToList();
    }
    public async Task<RoutineDetailResponse?> GetById(string routineId, string userId)
    {
        var routine = await _routines.Find(r => r.Id == routineId).FirstOrDefaultAsync();
        if (routine == null) return null;

        return MapToDetail(routine, userId);
    }

    public async Task<List<RoutineFeedItemResponse>> GetRoutinesByUserId(string userId)
    {
        var routines = await _routines
            .Find(r => r.UserId == userId)
            .SortByDescending(r => r.CreatedAt)
            .ToListAsync();

        return routines.Select(r => MapToFeed(r, userId)).ToList();
    }

    public async Task<RoutineDetailResponse> CreateRoutine(string userId, CreateRoutineRequest request)
    {
        var user = await _users.Find(u => u.Id == userId).FirstOrDefaultAsync();
        var userName = user?.FullName ?? user?.Email ?? "User";

        var tags = request.Tags
            ?.Where(t => !string.IsNullOrWhiteSpace(t))
            .Select(t => t.Trim())
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList() ?? new List<string>();

        var products = request.Products
            ?.Where(p => !string.IsNullOrWhiteSpace(p.ProductId) && !string.IsNullOrWhiteSpace(p.Name))
            .Select(p => new RoutineProduct
            {
                ProductId = p.ProductId,
                Name = p.Name,
                Brand = p.Brand,
                ImageUrl = p.ImageUrl
            })
            .ToList() ?? new List<RoutineProduct>();

        var routine = new Routine
        {
            Id = ObjectId.GenerateNewId().ToString(),
            UserId = userId,
            UserName = userName,
            Title = request.Title.Trim(),
            Description = request.Description?.Trim(),
            SkinType = request.SkinType?.Trim(),
            Focus = request.Focus?.Trim(),
            RoutineType = request.RoutineType?.Trim(),
            Tags = tags,
            CoverImageUrl = request.CoverImageUrl, // No fallback
            Products = products,
            Likes = new List<string>(),
            Comments = new List<RoutineComment>(),
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        await _routines.InsertOneAsync(routine);
        return MapToDetail(routine, userId);
    }

    public async Task<RoutineCommentResponse?> AddComment(string userId, string routineId, string text)
    {
        var routine = await _routines.Find(r => r.Id == routineId).FirstOrDefaultAsync();
        if (routine == null) return null;

        var user = await _users.Find(u => u.Id == userId).FirstOrDefaultAsync();
        var userName = user?.FullName ?? user?.Email ?? "User";

        var comment = new RoutineComment
        {
            UserId = userId,
            UserName = userName,
            Text = text.Trim(),
            CreatedAt = DateTime.UtcNow
        };

        var update = Builders<Routine>.Update
            .Push(r => r.Comments, comment)
            .Set(r => r.UpdatedAt, DateTime.UtcNow);

        await _routines.UpdateOneAsync(r => r.Id == routineId, update);

        return MapToComment(comment);
    }

    public async Task<ToggleLikeResponse?> ToggleLike(string userId, string routineId)
    {
        var routine = await _routines.Find(r => r.Id == routineId).FirstOrDefaultAsync();
        if (routine == null) return null;

        var hasLiked = routine.Likes.Contains(userId);
        var update = hasLiked
            ? Builders<Routine>.Update.Pull(r => r.Likes, userId)
            : Builders<Routine>.Update.AddToSet(r => r.Likes, userId);

        update = update.Set(r => r.UpdatedAt, DateTime.UtcNow);
        await _routines.UpdateOneAsync(r => r.Id == routineId, update);

        var likeCount = hasLiked
            ? Math.Max(0, routine.Likes.Count - 1)
            : routine.Likes.Count + 1;

        return new ToggleLikeResponse
        {
            IsLiked = !hasLiked,
            LikeCount = likeCount
        };
    }

    private static RoutineFeedItemResponse MapToFeed(Routine routine, string userId) => new()
    {
        Id = routine.Id,
        UserName = routine.UserName,
        SkinType = routine.SkinType,
        Focus = routine.Focus,
        Title = routine.Title,
        Description = routine.Description,
        CoverImageUrl = routine.CoverImageUrl,
        Tags = routine.Tags ?? new List<string>(),
        LikeCount = routine.Likes?.Count ?? 0,
        CommentCount = routine.Comments?.Count ?? 0,
        HasLiked = routine.Likes?.Contains(userId) ?? false,
        Products = routine.Products?.Select(MapToProduct).ToList() ?? new List<RoutineProductResponse>(),
        CreatedAt = routine.CreatedAt
    };

    private static RoutineDetailResponse MapToDetail(Routine routine, string userId) => new()
    {
        Id = routine.Id,
        UserName = routine.UserName,
        SkinType = routine.SkinType,
        Focus = routine.Focus,
        Title = routine.Title,
        Description = routine.Description,
        CoverImageUrl = routine.CoverImageUrl,
        RoutineType = routine.RoutineType,
        Tags = routine.Tags ?? new List<string>(),
        LikeCount = routine.Likes?.Count ?? 0,
        CommentCount = routine.Comments?.Count ?? 0,
        HasLiked = routine.Likes?.Contains(userId) ?? false,
        CreatedAt = routine.CreatedAt,
        Products = routine.Products?.Select(MapToProduct).ToList() ?? new List<RoutineProductResponse>(),
        Comments = routine.Comments?.Select(MapToComment).ToList() ?? new List<RoutineCommentResponse>()
    };

    private static RoutineProductResponse MapToProduct(RoutineProduct p) => new()
    {
        ProductId = p.ProductId,
        Name = p.Name,
        Brand = p.Brand,
        ImageUrl = p.ImageUrl
    };

    private static RoutineCommentResponse MapToComment(RoutineComment c) => new()
    {
        Id = c.Id,
        UserName = c.UserName,
        Text = c.Text,
        CreatedAt = c.CreatedAt
    };
}
