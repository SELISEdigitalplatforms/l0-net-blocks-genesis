namespace Blocks.Genesis
{
    public interface IJwtValidationService
    {
        JwtValidationParameters GetValidationParameter(string issuer, string audience);
    }

}
