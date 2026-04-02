using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using MongoDB.Driver;
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
builder.Services.AddSingleton<AdminAuthService>();
builder.Services.AddSingleton<UserProfileService>();
builder.Services.AddSingleton<PopularSearchService>();
builder.Services.AddSingleton<SocialRoutinesService>();
builder.Services.AddSingleton<ImageSearchService>();
builder.Services.AddSingleton<NotificationService>();
builder.Services.AddSingleton<AdminService>();
builder.Services.AddHttpClient<GoogleVisionOcrService>();

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

    var imageSearchService = scope.ServiceProvider.GetRequiredService<ImageSearchService>();
    imageSearchService.InitializeAsync().GetAwaiter().GetResult();

    var mongoDbService = scope.ServiceProvider.GetRequiredService<MongoDbService>();
    mongoDbService.CreateIndexesAsync().GetAwaiter().GetResult();

    // ── Migrate legacy admins from users -> admin_users ──
    var legacyAdmins = mongoDbService.UsersCollection
        .Find(u => u.IsAdmin)
        .ToList();

    if (legacyAdmins.Count > 0)
    {
        foreach (var legacy in legacyAdmins)
        {
            var email = legacy.Email.Trim().ToLowerInvariant();
            var baseUsername = string.IsNullOrWhiteSpace(legacy.Username)
                ? email.Split('@')[0]
                : legacy.Username.Trim().ToLowerInvariant();

            var username = baseUsername;
            var suffix = 1;
            while (mongoDbService.AdminUsersCollection.Find(a => a.Username == username).FirstOrDefault() != null)
            {
                username = $"{baseUsername}{suffix}";
                suffix++;
            }

            var alreadyExists = mongoDbService.AdminUsersCollection
                .Find(a => a.Email == email)
                .FirstOrDefault();

            if (alreadyExists != null || string.IsNullOrWhiteSpace(legacy.PasswordHash))
                continue;

            var migratedAdmin = new AdminUser
            {
                Email = email,
                Username = username,
                PasswordHash = legacy.PasswordHash,
                FullName = legacy.FullName,
                IsActive = true,
                FcmToken = legacy.FcmToken,
                NotificationsEnabled = legacy.NotificationsEnabled,
                PreferredLanguage = legacy.PreferredLanguage,
                CreatedAt = legacy.CreatedAt,
                LastLoginAt = legacy.LastLoginAt,
                UpdatedAt = DateTime.UtcNow
            };

            mongoDbService.AdminUsersCollection.InsertOne(migratedAdmin);
        }

        var legacyIds = legacyAdmins.Select(a => a.Id).ToList();
        if (legacyIds.Count > 0)
        {
            var deleteFilter = Builders<User>.Filter.In(u => u.Id, legacyIds);
            mongoDbService.UsersCollection.DeleteMany(deleteFilter);
        }

        Console.WriteLine($"\n[Admin Migration] {legacyAdmins.Count} legacy admin users moved to admin_users.\n");
    }

    // ── Generate Default Admin ──
    var defaultAdmin = mongoDbService.AdminUsersCollection
        .Find(a => a.Email == "admin@skincore.com")
        .FirstOrDefault();

    if (defaultAdmin == null)
    {
        var adminUser = new AdminUser
        {
            Email = "admin@skincore.com",
            Username = "admin",
            PasswordHash = BCrypt.Net.BCrypt.HashPassword("admin123"),
            FullName = "Admin User",
            IsActive = true,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        mongoDbService.AdminUsersCollection.InsertOne(adminUser);
        Console.WriteLine("\n==================================");
        Console.WriteLine(" ADMIN HESABI OLUŞTURULDU (admin_users)");
        Console.WriteLine(" Kullanıcı Adı: admin");
        Console.WriteLine(" E-posta: admin@skincore.com");
        Console.WriteLine(" Şifre: admin123");
        Console.WriteLine("==================================\n");
    }

    // ── Additional Seeded Admin ──
    var extraAdmin = mongoDbService.AdminUsersCollection
        .Find(a => a.Email == "admin2@skincore.com")
        .FirstOrDefault();

    if (extraAdmin == null)
    {
        var adminUser2 = new AdminUser
        {
            Email = "admin2@skincore.com",
            Username = "admin2",
            PasswordHash = BCrypt.Net.BCrypt.HashPassword("Admin123!"),
            FullName = "Admin User 2",
            IsActive = true,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        mongoDbService.AdminUsersCollection.InsertOne(adminUser2);
        Console.WriteLine("\n==================================");
        Console.WriteLine(" EK ADMIN HESABI OLUŞTURULDU (admin_users)");
        Console.WriteLine(" Kullanıcı Adı: admin2");
        Console.WriteLine(" E-posta: admin2@skincore.com");
        Console.WriteLine(" Şifre: Admin123!");
        Console.WriteLine("==================================\n");
    }
}

// ── HTTP Pipeline ──
app.UseSwagger();
app.UseSwaggerUI(c => c.SwaggerEndpoint("/swagger/v1/swagger.json", "SkinCore API v1"));
app.UseStaticFiles();
app.UseHttpsRedirection();
app.UseCors();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();

app.Run();
