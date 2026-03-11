using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using Skincore.Api.Models;
using Skincore.Api.Services;

var builder = WebApplication.CreateBuilder(args);

// ── Configuration ──
builder.Services.Configure<MongoDBSettings>(
    builder.Configuration.GetSection("MongoDBSettings"));
builder.Services.Configure<JwtSettings>(
    builder.Configuration.GetSection("JwtSettings"));
builder.Services.Configure<ResendSettings>(
    builder.Configuration.GetSection("ResendSettings"));

// ── Services ──
builder.Services.AddSingleton<MongoDbService>();
builder.Services.AddSingleton<IngredientMatchingService>();
builder.Services.AddSingleton<ProductSearchService>();
builder.Services.AddSingleton<EmailService>();
builder.Services.AddSingleton<AuthService>();

builder.Services.AddControllers();

// ── Swagger ──
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo { Title = "SkinCore API", Version = "v1" });
    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Description = "JWT token girin. Örnek: \"Bearer {token}\"",
        Name = "Authorization",
        In = ParameterLocation.Header,
        Type = SecuritySchemeType.ApiKey,
        Scheme = "Bearer"
    });
    c.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme
            {
                Reference = new OpenApiReference { Type = ReferenceType.SecurityScheme, Id = "Bearer" }
            },
            Array.Empty<string>()
        }
    });
});

// ── JWT Authentication ──
var jwtSettings = builder.Configuration.GetSection("JwtSettings").Get<JwtSettings>()!;
builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer(options =>
{
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuer = true,
        ValidIssuer = jwtSettings.Issuer,
        ValidateAudience = true,
        ValidAudience = jwtSettings.Audience,
        ValidateLifetime = true,
        ValidateIssuerSigningKey = true,
        IssuerSigningKey = new SymmetricSecurityKey(
            Encoding.UTF8.GetBytes(jwtSettings.Secret)),
        ClockSkew = TimeSpan.Zero
    };
});

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

// ── Initialize on startup ──
using (var scope = app.Services.CreateScope())
{
    var matchingService = scope.ServiceProvider.GetRequiredService<IngredientMatchingService>();
    matchingService.InitializeAsync().GetAwaiter().GetResult();

    var productSearchService = scope.ServiceProvider.GetRequiredService<ProductSearchService>();
    productSearchService.InitializeAsync().GetAwaiter().GetResult();

    // Create MongoDB indexes for users collection
    var mongoDbService = scope.ServiceProvider.GetRequiredService<MongoDbService>();
    mongoDbService.CreateIndexesAsync().GetAwaiter().GetResult();
}

// ── HTTP Pipeline ──
app.UseSwagger();
app.UseSwaggerUI(c => c.SwaggerEndpoint("/swagger/v1/swagger.json", "SkinCore API v1"));
app.UseHttpsRedirection();
app.UseCors();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();

app.Run();

