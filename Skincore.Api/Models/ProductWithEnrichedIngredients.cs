namespace Skincore.Api.Models;

public class EnrichedIngredient
{
    public string OriginalString { get; set; } = null!;
    public Ingredient? MatchedIngredient { get; set; }
    public double MatchScore { get; set; }
    public string? MatchType { get; set; } // "Exact", "Fuzzy", "None"
}

public class ProductWithEnrichedIngredients : Product
{
    public List<EnrichedIngredient> EnrichedIngredients { get; set; } = new();

    public ProductWithEnrichedIngredients() { }

    public ProductWithEnrichedIngredients(Product product)
    {
        Id = product.Id;
        Name = product.Name;
        Barcode = product.Barcode;
        Brand = product.Brand;
        OcrText = product.OcrText;
        ProductIngredients = product.ProductIngredients;
        ImageUrls = product.ImageUrls;
    }
}
