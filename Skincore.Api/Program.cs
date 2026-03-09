using Skincore.Api.Models;
using Skincore.Api.Services;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.Configure<MongoDBSettings>(
    builder.Configuration.GetSection("MongoDBSettings"));

builder.Services.AddSingleton<MongoDbService>();
builder.Services.AddSingleton<IngredientMatchingService>();
builder.Services.AddSingleton<ProductSearchService>();

builder.Services.AddControllers();

builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

var app = builder.Build();

// Initialize the caches on startup
using (var scope = app.Services.CreateScope())
{
    var matchingService = scope.ServiceProvider.GetRequiredService<IngredientMatchingService>();
    matchingService.InitializeAsync().GetAwaiter().GetResult();

    var productSearchService = scope.ServiceProvider.GetRequiredService<ProductSearchService>();
    productSearchService.InitializeAsync().GetAwaiter().GetResult();
}

// Configure the HTTP request pipeline.
app.UseHttpsRedirection();
app.UseCors();
app.UseAuthorization();
app.MapControllers();

app.Run();
