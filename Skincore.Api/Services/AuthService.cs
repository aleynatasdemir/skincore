using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using MongoDB.Driver;
using Skincore.Api.Models;

namespace Skincore.Api.Services;

public class AuthService
{
    private readonly MongoDbService _mongoDbService;
    private readonly EmailService _emailService;
    private readonly JwtSettings _jwtSettings;
    private readonly ILogger<AuthService> _logger;

    public AuthService(
        MongoDbService mongoDbService,
        EmailService emailService,
        IOptions<JwtSettings> jwtSettings,
        ILogger<AuthService> logger)
    {
        _mongoDbService = mongoDbService;
        _emailService = emailService;
        _jwtSettings = jwtSettings.Value;
        _logger = logger;
    }

    // ── Register ──
    public async Task<(bool Success, string Message)> RegisterAsync(RegisterRequest request)
    {
        var email = request.Email.Trim().ToLowerInvariant();

        // Check if user already exists
        var existingUser = await _mongoDbService.UsersCollection
            .Find(u => u.Email == email)
            .FirstOrDefaultAsync();

        if (existingUser != null)
        {
            if (!existingUser.IsEmailVerified)
            {
                // Re-send verification code for unverified accounts
                var newCode = GenerateVerificationCode();
                var update = Builders<User>.Update
                    .Set(u => u.VerificationCode, newCode)
                    .Set(u => u.VerificationCodeExpiry, DateTime.UtcNow.AddMinutes(10))
                    .Set(u => u.VerificationAttempts, 0)
                    .Set(u => u.PasswordHash, BCrypt.Net.BCrypt.HashPassword(request.Password));

                await _mongoDbService.UsersCollection.UpdateOneAsync(u => u.Id == existingUser.Id, update);
                await _emailService.SendVerificationEmailAsync(email, newCode);
                return (true, "Doğrulama kodu e-posta adresinize gönderildi.");
            }
            return (false, "Bu e-posta adresi zaten kayıtlı.");
        }

        // Validate password
        var passwordError = ValidatePassword(request.Password);
        if (passwordError != null)
            return (false, passwordError);

        var code = GenerateVerificationCode();

        var user = new User
        {
            Email = email,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.Password),
            FullName = request.FullName,
            AuthProvider = "email",
            IsEmailVerified = false,
            VerificationCode = code,
            VerificationCodeExpiry = DateTime.UtcNow.AddMinutes(10),
            VerificationAttempts = 0,
            CreatedAt = DateTime.UtcNow
        };

        await _mongoDbService.UsersCollection.InsertOneAsync(user);
        await _emailService.SendVerificationEmailAsync(email, code);

