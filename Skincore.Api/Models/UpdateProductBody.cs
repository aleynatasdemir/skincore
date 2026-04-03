namespace Skincore.Api.Models;

public class UpdateProductBody
{
    public string? Barcode { get; set; }
    public string? Name { get; set; }
    public string? Brand { get; set; }
    public string? ProductIngredients { get; set; }
    public string? ImageUrls { get; set; }
}
