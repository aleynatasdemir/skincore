using System.Text;
using System.Text.Json;
using FuzzySharp;
using MongoDB.Driver;
using Skincore.Api.Models;

namespace Skincore.Api.Services;

public class ImageSearchService
{
    private readonly MongoDbService _mongoDbService;
    private readonly IConfiguration _configuration;
    private readonly HttpClient _httpClient = new();

    // In-memory cache: productId → embedding vector
    private Dictionary<string, double[]> _embeddingCache = new();
    // In-memory cache: productId → ocrText (for OCR fuzzy search)
    private List<(string OcrText, string ProductId)> _ocrIndex = new();

    private const string GEMINI_MODEL = "gemini-embedding-2-preview";
    private const double EMBEDDING_WEIGHT = 1.0;
    private const double OCR_WEIGHT = 0.0; // OCR devre dışı — sadece embedding

    public ImageSearchService(MongoDbService mongoDbService, IConfiguration configuration)
    {
        _mongoDbService = mongoDbService;
        _configuration = configuration;
    }

    public void AddToCache(string productId, double[] embedding)
    {
        _embeddingCache[productId] = embedding;
    }

    public async Task InitializeAsync()
    {
        // Load all products with embeddings into memory
        var projection = Builders<Product>.Projection
            .Include(p => p.Id)
            .Include(p => p.Embedding)
            .Include(p => p.OcrText);

        var products = await _mongoDbService.ProductsCollection
            .Find(Builders<Product>.Filter.Exists(p => p.Embedding))
            .Project<Product>(projection)
            .ToListAsync();

        _embeddingCache.Clear();
        _ocrIndex.Clear();

        foreach (var product in products)
        {
            if (product.Id == null || product.Embedding == null || product.Embedding.Count == 0)
                continue;

            _embeddingCache[product.Id] = product.Embedding.ToArray();

            if (!string.IsNullOrWhiteSpace(product.OcrText))
                _ocrIndex.Add((product.OcrText.ToLowerInvariant().Trim(), product.Id));
        }

        // Also load products without embeddings but with OCR text
        var ocrOnly = await _mongoDbService.ProductsCollection
            .Find(Builders<Product>.Filter.And(
                Builders<Product>.Filter.Exists(p => p.OcrText),
                Builders<Product>.Filter.Ne(p => p.OcrText, null),
                Builders<Product>.Filter.Or(
                    Builders<Product>.Filter.Exists(p => p.Embedding, false),
                    Builders<Product>.Filter.Eq(p => p.Embedding, null)
                )
            ))
            .Project<Product>(Builders<Product>.Projection
                .Include(p => p.Id)
                .Include(p => p.OcrText))
            .ToListAsync();

        foreach (var product in ocrOnly)
        {
            if (product.Id != null && !string.IsNullOrWhiteSpace(product.OcrText))
                _ocrIndex.Add((product.OcrText.ToLowerInvariant().Trim(), product.Id));
        }
    }

