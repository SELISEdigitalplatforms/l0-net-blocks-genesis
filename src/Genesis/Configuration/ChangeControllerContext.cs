﻿using Microsoft.AspNetCore.Http;
using MongoDB.Bson;
using MongoDB.Driver;
using OpenTelemetry;
using System.Text.Json;

namespace Blocks.Genesis
{
    public class ChangeControllerContext
    {
        private readonly ITenants _tenants;
        private readonly IDbContextProvider _dbContextProvider;
        private readonly IHttpContextAccessor  _httpContextAccessor;

        public ChangeControllerContext(ITenants tenants, IDbContextProvider dbContextProvider,
                                       IHttpContextAccessor httpContextAccessor)
        {
            _tenants = tenants;
            _dbContextProvider = dbContextProvider;
            _httpContextAccessor = httpContextAccessor;
        }

        public void ChangeContext(IProjectKey projectKey)
        {
            string thirdPartyContextHeader = _httpContextAccessor.HttpContext.Request.Headers[BlocksConstants.ThirdPartyContextHeader];

            if (!string.IsNullOrWhiteSpace(thirdPartyContextHeader))
            {
                var thirdPartyContext = JsonSerializer.Deserialize<BlocksContext>(thirdPartyContextHeader);

                if (thirdPartyContext != null)
                {
                    SetThirdPartyContext(thirdPartyContext);
                }
            }

            var bc =  BlocksContext.GetContext();

            Baggage.SetBaggage("ActualTenantId", bc.TenantId);

            if (string.IsNullOrWhiteSpace(projectKey.ProjectKey) || projectKey.ProjectKey == bc?.TenantId) return;

            var tenant = _tenants.GetTenantByID(projectKey.ProjectKey);
            var sharedProject = _dbContextProvider.GetCollection<BsonDocument>("ProjectPeoples").Find(Builders<BsonDocument>.Filter.Eq("UserId", bc?.UserId) & Builders<BsonDocument>.Filter.Eq("TenantId", projectKey.ProjectKey)).FirstOrDefault();
            var isRoot = _tenants.GetTenantByID(bc?.TenantId)?.IsRootTenant ?? false;

            if (isRoot && (tenant?.CreatedBy == bc.UserId || sharedProject != null))
            {
                BlocksContext.SetContext(BlocksContext.Create
                 (
                    tenantId: projectKey.ProjectKey,
                    roles: bc?.Roles ?? Enumerable.Empty<string>(),
                    userId: bc?.UserId ?? string.Empty,
                    isAuthenticated: bc?.IsAuthenticated ?? false,
                    requestUri: bc?.RequestUri ?? string.Empty,
                    organizationId: bc?.OrganizationId ?? string.Empty,
                    expireOn: bc?.ExpireOn ?? DateTime.UtcNow.AddHours(1),
                    email: bc?.Email ?? string.Empty,
                    permissions: bc?.Permissions ?? Enumerable.Empty<string>(),
                    userName: bc?.UserName ?? string.Empty,
                    phoneNumber: bc?.PhoneNumber ?? string.Empty,
                    displayName: bc?.DisplayName ?? string.Empty,
                    oauthToken: bc?.OAuthToken ?? string.Empty,
                    actualTentId: bc?.TenantId ?? string.Empty
                ));

                Baggage.SetBaggage("TenantId", projectKey.ProjectKey);
            }
        }

        private void SetThirdPartyContext(BlocksContext bc)
        {
             BlocksContext.SetContext(BlocksContext.Create
                 (
                    tenantId: bc.TenantId,
                    roles: bc?.Roles ?? Enumerable.Empty<string>(),
                    userId: bc?.UserId ?? string.Empty,
                    isAuthenticated: bc?.IsAuthenticated ?? false,
                    requestUri: bc?.RequestUri ?? string.Empty,
                    organizationId: bc?.OrganizationId ?? string.Empty,
                    expireOn: bc?.ExpireOn ?? DateTime.UtcNow.AddHours(1),
                    email: bc?.Email ?? string.Empty,
                    permissions: bc?.Permissions ?? Enumerable.Empty<string>(),
                    userName: bc?.UserName ?? string.Empty,
                    phoneNumber: bc?.PhoneNumber ?? string.Empty,
                    displayName: bc?.DisplayName ?? string.Empty,
                    oauthToken: bc?.OAuthToken ?? string.Empty,
                    actualTentId: bc?.TenantId ?? string.Empty
                ));
        }
    }
}
