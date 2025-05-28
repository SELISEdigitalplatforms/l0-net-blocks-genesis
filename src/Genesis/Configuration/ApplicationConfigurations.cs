﻿using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using MongoDB.Bson.Serialization;
using MongoDB.Bson.Serialization.Serializers;
using OpenTelemetry.Metrics;
using OpenTelemetry.Trace;
using Serilog;
using System.Diagnostics;

namespace Blocks.Genesis
{
    public static class ApplicationConfigurations
    {
        private static string _serviceName = string.Empty;
        private static IBlocksSecret _blocksSecret;
        private static BlocksSwaggerOptions _blocksSwaggerOptions;

        public static async Task<IBlocksSecret> ConfigureLogAndSecretsAsync(string serviceName, VaultType vaultType)
        {
            _serviceName = serviceName;

            _blocksSecret = await BlocksSecret.ProcessBlocksSecret(vaultType);
            _blocksSecret.ServiceName = _serviceName;

            LmtConfiguration.CreateCollectionForTrace(_blocksSecret.TraceConnectionString, BlocksConstants.Miscellaneous);
            LmtConfiguration.CreateCollectionForLogs(_blocksSecret.LogConnectionString, _serviceName);
            LmtConfiguration.CreateCollectionForMetrics(_blocksSecret.MetricConnectionString, _serviceName);

            Log.Logger = new LoggerConfiguration()
                .Enrich.FromLogContext()
                .Enrich.With<TraceContextEnricher>()
                .Enrich.WithEnvironmentName()
                .WriteTo.Console()
                .WriteTo.MongoDBWithDynamicCollection(_serviceName, _blocksSecret)
                .CreateLogger();

            return _blocksSecret;
        }

        public static void ConfigureKestrel(WebApplicationBuilder builder)
        {
            var httpPort = Environment.GetEnvironmentVariable("HTTP1_PORT") ?? "5000";
            var http2Port = Environment.GetEnvironmentVariable("HTTP2_PORT") ?? "5001";

            builder.WebHost.ConfigureKestrel(options =>
            {
                options.ListenAnyIP(int.Parse(httpPort), listenOptions =>
                {
                    listenOptions.Protocols = Microsoft.AspNetCore.Server.Kestrel.Core.HttpProtocols.Http1;
                });

                options.ListenAnyIP(int.Parse(http2Port), listenOptions =>
                {
                    listenOptions.Protocols = Microsoft.AspNetCore.Server.Kestrel.Core.HttpProtocols.Http2;
                });
            });
        }

        public static void ConfigureApiEnv(IHostApplicationBuilder builder, string[] args)
        {
            builder.Configuration
                .AddCommandLine(args)
                .AddEnvironmentVariables()
                .AddJsonFile(GetAppSettingsFileName(), optional: false, reloadOnChange: false);

            _blocksSwaggerOptions = builder.Configuration.GetSection("SwaggerOptions").Get<BlocksSwaggerOptions>();
        }

        public static void ConfigureWorkerEnv(IConfigurationBuilder builder, string[] args)
        {
            builder
                .AddCommandLine(args)
                .AddEnvironmentVariables()
                .AddJsonFile(GetAppSettingsFileName(), optional: false, reloadOnChange: false);
        }

        public static void ConfigureServices(IServiceCollection services, MessageConfiguration messageConfiguration)
        {
            services.AddSingleton(typeof(IBlocksSecret), _blocksSecret);
            services.AddSingleton<ICacheClient, RedisClient>();
            services.AddSingleton<ITenants, Tenants>();
            services.AddSingleton<IDbContextProvider, MongoDbContextProvider>();

            var objectSerializer = new ObjectSerializer(_ => true);
            BsonSerializer.RegisterSerializer(objectSerializer);

            services.AddLogging(builder =>
            {
                builder.ClearProviders();
                builder.AddSerilog();
            });

            services.AddSingleton(new ActivitySource(_serviceName));

            services.AddOpenTelemetry()
                .WithTracing(tracingBuilder =>
                {
                    tracingBuilder
                        .SetSampler(new AlwaysOnSampler())
                        .AddAspNetCoreInstrumentation()
                        .AddProcessor(new MongoDBTraceExporter(_serviceName, blocksSecret: _blocksSecret));
                });


            // For now we comment it, after July we will enable this
            //services.AddOpenTelemetry().WithMetrics(metricsBuilder =>
            //{
            //    metricsBuilder
            //        .AddAspNetCoreInstrumentation()
            //        .AddRuntimeInstrumentation()
            //        .AddReader(new PeriodicExportingMetricReader(new MongoDBMetricsExporter(_serviceName, _blocksSecret)));
            //});

            services.AddSingleton<IHttpService, HttpService>();

            ConfigureMessageClient(services, messageConfiguration).GetAwaiter().GetResult();

            services.AddHttpContextAccessor();
            services.AddHealthChecks();

            if (_blocksSwaggerOptions != null)
                services.AddBlocksSwagger(_blocksSwaggerOptions);

            services.AddSingleton<ICryptoService, CryptoService>();
            services.AddSingleton<IGrpcClientFactory, GrpcClientFactory>();
        }

