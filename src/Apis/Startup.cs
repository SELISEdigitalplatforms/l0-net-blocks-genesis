using Apis;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Http.Extensions;
using Microsoft.IdentityModel.Tokens;
using Serilog;
using System.Security.Claims;
using System.Text;

public class Startup
{
    public void ConfigureServices(IServiceCollection services)
    {
        services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
        .AddJwtBearer(options =>
        {
            var secretKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes("Definitely-Evolving-Roadway-1993-6122-5638-4817-7520-4846-0705-4"));

            options.TokenValidationParameters = new TokenValidationParameters
            {
                ValidateIssuer = true,
                ValidateAudience = true,
                ValidateIssuerSigningKey = true,
                ValidIssuer = "YOUR_ISSUER",
                ValidAudience = "YOUR_AUDIENCE",
                IssuerSigningKey = secretKey,
                ClockSkew = TimeSpan.Zero
            };

            options.Events = new JwtBearerEvents
            {
                OnAuthenticationFailed = authenticationFailedContext => //delegate to handle case when authentication fails.
                {
                    Console.WriteLine("faild");
                    return Task.CompletedTask;
                },
                OnTokenValidated = tokenValidatedContext => //called after the security token has passed validation
                {
                    var claimsIdentity = tokenValidatedContext.Principal.Identity as ClaimsIdentity;

                    var requestUri = tokenValidatedContext.Request.GetDisplayUrl();

                    var jwtBearerToken = tokenValidatedContext.SecurityToken.ToString();

                    var claimsIssuer = claimsIdentity.Claims.First().Issuer;

                    var requestClaims = new Claim[]
                    {
                new Claim("RequestUri", requestUri),
                new Claim("OauthBearerToken", jwtBearerToken)
                    };

                    claimsIdentity.AddClaims(requestClaims);
                    return Task.CompletedTask;
                },
                OnMessageReceived = messageReceivedContext => //when a protocol message is first received
                {
                    messageReceivedContext.Token = messageReceivedContext.Request.Headers["Authorization"];

                    return Task.CompletedTask;
                },
                OnForbidden = forbiddenContext => //invoked when authorization middleware return Forbidden response
                {
                    Console.WriteLine("faild");
                    return Task.CompletedTask;
                }
            };

        });

        services.AddAuthorization();

        services.AddControllers();
        //http://localhost:51846/HelloWorld/Index
        // Authorization: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiNTRjNDZlODEtNjUxNy00YmViLWEyNzQtYjFiYzY2MjA0YmI4IiwiZGlzcGxheV9uYW1lIjoiQ29tcG9zZSBBZG1pbiIsImVtYWlsIjoiY29tcG9zZUB5b3BtYWlsLmNvbSIsInBob25lX251bWJlciI6Iis4ODAgICAxNjc0NDExMzAyIiwibGFuZ3VhZ2UiOiJlbi1VUyIsInVzZXJfbG9nZ2VkaW4iOiJUcnVlIiwibmJmIjoxNzE3ODEzMzgxLCJleHAiOjE3MTk5NjkzODEsImlzcyI6IllPVVJfSVNTVUVSIiwiYXVkIjoiWU9VUl9BVURJRU5DRSJ9.R1ods7WzSskcxJE0AFOKTRoJuewAkOVZcmbnQC9fQrg

        services.AddHttpClient();
        services.AddSerilog();

    }

    public void Configure(IApplicationBuilder app, IWebHostEnvironment env)
    {
        app.UseMiddleware<TenantEnrichmentMiddleware>();

        if (env.IsDevelopment())
        {
            app.UseDeveloperExceptionPage();
        }

        

        app.UseRouting();
        app.UseAuthentication();
        app.UseAuthorization();
        app.UseEndpoints(endpoints =>
        {
            endpoints.MapControllers();
        });
    }
}

