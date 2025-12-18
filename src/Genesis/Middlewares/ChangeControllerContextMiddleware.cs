using Microsoft.AspNetCore.Http;
using MongoDB.Bson;
using MongoDB.Driver;
using OpenTelemetry;
using System.Text.Json;

namespace Blocks.Genesis.Middlewares
{
    public class ChangeControllerContextMiddleware
    {
        private readonly RequestDelegate _next;

        public ChangeControllerContextMiddleware(RequestDelegate next)
        {
            _next = next;
        }

        public async Task InvokeAsync(
            HttpContext context,
            ITenants tenants,
            IDbContextProvider dbContextProvider)
        {
            string thirdPartyContextHeader =
                context.Request.Headers[BlocksConstants.ThirdPartyContextHeader];

            if (!string.IsNullOrWhiteSpace(thirdPartyContextHeader))
            {
                var thirdPartyContext =
                    JsonSerializer.Deserialize<BlocksContext>(thirdPartyContextHeader);

                if (thirdPartyContext != null)
                {
                    SetThirdPartyContext(thirdPartyContext);
                }
            }

            var bc = BlocksContext.GetContext();

            if (bc != null)
            {
                Baggage.SetBaggage("ActualTenantId", bc.TenantId);
            }

            var projectKeyValue = context.Request.Headers["Project-Key"].FirstOrDefault();
            if (string.IsNullOrWhiteSpace(projectKeyValue) || bc == null || projectKeyValue == bc.TenantId)
            {
                await _next(context);
                return;
            }

            var tenant = tenants.GetTenantByID(projectKeyValue);
            var sharedProject = dbContextProvider
                .GetCollection<BsonDocument>("ProjectPeoples")
                .Find(
                    Builders<BsonDocument>.Filter.Eq("UserId", bc.UserId) &
                    Builders<BsonDocument>.Filter.Eq("TenantId", projectKeyValue))
                .FirstOrDefault();

            var isRoot = tenants.GetTenantByID(bc.TenantId)?.IsRootTenant ?? false;

            if (isRoot && (tenant?.CreatedBy == bc.UserId || sharedProject != null))
            {
                BlocksContext.SetContext(
                    BlocksContext.Create(
                        tenantId: projectKeyValue,
                        roles: bc.Roles ?? Enumerable.Empty<string>(),
                        userId: bc.UserId ?? string.Empty,
                        isAuthenticated: bc.IsAuthenticated,
                        requestUri: bc.RequestUri ?? string.Empty,
                        organizationId: bc.OrganizationId ?? string.Empty,
                        expireOn: bc.ExpireOn,
                        email: bc.Email ?? string.Empty,
                        permissions: bc.Permissions ?? Enumerable.Empty<string>(),
                        userName: bc.UserName ?? string.Empty,
                        phoneNumber: bc.PhoneNumber ?? string.Empty,
                        displayName: bc.DisplayName ?? string.Empty,
                        oauthToken: bc.OAuthToken ?? string.Empty,
                        actualTentId: bc.TenantId
                    ));

                Baggage.SetBaggage("TenantId", projectKeyValue);
            }

            await _next(context);
        }

        private static void SetThirdPartyContext(BlocksContext bc)
        {
            BlocksContext.SetContext(
                BlocksContext.Create(
                    tenantId: bc.TenantId,
                    roles: bc.Roles ?? Enumerable.Empty<string>(),
                    userId: bc.UserId ?? string.Empty,
                    isAuthenticated: bc.IsAuthenticated,
                    requestUri: bc.RequestUri ?? string.Empty,
                    organizationId: bc.OrganizationId ?? string.Empty,
                    expireOn: bc.ExpireOn,
                    email: bc.Email ?? string.Empty,
                    permissions: bc.Permissions ?? Enumerable.Empty<string>(),
                    userName: bc.UserName ?? string.Empty,
                    phoneNumber: bc.PhoneNumber ?? string.Empty,
                    displayName: bc.DisplayName ?? string.Empty,
                    oauthToken: bc.OAuthToken ?? string.Empty,
                    actualTentId: bc.ActualTenantId ?? string.Empty
                ));
        }
    }
}