        public static void ConfigureApi(IServiceCollection services)
        {
            services.JwtBearerAuthentication();
            services.AddControllers();
            services.AddHttpClient();

            services.AddGrpc(options =>
            {
                options.Interceptors.Add<GrpcServerInterceptor>();
            });

            services.AddSingleton<ChangeControllerContext>();
        }

        public static void ConfigureMiddleware(WebApplication app)
        {
            var enableHsts = _blocksSecret.EnableHsts || app.Configuration.GetValue<bool>("EnableHsts");
            if (enableHsts)
            {
                app.UseHsts();
            }

            app.UseHealthChecks("/ping", new HealthCheckOptions
            {
                Predicate = _ => true,
                ResponseWriter = async (context, _) =>
                {
                    context.Response.ContentType = "application/json";
                    await context.Response.WriteAsJsonAsync(new { message = $"pong from {_serviceName}" });
                }
            });

            app.UseCors(corsPolicyBuilder =>
                corsPolicyBuilder
                    .AllowAnyHeader()
                    .AllowAnyMethod()
                    .SetIsOriginAllowed(_ => true)
                    .AllowCredentials()
                    .SetPreflightMaxAge(TimeSpan.FromDays(365)));

            if (_blocksSwaggerOptions != null)
            {
                app.UseSwagger();
                app.UseSwaggerUI();
            }

            app.UseMiddleware<TraceContextMiddleware>();
            app.UseMiddleware<TenantValidationMiddleware>();
            app.UseMiddleware<GlobalExceptionHandlerMiddleware>();

            app.UseRouting();

            app.UseAuthentication();
            app.UseAuthorization();

            app.MapControllers();
        }

        public static void ConfigureWorker(IServiceCollection services, MessageConfiguration messageConfiguration)
        {
            ConfigureServices(services, messageConfiguration);

            if (messageConfiguration.AzureServiceBusConfiguration != null)
            {
                services.AddHostedService<AzureMessageWorker>();
            }

            if (messageConfiguration.RabbitMqConfiguration != null)
            {
                services.AddHostedService<RabbitMessageWorker>();
            }

            services.AddSingleton<Consumer>();
            var routingTable = new RoutingTable(services);
            services.AddSingleton(routingTable);
        }

        private static async Task ConfigureMessageClient(IServiceCollection services, MessageConfiguration messageConfiguration)
        {
            messageConfiguration.Connection ??= _blocksSecret.MessageConnectionString;
            messageConfiguration.ServiceName ??= _serviceName;

            services.AddSingleton(messageConfiguration);

            if (messageConfiguration.AzureServiceBusConfiguration != null)
            {
                services.AddSingleton<IMessageClient, AzureMessageClient>();
                await ConfigerAzureServiceBus.ConfigerQueueAndTopicAsync(messageConfiguration);
            }

            if (messageConfiguration.RabbitMqConfiguration != null)
            {
                services.AddSingleton<IRabbitMqService, RabbitMqService>();
                services.AddSingleton<IMessageClient, RabbitMessageClient>();
            }
        }

        private static string GetAppSettingsFileName()
        {
            var currentEnvironment = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT");
            return string.IsNullOrWhiteSpace(currentEnvironment) ? "appsettings.json" : $"appsettings.{currentEnvironment}.json";
        }
    }
}
