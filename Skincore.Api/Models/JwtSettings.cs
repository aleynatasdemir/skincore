namespace Skincore.Api.Models;

public class JwtSettings
{
    public string Secret { get; set; } = null!;
    public string Issuer { get; set; } = null!;
    public string Audience { get; set; } = null!;
    public int AccessTokenExpirationMinutes { get; set; } = 60;
    public int RefreshTokenExpirationDays { get; set; } = 30;
}

public class ResendSettings
{
    public string ApiKey { get; set; } = null!;
    public string FromEmail { get; set; } = null!;
    public string FromName { get; set; } = "SkinCore";
}