        return (true, "Kayıt başarılı. Doğrulama kodu e-posta adresinize gönderildi.");
    }

    // ── Verify Email ──
    public async Task<(bool Success, string Message, AuthResponse? Response)> VerifyEmailAsync(VerifyEmailRequest request)
    {
        var email = request.Email.Trim().ToLowerInvariant();

        var user = await _mongoDbService.UsersCollection
            .Find(u => u.Email == email)
            .FirstOrDefaultAsync();

        if (user == null)
            return (false, "Kullanıcı bulunamadı.", null);

        if (user.IsEmailVerified)
            return (false, "E-posta zaten doğrulanmış.", null);

        if (user.VerificationAttempts >= 5)
            return (false, "Çok fazla yanlış deneme. Lütfen yeni kod isteyin.", null);

        if (user.VerificationCodeExpiry < DateTime.UtcNow)
            return (false, "Doğrulama kodu süresi dolmuş. Lütfen yeni kod isteyin.", null);

        if (user.VerificationCode != request.Code)
        {
            // Increment attempts
            var attemptUpdate = Builders<User>.Update.Inc(u => u.VerificationAttempts, 1);
            await _mongoDbService.UsersCollection.UpdateOneAsync(u => u.Id == user.Id, attemptUpdate);
            return (false, "Geçersiz doğrulama kodu.", null);
        }

        // Mark as verified and clear code
        var update = Builders<User>.Update
            .Set(u => u.IsEmailVerified, true)
            .Set(u => u.VerificationCode, null)
            .Set(u => u.VerificationCodeExpiry, null)
            .Set(u => u.VerificationAttempts, 0)
            .Set(u => u.LastLoginAt, DateTime.UtcNow);

        // Generate tokens
        var refreshToken = GenerateRefreshToken();
        update = update
            .Set(u => u.RefreshToken, refreshToken)
            .Set(u => u.RefreshTokenExpiry, DateTime.UtcNow.AddDays(_jwtSettings.RefreshTokenExpirationDays));

        await _mongoDbService.UsersCollection.UpdateOneAsync(u => u.Id == user.Id, update);

        var accessToken = GenerateJwtToken(user);

        var response = new AuthResponse
        {
            AccessToken = accessToken,
            RefreshToken = refreshToken,
            User = UserResponse.FromUser(user)
        };
        response.User.IsEmailVerified = true;

        return (true, "E-posta doğrulandı.", response);
    }

    // ── Login ──
    public async Task<(bool Success, string Message, AuthResponse? Response)> LoginAsync(LoginRequest request)
    {
        var email = request.Email.Trim().ToLowerInvariant();

        var user = await _mongoDbService.UsersCollection
            .Find(u => u.Email == email && u.AuthProvider == "email")
            .FirstOrDefaultAsync();

        if (user == null)
            return (false, "E-posta veya şifre hatalı.", null);

        if (!user.IsEmailVerified)
            return (false, "Lütfen önce e-posta adresinizi doğrulayın.", null);

        if (!BCrypt.Net.BCrypt.Verify(request.Password, user.PasswordHash))
            return (false, "E-posta veya şifre hatalı.", null);

        var refreshToken = GenerateRefreshToken();
        var update = Builders<User>.Update
            .Set(u => u.LastLoginAt, DateTime.UtcNow)
            .Set(u => u.RefreshToken, refreshToken)
            .Set(u => u.RefreshTokenExpiry, DateTime.UtcNow.AddDays(_jwtSettings.RefreshTokenExpirationDays));

        await _mongoDbService.UsersCollection.UpdateOneAsync(u => u.Id == user.Id, update);

        var accessToken = GenerateJwtToken(user);

        return (true, "Giriş başarılı.", new AuthResponse
        {
            AccessToken = accessToken,
            RefreshToken = refreshToken,
            User = UserResponse.FromUser(user)
        });
    }

    // ── Apple Sign In ──
    public async Task<(bool Success, string Message, AuthResponse? Response)> AppleSignInAsync(AppleSignInRequest request)
    {
        try
        {
            // Validate Apple identity token
            var appleUserId = await ValidateAppleTokenAsync(request.IdentityToken);
            if (string.IsNullOrEmpty(appleUserId))
                return (false, "Geçersiz Apple kimlik bilgisi.", null);

            // Check if user already exists with this Apple ID
            var user = await _mongoDbService.UsersCollection
                .Find(u => u.AppleUserId == appleUserId)
                .FirstOrDefaultAsync();

            var refreshToken = GenerateRefreshToken();

            if (user == null)
            {
                // Extract email from the token claims if not provided
                var email = request.Email?.Trim().ToLowerInvariant();

                // First sign in — create user
                user = new User
                {
                    Email = email ?? $"{appleUserId}@privaterelay.appleid.com",
                    FullName = request.FullName,
                    AppleUserId = appleUserId,
                    AuthProvider = "apple",
                    IsEmailVerified = true, // Apple already verified
                    CreatedAt = DateTime.UtcNow,
                    LastLoginAt = DateTime.UtcNow,
                    RefreshToken = refreshToken,
                    RefreshTokenExpiry = DateTime.UtcNow.AddDays(_jwtSettings.RefreshTokenExpirationDays)
                };

                await _mongoDbService.UsersCollection.InsertOneAsync(user);
            }
            else
            {
                // Returning user — update login time
                var update = Builders<User>.Update
                    .Set(u => u.LastLoginAt, DateTime.UtcNow)
                    .Set(u => u.RefreshToken, refreshToken)
                    .Set(u => u.RefreshTokenExpiry, DateTime.UtcNow.AddDays(_jwtSettings.RefreshTokenExpirationDays));

                // Update name only if provided (Apple only sends on first sign in)
                if (!string.IsNullOrEmpty(request.FullName))
                    update = update.Set(u => u.FullName, request.FullName);

                await _mongoDbService.UsersCollection.UpdateOneAsync(u => u.Id == user.Id, update);
            }

            var accessToken = GenerateJwtToken(user);

            return (true, "Apple ile giriş başarılı.", new AuthResponse
            {
                AccessToken = accessToken,
                RefreshToken = refreshToken,
                User = UserResponse.FromUser(user)
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Apple Sign In error");
            return (false, "Apple ile giriş sırasında bir hata oluştu.", null);
        }
    }

    // ── Resend Verification Code ──
    public async Task<(bool Success, string Message)> ResendVerificationCodeAsync(string email)
    {
        email = email.Trim().ToLowerInvariant();

        var user = await _mongoDbService.UsersCollection
            .Find(u => u.Email == email && u.AuthProvider == "email")
            .FirstOrDefaultAsync();

        if (user == null)
            return (false, "Kullanıcı bulunamadı.");

        if (user.IsEmailVerified)
            return (false, "E-posta zaten doğrulanmış.");

        // Rate limiting: don't allow resend within 60 seconds
        if (user.VerificationCodeExpiry.HasValue && 
            user.VerificationCodeExpiry.Value > DateTime.UtcNow.AddMinutes(9))
            return (false, "Lütfen yeni kod istemek için 60 saniye bekleyin.");

        var code = GenerateVerificationCode();

        var update = Builders<User>.Update
            .Set(u => u.VerificationCode, code)
            .Set(u => u.VerificationCodeExpiry, DateTime.UtcNow.AddMinutes(10))
            .Set(u => u.VerificationAttempts, 0);

        await _mongoDbService.UsersCollection.UpdateOneAsync(u => u.Id == user.Id, update);
        await _emailService.SendVerificationEmailAsync(email, code);

        return (true, "Yeni doğrulama kodu gönderildi.");
    }

    // ── Refresh Token ──
    public async Task<(bool Success, string Message, AuthResponse? Response)> RefreshTokenAsync(string refreshToken)
    {
        var user = await _mongoDbService.UsersCollection
            .Find(u => u.RefreshToken == refreshToken)
            .FirstOrDefaultAsync();

        if (user == null || user.RefreshTokenExpiry < DateTime.UtcNow)
            return (false, "Geçersiz veya süresi dolmuş refresh token.", null);

        var newRefreshToken = GenerateRefreshToken();
        var update = Builders<User>.Update
            .Set(u => u.RefreshToken, newRefreshToken)
            .Set(u => u.RefreshTokenExpiry, DateTime.UtcNow.AddDays(_jwtSettings.RefreshTokenExpirationDays));

        await _mongoDbService.UsersCollection.UpdateOneAsync(u => u.Id == user.Id, update);

        var accessToken = GenerateJwtToken(user);

        return (true, "Token yenilendi.", new AuthResponse
        {
            AccessToken = accessToken,
            RefreshToken = newRefreshToken,
            User = UserResponse.FromUser(user)
        });
    }

    // ── Forgot Password ──
    public async Task<(bool Success, string Message)> ForgotPasswordAsync(string email)
    {
        email = email.Trim().ToLowerInvariant();

        var user = await _mongoDbService.UsersCollection
            .Find(u => u.Email == email && u.AuthProvider == "email")
            .FirstOrDefaultAsync();

        // Güvenlik: kullanıcı bulunamasa da aynı mesajı dön (email enumeration önlemi)
        if (user == null || !user.IsEmailVerified)
            return (true, "Eğer bu e-posta adresi kayıtlıysa sıfırlama kodu gönderildi.");

        // Rate limiting: son 60 saniyede istek atıldıysa beklet
        if (user.PasswordResetCodeExpiry.HasValue &&
            user.PasswordResetCodeExpiry.Value > DateTime.UtcNow.AddMinutes(9))
            return (false, "Lütfen yeni kod istemek için 60 saniye bekleyin.");

        var code = GenerateVerificationCode();

        var update = Builders<User>.Update
            .Set(u => u.PasswordResetCode, code)
            .Set(u => u.PasswordResetCodeExpiry, DateTime.UtcNow.AddMinutes(10))
            .Set(u => u.PasswordResetAttempts, 0);

        await _mongoDbService.UsersCollection.UpdateOneAsync(u => u.Id == user.Id, update);
        await _emailService.SendPasswordResetEmailAsync(email, code);

        return (true, "Eğer bu e-posta adresi kayıtlıysa sıfırlama kodu gönderildi.");
    }

    // ── Reset Password ──
    public async Task<(bool Success, string Message)> ResetPasswordAsync(ResetPasswordRequest request)
    {
        var email = request.Email.Trim().ToLowerInvariant();

        var user = await _mongoDbService.UsersCollection
            .Find(u => u.Email == email && u.AuthProvider == "email")
            .FirstOrDefaultAsync();

        if (user == null)
            return (false, "Geçersiz istek.");

        if (user.PasswordResetAttempts >= 5)
            return (false, "Çok fazla yanlış deneme. Lütfen yeni kod isteyin.");

        if (user.PasswordResetCode == null || user.PasswordResetCodeExpiry < DateTime.UtcNow)
            return (false, "Sıfırlama kodu süresi dolmuş veya geçersiz. Lütfen yeni kod isteyin.");

        if (user.PasswordResetCode != request.Code)
        {
            var attemptUpdate = Builders<User>.Update.Inc(u => u.PasswordResetAttempts, 1);
            await _mongoDbService.UsersCollection.UpdateOneAsync(u => u.Id == user.Id, attemptUpdate);
            return (false, "Geçersiz sıfırlama kodu.");
        }

        var passwordError = ValidatePassword(request.NewPassword);
        if (passwordError != null)
            return (false, passwordError);

        if (user.PasswordHash != null && BCrypt.Net.BCrypt.Verify(request.NewPassword, user.PasswordHash))
            return (false, "Yeni şifre eski şifrenizle aynı olamaz.");

        var update = Builders<User>.Update
            .Set(u => u.PasswordHash, BCrypt.Net.BCrypt.HashPassword(request.NewPassword))
            .Set(u => u.PasswordResetCode, null)
            .Set(u => u.PasswordResetCodeExpiry, null)
            .Set(u => u.PasswordResetAttempts, 0)
            // Güvenlik: tüm oturumları geçersiz kıl
            .Set(u => u.RefreshToken, null)
            .Set(u => u.RefreshTokenExpiry, null)
            .Set(u => u.UpdatedAt, DateTime.UtcNow);

        await _mongoDbService.UsersCollection.UpdateOneAsync(u => u.Id == user.Id, update);

        return (true, "Şifreniz başarıyla sıfırlandı. Lütfen yeni şifrenizle giriş yapın.");
    }

    // ── Get User By ID ──
    public async Task<User?> GetUserByIdAsync(string userId)
    {
        return await _mongoDbService.UsersCollection
            .Find(u => u.Id == userId)
            .FirstOrDefaultAsync();
    }

    // ── JWT Token Generation ──
    private string GenerateJwtToken(User user)
    {
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_jwtSettings.Secret));
        var credentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var claims = new[]
        {
            new Claim(ClaimTypes.NameIdentifier, user.Id),
            new Claim(ClaimTypes.Email, user.Email),
            new Claim("auth_provider", user.AuthProvider)
        };

        var token = new JwtSecurityToken(
            issuer: _jwtSettings.Issuer,
            audience: _jwtSettings.Audience,
            claims: claims,
            expires: DateTime.UtcNow.AddMinutes(_jwtSettings.AccessTokenExpirationMinutes),
            signingCredentials: credentials
        );

        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    // ── Refresh Token Generation ──
    private static string GenerateRefreshToken()
    {
        var randomBytes = new byte[64];
        using var rng = RandomNumberGenerator.Create();
        rng.GetBytes(randomBytes);
        return Convert.ToBase64String(randomBytes);
    }

    // ── Verification Code Generation ──
    private static string GenerateVerificationCode()
    {
        using var rng = RandomNumberGenerator.Create();
        var bytes = new byte[4];
        rng.GetBytes(bytes);
        var number = BitConverter.ToUInt32(bytes, 0) % 900000 + 100000;
        return number.ToString();
    }

    // ── Apple Token Validation ──
    private async Task<string?> ValidateAppleTokenAsync(string identityToken)
    {
        try
        {
            using var httpClient = new HttpClient();
            var response = await httpClient.GetStringAsync("https://appleid.apple.com/auth/keys");
            var appleKeys = JsonDocument.Parse(response);

            var tokenHandler = new JwtSecurityTokenHandler();
            var jwtToken = tokenHandler.ReadJwtToken(identityToken);

            var kid = jwtToken.Header.Kid;
            var alg = jwtToken.Header.Alg;

            // Find the matching key
            JsonElement? matchingKey = null;
            foreach (var key in appleKeys.RootElement.GetProperty("keys").EnumerateArray())
            {
                if (key.GetProperty("kid").GetString() == kid)
                {
                    matchingKey = key;
                    break;
                }
            }

            if (matchingKey == null)
                return null;

            var n = Base64UrlDecode(matchingKey.Value.GetProperty("n").GetString()!);
            var e = Base64UrlDecode(matchingKey.Value.GetProperty("e").GetString()!);

            var rsaParams = new RSAParameters { Modulus = n, Exponent = e };
            var rsa = RSA.Create();
            rsa.ImportParameters(rsaParams);

            var validationParameters = new TokenValidationParameters
            {
                ValidateIssuer = true,
                ValidIssuer = "https://appleid.apple.com",
                ValidateAudience = false, // We'll validate manually if needed
                ValidateLifetime = true,
                IssuerSigningKey = new RsaSecurityKey(rsa)
            };

            var principal = tokenHandler.ValidateToken(identityToken, validationParameters, out _);
            var sub = principal.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            return sub;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Apple token validation failed");
            return null;
        }
    }

    private static byte[] Base64UrlDecode(string input)
    {
        var output = input.Replace('-', '+').Replace('_', '/');
        switch (output.Length % 4)
        {
            case 2: output += "=="; break;
            case 3: output += "="; break;
        }
        return Convert.FromBase64String(output);
    }

    // ── Password Validation ──
    private static string? ValidatePassword(string? password)
    {
        if (string.IsNullOrWhiteSpace(password))
            return "Şifre gereklidir.";
        if (password.Length < 8)
            return "Şifre en az 8 karakter olmalıdır.";
        if (!password.Any(char.IsUpper))
            return "Şifre en az bir büyük harf içermelidir.";
        if (!password.Any(char.IsLower))
            return "Şifre en az bir küçük harf içermelidir.";
        if (!password.Any(char.IsDigit))
            return "Şifre en az bir rakam içermelidir.";
        if (!password.Any(c => !char.IsLetterOrDigit(c)))
            return "Şifre en az bir özel karakter içermelidir (!@#$%^&*).";
        return null;
    }
}
