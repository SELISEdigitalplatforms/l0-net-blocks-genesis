using Microsoft.Extensions.Logging;
using MongoDB.Driver;
using StackExchange.Redis;

namespace Blocks.Genesis
{
    public class Tenants : ITenants
    {
        private readonly ILogger<Tenants> _logger;
        private readonly IBlocksSecret _blocksSecret;
        private readonly ICacheClient _cacheClient;
        private readonly IMongoDatabase _database;


        public Tenants(ILogger<Tenants> logger, IBlocksSecret blocksSecret, ICacheClient cacheClient)
        {
            _logger = logger;
            _blocksSecret = blocksSecret;
            _cacheClient = cacheClient;
        }

        public async Task<Tenant?> GetTenantByID(string tenantId)
        {
            var tenant = GetTenantFromCache(tenantId);
            if(tenant == null)
            {
                tenant = await CacheTenant(tenantId);
            }

            return tenant;
        }

        public Dictionary<string, (string, string)> GetTenantDatabaseConnectionStrings()
        {
            IMongoDatabase _database = new MongoClient(_blocksSecret.DatabaseConnectionString).GetDatabase(_blocksSecret.RootDatabaseName);
            var tenants = _database.GetCollection<Tenant>(BlocksConstants.TenantCollectionName).Find(_ => true).ToList()
                .ToDictionary(t => t.TenantId, t => (t.DBName, t.DbConnectionString));
            return tenants;
        }

        public async Task<(string?, string?)> GetTenantDatabaseConnectionString(string tenantId)
        {
            var tenant = await GetTenantByID(tenantId);

            return (tenant?.DBName, tenant?.DbConnectionString);
        }

        public JwtTokenParameters? GetTenantTokenValidationParameter(string tenantId)
        {
            var tenant = GetTenantFromCache(tenantId);
            return tenant == null ? null : tenant.JwtTokenParameters;
        }

        public async Task CacheTenants()
        {
            try
            {
                IMongoDatabase _database = new MongoClient(_blocksSecret.DatabaseConnectionString).GetDatabase(_blocksSecret.RootDatabaseName);
                var tenants = await _database.GetCollection<Tenant>(BlocksConstants.TenantCollectionName).Find(_ => true).ToListAsync();

                foreach (var tenant in tenants)
                {
                    SaveTenantInCache(tenant);
                    LmtConfiguration.CreateCollectionForTrace(_blocksSecret.TraceConnectionString, tenant.TenantId);
                }

                tenants = null;
            }
            catch (Exception exception)
            {
                _logger.LogError(exception, exception.Message);
            }


        }

        public async Task<Tenant?> CacheTenant(string tenantId)
        {
            try
            {
                var tenant = await _database.GetCollection<Tenant>(BlocksConstants.TenantCollectionName)
                    .Find((Tenant t) => t.ItemId == tenantId || t.TenantId == tenantId)
                    .FirstOrDefaultAsync();

                SaveTenantInCache(tenant);

                LmtConfiguration.CreateCollectionForTrace(_blocksSecret.TraceConnectionString, tenant.TenantId);
                return tenant;
            }
            catch (Exception exception)
            {
                _logger.LogError(exception, exception.Message);
            }
            return null;
        }


        private void SaveTenantInCache(Tenant tenant)
        {
            try
            {
                var hashEntries = new List<HashEntry>
                    {
                        new HashEntry("ItemId", tenant.ItemId),
                        new HashEntry("TenantId", tenant.TenantId),
                        new HashEntry("DBName", tenant.DBName ?? string.Empty),
                        new HashEntry("ApplicationDomain", tenant.ApplicationDomain ?? string.Empty),
                        new HashEntry("CookieDomain", tenant.CookieDomain ?? string.Empty),
                        new HashEntry("IsDisabled", tenant.IsDisabled),
                        new HashEntry("PasswordStrengthCheckerRegex", tenant.PasswordStrengthCheckerRegex ?? string.Empty),
                        new HashEntry("PasswordSalt", tenant.PasswordSalt ?? string.Empty),
                        new HashEntry("DbConnectionString", tenant.DbConnectionString),
                        new HashEntry("AccessTokenValidForNumberMinutes", tenant.AccessTokenValidForNumberMinutes),
                        new HashEntry("RefreshTokenValidForNumberMinutes", tenant.RefreshTokenValidForNumberMinutes),
                        new HashEntry("RememberMeRefreshTokenValidForNumberMinutes", tenant.RememberMeRefreshTokenValidForNumberMinutes),
                        new HashEntry("GetNumberOfWrongAttemptsToLockTheAccount", tenant.GetNumberOfWrongAttemptsToLockTheAccount),
                        new HashEntry("AccountLockDurationInMinutes", tenant.AccountLockDurationInMinutes),
                    };

                foreach (var grantType in tenant.AllowedGrantType)
                {
                    hashEntries.Add(new HashEntry($"AllowedGrantType:{grantType}", grantType ?? string.Empty));
                }

                _cacheClient.AddHashValue(BlocksConstants.TenantInfoCachePrefix + tenant.TenantId, hashEntries.ToArray());

                SaveTokenParametersInCache(tenant.TenantId, tenant.JwtTokenParameters);
            }
            catch (Exception exception)
            {
                _logger.LogError(exception, exception.Message);
            }
        }