    /// <summary>
    /// Embed image bytes via Gemini API, then hybrid search: embedding similarity (0.6) + OCR fuzzy (0.4)
    /// </summary>
    public async Task<List<Product>> SearchByImageAsync(byte[] imageBytes, string? ocrText, int maxResults = 5)
    {
        Console.WriteLine($"[ImageSearch] Arama başladı — imageSize={imageBytes.Length}, ocrText=\"{ocrText?.Substring(0, Math.Min(ocrText?.Length ?? 0, 80))}...\", embeddingCache={_embeddingCache.Count}, ocrIndex={_ocrIndex.Count}");

        var scores = new Dictionary<string, double>();

        // 1. Embedding similarity search
        var queryEmbedding = await GetImageEmbeddingAsync(imageBytes);
        Console.WriteLine($"[ImageSearch] Embedding sonucu: {(queryEmbedding != null ? $"dim={queryEmbedding.Length}" : "NULL (API hatası)")}");

        if (queryEmbedding != null && _embeddingCache.Count > 0)
        {
            foreach (var (productId, productEmbedding) in _embeddingCache)
            {
                var similarity = CosineSimilarity(queryEmbedding, productEmbedding);
                scores[productId] = similarity * EMBEDDING_WEIGHT;
            }

            var topEmbedding = scores.OrderByDescending(x => x.Value).Take(5);
            Console.WriteLine("[ImageSearch] Top 5 embedding skorları:");
            foreach (var e in topEmbedding)
                Console.WriteLine($"  [EMB] {e.Key} similarity={e.Value / EMBEDDING_WEIGHT:F4} → weighted={e.Value:F4}");
        }

        // 2. OCR fuzzy search (if OCR text provided)
        // FURKAN NOT: SUNUCUYA YUK BINDIDIGI ICIN OCR (FuzzySearch) KISMI DEVRE DISI BIRAKILDI
        /*
        if (!string.IsNullOrWhiteSpace(ocrText) && _ocrIndex.Count > 0)
        {
            var normalizedQuery = ocrText.ToLowerInvariant().Trim();
            var searchKeys = _ocrIndex.Select(x => x.OcrText).ToList();
            var fuzzyResults = Process.ExtractTop(normalizedQuery, searchKeys, limit: maxResults * 5);

            // Her ürün için sadece en yüksek OCR skorunu al (birden fazla eşleşme birikmesin)
            var bestOcrScores = new Dictionary<string, double>();
            foreach (var result in fuzzyResults)
            {
                if (result.Score < 40) continue;

                var match = _ocrIndex.FirstOrDefault(x => x.OcrText == result.Value);
                if (match.ProductId == null) continue;

                var normalizedScore = result.Score / 100.0;
                bestOcrScores.TryGetValue(match.ProductId, out var existing);
                if (normalizedScore > existing)
                    bestOcrScores[match.ProductId] = normalizedScore;
            }

            foreach (var (productId, ocrScore) in bestOcrScores)
            {
                scores.TryGetValue(productId, out var existing);
                scores[productId] = existing + ocrScore * OCR_WEIGHT;
                Console.WriteLine($"  [OCR] {productId} ocrScore={ocrScore:F2} → weighted={ocrScore * OCR_WEIGHT:F4}");
            }
        }
        */

        // 3. Get top results
        var topScores = scores
            .OrderByDescending(x => x.Value)
            .Take(maxResults * 2)
            .ToList();

        Console.WriteLine($"[ImageSearch] Top skorlar:");
        foreach (var s in topScores.Take(10))
            Console.WriteLine($"  productId={s.Key} score={s.Value:F4}");

        var topIds = topScores
            .Where(x => x.Value > 0.1) // minimum threshold
            .Take(maxResults)
            .Select(x => x.Key)
            .ToList();

        Console.WriteLine($"[ImageSearch] Sonuç: {topIds.Count} ürün eşleşti (threshold > 0.1)");

        if (topIds.Count == 0)
            return new List<Product>();

        var filter = Builders<Product>.Filter.In(p => p.Id, topIds);
        var matchedProducts = await _mongoDbService.ProductsCollection.Find(filter).ToListAsync();

        var ordered = matchedProducts.OrderBy(p => topIds.IndexOf(p.Id!)).ToList();
        foreach (var p in ordered)
            Console.WriteLine($"  → {p.Name} (id={p.Id})");

        return ordered;
    }

    /// <summary>
    /// Call Gemini Embedding API to get image embedding vector
    /// </summary>
    private async Task<double[]?> GetImageEmbeddingAsync(byte[] imageBytes)
    {
        var apiKey = _configuration["GoogleApiKey"];
        if (string.IsNullOrEmpty(apiKey)) return null;

        var url = $"https://generativelanguage.googleapis.com/v1beta/models/{GEMINI_MODEL}:embedContent?key={apiKey}";

        var base64Image = Convert.ToBase64String(imageBytes);
        var payload = new
        {
            model = $"models/{GEMINI_MODEL}",
            content = new
            {
                parts = new[]
                {
                    new
                    {
                        inlineData = new
                        {
                            mimeType = "image/jpeg",
                            data = base64Image
                        }
                    }
                }
            }
        };

        try
        {
            var json = JsonSerializer.Serialize(payload);
            var content = new StringContent(json, Encoding.UTF8, "application/json");
            var response = await _httpClient.PostAsync(url, content);

            if (!response.IsSuccessStatusCode) return null;

            var responseJson = await response.Content.ReadAsStringAsync();
            using var doc = JsonDocument.Parse(responseJson);

            var values = doc.RootElement
                .GetProperty("embedding")
                .GetProperty("values")
                .EnumerateArray()
                .Select(v => v.GetDouble())
                .ToArray();

            return values;
        }
        catch
        {
            return null;
        }
    }

    private static double CosineSimilarity(double[] a, double[] b)
    {
        if (a.Length != b.Length) return 0;

        double dotProduct = 0, normA = 0, normB = 0;
        for (int i = 0; i < a.Length; i++)
        {
            dotProduct += a[i] * b[i];
            normA += a[i] * a[i];
            normB += b[i] * b[i];
        }

        var denominator = Math.Sqrt(normA) * Math.Sqrt(normB);
        return denominator == 0 ? 0 : dotProduct / denominator;
    }
}
