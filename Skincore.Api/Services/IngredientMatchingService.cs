using FuzzySharp;
using Skincore.Api.Models;
using MongoDB.Driver;

namespace Skincore.Api.Services;

public class IngredientMatchingService
{
    private readonly MongoDbService _mongoDbService;
    private List<Ingredient> _cachedIngredients = new();
    
    // A dictionary to quickly lookup exact matches or guide fuzzy searches
    // Key: Lowercase ingredient name/alias, Value: The actual Ingredient object
    private Dictionary<string, Ingredient> _ingredientLookup = new();
    private List<string> _searchableKeys = new();

    public IngredientMatchingService(MongoDbService mongoDbService)
    {
        _mongoDbService = mongoDbService;
    }

    public async Task InitializeAsync()
    {
        // Load all ingredients into memory for fast matching
        _cachedIngredients = await _mongoDbService.IngredientsCollection.Find(_ => true).ToListAsync();
        
        foreach (var ingredient in _cachedIngredients)
        {
            if (!string.IsNullOrEmpty(ingredient.Name))
            {
                var key = ingredient.Name.ToLowerInvariant().Trim();
                _ingredientLookup.TryAdd(key, ingredient);
            }

            if (ingredient.Aliases != null)
            {
                foreach (var alias in ingredient.Aliases)
                {
                    if (!string.IsNullOrEmpty(alias))
                    {
                        var key = alias.ToLowerInvariant().Trim();
                        _ingredientLookup.TryAdd(key, ingredient);
                    }
                }
            }
        }

        _searchableKeys = _ingredientLookup.Keys.ToList();
    }

    public EnrichedIngredient MatchIngredient(string rawIngredientString)
    {
        if (string.IsNullOrWhiteSpace(rawIngredientString))
        {
            return new EnrichedIngredient 
            { 
                OriginalString = rawIngredientString, 
                MatchType = "None" 
            };
        }

        var normalizedInput = rawIngredientString.ToLowerInvariant().Trim();

        // 1. Try Exact Match
        if (_ingredientLookup.TryGetValue(normalizedInput, out var exactMatch))
        {
            return new EnrichedIngredient
            {
                OriginalString = rawIngredientString,
                MatchedIngredient = exactMatch,
                MatchScore = 100,
                MatchType = "Exact"
            };
        }

        // 2. Try Fuzzy Match using FuzzySharp (ExtractOne gets the best match)
        // We ensure we only do this if we have searchable keys
        if (_searchableKeys.Count > 0)
        {
            var fuzzyResult = Process.ExtractOne(normalizedInput, _searchableKeys);
            
            // Define a threshold, e.g., 85%
            if (fuzzyResult.Score >= 85)
            {
                return new EnrichedIngredient
                {
                    OriginalString = rawIngredientString,
                    MatchedIngredient = _ingredientLookup[fuzzyResult.Value],
                    MatchScore = fuzzyResult.Score,
                    MatchType = "Fuzzy"
                };
            }
        }

        // 3. No sufficient match found
        return new EnrichedIngredient
        {
            OriginalString = rawIngredientString,
            MatchType = "None"
        };
    }
}