        private void SaveTokenParametersInCache(string tenantId, JwtTokenParameters parameters)
        {
            try
            {
                var hashEntries = new List<HashEntry>
                {
                    new HashEntry("Issuer", parameters.Issuer ?? string.Empty),
                    new HashEntry("PublicCertificatePath", parameters.PublicCertificatePath ?? string.Empty),
                    new HashEntry("PublicCertificatePassword", parameters.PublicCertificatePassword ?? string.Empty),
                    new HashEntry("PrivateCertificatePassword", parameters.PrivateCertificatePassword ?? string.Empty),
                    new HashEntry("CertificateValidForNumberOfDays", parameters.CertificateValidForNumberOfDays),
                    new HashEntry("IssueDate", parameters.IssueDate.ToString()),
                    
                };

                foreach (var audience in parameters.Audiences)
                {
                    hashEntries.Add(new HashEntry($"Audience:{audience}", audience ?? string.Empty));
                }

                _cacheClient.AddHashValue(BlocksConstants.TenantTokenParametersCachePrefix + tenantId, hashEntries.ToArray());
            }
            catch (Exception exception)
            {
                _logger.LogError(exception, exception.Message);
            }
        }

        private Tenant? GetTenantFromCache(string tenantId)
        {
            try
            {
                var hashEntries = _cacheClient.GetHashValue(BlocksConstants.TenantInfoCachePrefix + tenantId);

                if (hashEntries.Length == 0)
                {
                    throw new KeyNotFoundException("Tenant information is not found in Redis.");
                }

                var tenant = new Tenant
                {
                    ItemId = hashEntries.FirstOrDefault(e => e.Name == "ItemId").Value,
                    TenantId = hashEntries.FirstOrDefault(e => e.Name == "TenantId").Value,
                    DBName = hashEntries.FirstOrDefault(e => e.Name == "DBName").Value,
                    ApplicationDomain = hashEntries.FirstOrDefault(e => e.Name == "ApplicationDomain").Value,
                    CookieDomain = hashEntries.FirstOrDefault(e => e.Name == "CookieDomain").Value,
                    IsDisabled = hashEntries.FirstOrDefault(e => e.Name == "IsDisabled").Value == "true",
                    DbConnectionString = hashEntries.FirstOrDefault(e => e.Name == "DbConnectionString").Value,
                    PasswordStrengthCheckerRegex = hashEntries.FirstOrDefault(e => e.Name == "PasswordStrengthCheckerRegex").Value,
                    PasswordSalt = hashEntries.FirstOrDefault(e => e.Name == "PasswordSalt").Value,
                    AllowedGrantType = hashEntries.Where(e => e.Name.StartsWith("AllowedGrantType:")).Select(e => (string)e.Value).ToList(),
                    JwtTokenParameters = GetTokenParametersFromCache(tenantId),
                    AccessTokenValidForNumberMinutes = (int)hashEntries.FirstOrDefault(e => e.Name == "AccessTokenValidForNumberMinutes").Value,
                    RefreshTokenValidForNumberMinutes = (int)hashEntries.FirstOrDefault(e => e.Name == "RefreshTokenValidForNumberMinutes").Value,
                    RememberMeRefreshTokenValidForNumberMinutes = (int)hashEntries.FirstOrDefault(e => e.Name == "RememberMeRefreshTokenValidForNumberMinute").Value,
                    GetNumberOfWrongAttemptsToLockTheAccount = (int)hashEntries.FirstOrDefault(e => e.Name == "GetNumberOfWrongAttemptsToLockTheAccount").Value,
                    AccountLockDurationInMinutes = (int)hashEntries.FirstOrDefault(e => e.Name == "AccountLockDurationInMinutes").Value,
                };

                return tenant;
            }
            catch (Exception exception)
            {
                _logger.LogError(exception, exception.Message);
                return null;
            }
        }

        private JwtTokenParameters? GetTokenParametersFromCache(string tenantId)
        {
            try
            {
                var hashEntries = _cacheClient.GetHashValue(BlocksConstants.TenantTokenParametersCachePrefix + tenantId);

                if (hashEntries.Length == 0)
                {
                    throw new KeyNotFoundException("Tenant Token Parameters are not found in Redis.");
                }

                var tokenParameters = new JwtTokenParameters
                {
                    Issuer = hashEntries.FirstOrDefault(e => e.Name == "Issuer").Value,
                    Audiences = hashEntries.Where(e => e.Name.StartsWith("Audience:")).Select(e => (string)e.Value).ToList(),
                    PublicCertificatePath = hashEntries.FirstOrDefault(e => e.Name == "PublicCertificatePath").Value,
                    PublicCertificatePassword = hashEntries.FirstOrDefault(e => e.Name == "PublicCertificatePassword").Value,
                    PrivateCertificatePassword = hashEntries.FirstOrDefault(e => e.Name == "PrivateCertificatePassword").Value,
                    CertificateValidForNumberOfDays = (int)hashEntries.FirstOrDefault(e => e.Name == "CertificateValidForNumberOfDays").Value,
                    IssueDate = DateTime.Parse(hashEntries.FirstOrDefault(e => e.Name == "IssueDate").Value),
                };

                return tokenParameters;
            }
            catch (Exception exception)
            {
                _logger.LogError(exception, exception.Message);
                return null;
            }
        }

    }
}
