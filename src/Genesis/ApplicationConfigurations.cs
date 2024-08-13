using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using MongoDB.Bson.Serialization;
using MongoDB.Bson.Serialization.Serializers;
using MongoDB.Driver;
using MongoDB.Driver.Core.Operations;
using OpenTelemetry.Metrics;
using OpenTelemetry.Trace;
using Serilog;
using System.Diagnostics;

namespace Blocks.Genesis
{
    public static class ApplicationConfigurations
    {
       

        public static string ServiceName { get; private set; }

        public static void SetServiceName(IConfigurationManager configuration)
        {
            ServiceName = configuration["ServiceName"] ?? "";
        }

        public static void ConfigureLog()
        {
            Log.Logger = new LoggerConfiguration()
                        .Enrich.FromLogContext()
                        .Enrich.With<TraceContextEnricher>()
                        .Enrich.WithEnvironmentName()
                        .WriteTo.Console()
                        .WriteTo.MongoDBWithDynamicCollection(ServiceName)
                        .CreateLogger();
        }

        public async static Task<IBlocksSecret> ConfigureServices(IServiceCollection services, IConfigurationManager configurationManager)
        {
            string _secretConfigPath = configurationManager["SecretConfigJsonPath"] ?? "";
            var blocksSecret = BlocksSecret.ProcessBlocksSecretFromJsonFile(_secretConfigPath);

            services.AddSingleton(typeof(IBlocksSecret), blocksSecret);
            services.AddSingleton<IMongoClient, MongoClient>(sp => new MongoClient($"{blocksSecret.StorageBasePath}"));

            services.AddSingleton<ICacheClient, RedisClient>();
            await LmtConfiguration.CreateCollectionAsync(ServiceName);

            var objectSerializer = new ObjectSerializer(_ => true);
            BsonSerializer.RegisterSerializer(objectSerializer);

            services.AddLogging(builder =>
            {
                builder.ClearProviders();
                builder.AddSerilog();
            });

            services.AddSingleton(new ActivitySource(ServiceName));

            services.AddOpenTelemetry()
                .WithTracing(builder =>
                {
                    builder.AddAspNetCoreInstrumentation()
                           .AddHttpClientInstrumentation()
                           .AddMongoDBInstrumentation()
                           .AddRedisInstrumentation()
                           .AddProcessor(new MongoDBTraceExporter(ServiceName));
                });
            services.AddOpenTelemetry().WithMetrics(builder =>
            {
                builder.AddAspNetCoreInstrumentation()
                       .AddRuntimeInstrumentation()
                       .AddReader(new PeriodicExportingMetricReader(new MongoDBMetricsExporter(ServiceName)));
            });

            return blocksSecret;
        }

        public static void ConfigureAuth(IServiceCollection services)
        {
            services.JwtBearerAuthentication();
            services.AddControllers();
            services.AddHttpClient();
        }

        public static void ConfigureTraceContextMiddleware(IApplicationBuilder app)
        {
            app.UseMiddleware<TraceContextMiddleware>();
        }

        public static void ConfigureAuthMiddleware(IApplicationBuilder app)
        {
            app.UseAuthentication();
            app.UseAuthorization();
        }

        public async static Task ConfigureMessageWorker(IServiceCollection services, MessageConfiguration messageConfiguration)
        {
            await ConfigerAzureServiceBus.ConfigerMessagesAsync(messageConfiguration);

            ConfigureMessage(services, messageConfiguration);

            services.AddHostedService<AzureMessageWorker>();

            services.AddSingleton<Consumer>();

            var routingTable = new RoutingTable(services);
            services.AddSingleton(routingTable);
        }

        public static void ConfigureMessage(IServiceCollection services, MessageConfiguration messageConfiguration)
        {
            services.AddSingleton(messageConfiguration);

            services.AddSingleton<IMessageClient, AzureMessageClient>();
        }
    }
}
