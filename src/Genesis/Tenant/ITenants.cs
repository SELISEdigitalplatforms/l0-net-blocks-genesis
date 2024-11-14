namespace Blocks.Genesis
{
    public interface ITenants
    {
        Task<Tenant?> GetTenantByID(string tenantId);
        Dictionary<string, (string, string)> GetTenantDatabaseConnectionStrings();
        Task<(string?, string?)> GetTenantDatabaseConnectionString(string tenantId);
        JwtTokenParameters? GetTenantTokenValidationParameter(string tenantId);
        Task CacheTenants();
        Task<Tenant?> CacheTenant(string tenantId);
    }
}
