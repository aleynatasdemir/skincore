using System.Text.RegularExpressions;
using FuzzySharp;
using Skincore.Api.Models;
using MongoDB.Driver;

namespace Skincore.Api.Services;

public partial class IngredientMatchingService
{
    private readonly MongoDbService _mongoDbService;
    private List<Ingredient> _cachedIngredients = new();

    private Dictionary<string, Ingredient> _ingredientLookup = new();
    private List<string> _searchableKeys = new();

    [GeneratedRegex(@"^#\d+\s*(ingrediente:\s*)?", RegexOptions.IgnoreCase)]
    private static partial Regex HashPrefixRegex();

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
            // inci_name (en güvenilir alan — çoğu kayıtta dolu)
            if (!string.IsNullOrEmpty(ingredient.InciName))
            {
                var key = ingredient.InciName.ToLowerInvariant().Trim();
                _ingredientLookup.TryAdd(key, ingredient);
            }

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

    /// <summary>
    /// Gelen ingredient string'ini temizler: #ID prefix, INGREDIENTS: prefix, 
    /// trailing noktalama, sayı prefix vb. kaldırır.
    /// </summary>
    private static string NormalizeIngredientName(string raw)
    {
        var s = raw.Trim();

        // #14593 Ingrediente: AQUA → AQUA
        s = HashPrefixRegex().Replace(s, "");

        // INGREDIENTS: Aqua, ... → Aqua, ... (tek ingredient geldiğinde prefix kalmış olabilir)
        if (s.StartsWith("INGREDIENTS:", StringComparison.OrdinalIgnoreCase))
            s = s["INGREDIENTS:".Length..].TrimStart();
        if (s.StartsWith("INGREDIENTS", StringComparison.OrdinalIgnoreCase) && s.Length > 11 && !char.IsLetter(s[11]))
            s = s[11..].TrimStart(':', ' ');

        // Trailing noktalama: "Glycerin." → "Glycerin"
        s = s.TrimEnd('.', ',', ';', ' ');

        // Stray quotes: "Aqua veya Parfum" → Aqua / Parfum
        s = s.Trim('"');

        // Baştaki sayı ID'leri: "18311 AQUA" → "AQUA"  
        s = NumericPrefixRegex().Replace(s, "");

        return s.Trim();
    }

    [GeneratedRegex(@"^\d{3,}\s+")]
    private static partial Regex NumericPrefixRegex();

    /// <summary>
    /// Verilen key ile exact match dener. Eşleşirse EnrichedIngredient döner, yoksa null.
    /// </summary>
    private EnrichedIngredient? TryExactMatch(string key, string originalString)
    {
        if (string.IsNullOrWhiteSpace(key)) return null;
        var normalized = key.ToLowerInvariant().Trim();
        if (_ingredientLookup.TryGetValue(normalized, out var match))
        {
            return new EnrichedIngredient
            {
                OriginalString = originalString,
                MatchedIngredient = match,
                MatchScore = 100,
                MatchType = "Exact"
            };
        }
        return null;
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

        // Normalize: prefix/suffix temizliği
        var cleaned = NormalizeIngredientName(rawIngredientString);
        var normalizedInput = cleaned.ToLowerInvariant().Trim();

        if (string.IsNullOrWhiteSpace(normalizedInput))
        {
            return new EnrichedIngredient 
            { 
                OriginalString = rawIngredientString, 
                MatchType = "None" 
            };
        }

        // 1. Try Exact Match
        var result = TryExactMatch(normalizedInput, rawIngredientString);
        if (result != null) return result;

        // 2. Parantez alternatifleri: "Aqua (Water)" → "Aqua" ve "Water"
        var parenIdx = normalizedInput.IndexOf('(');
        if (parenIdx > 0)
        {
            result = TryExactMatch(normalizedInput[..parenIdx].Trim(), rawIngredientString);
            if (result != null) return result;

            var closeIdx = normalizedInput.IndexOf(')', parenIdx);
            if (closeIdx > parenIdx + 1)
            {
                result = TryExactMatch(normalizedInput[(parenIdx + 1)..closeIdx].Trim(), rawIngredientString);
                if (result != null) return result;
            }
        }

        // 3. Kolon-split: "Krem Boya: Aqua" → "Aqua", "HAIR COLOR CREAM: AQUA" → "AQUA"
        var colonIdx = normalizedInput.LastIndexOf(':');
        if (colonIdx > 0 && colonIdx < normalizedInput.Length - 1)
        {
            var afterColon = normalizedInput[(colonIdx + 1)..].Trim();
            result = TryExactMatch(afterColon, rawIngredientString);
            if (result != null) return result;
        }

        // 4. Slash-split: "Aqua/Water/Eau" → "Aqua", "Water", "Eau" — her birini dene
        if (normalizedInput.Contains('/'))
        {
            var parts = normalizedInput.Split('/');
            foreach (var part in parts)
            {
                result = TryExactMatch(part.Trim(), rawIngredientString);
                if (result != null) return result;
            }
        }

        // 5. Trailing yıldız/footnote: "Glycerin*" → "Glycerin", "Linalool**" → "Linalool"
        if (normalizedInput.EndsWith('*'))
        {
            result = TryExactMatch(normalizedInput.TrimEnd('*'), rawIngredientString);
            if (result != null) return result;
        }

        // 6. Try Fuzzy Match using FuzzySharp (ExtractOne gets the best match)
        if (_searchableKeys.Count > 0)
        {
            var fuzzyResult = Process.ExtractOne(normalizedInput, _searchableKeys);
            
            // 70+ threshold — yazım farklılıklarını yakala
            if (fuzzyResult.Score >= 70)
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

        // 7. No sufficient match found
        return new EnrichedIngredient
        {
            OriginalString = rawIngredientString,
            MatchType = "None"
        };
    }
}
