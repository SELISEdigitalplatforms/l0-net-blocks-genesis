using Blocks.Genesis;

var builder = WebApplication.CreateBuilder(args);
var configuration = builder.Configuration;

ApplicationConfigurations.SetServiceName(configuration);
ApplicationConfigurations.ConfigureLog();

var services = builder.Services;

var blocksSecret = await ApplicationConfigurations.ConfigureServices(services, configuration);
ApplicationConfigurations.ConfigureAuth(services);

ApplicationConfigurations.ConfigureMessage(services, new MessageConfiguration
{
    Connection = $"{blocksSecret.MetricConnectionString}",
    Queues = new List<string> { "demo_queue_1" },
    Topics = new List<string> { "demo_topic_1" },
    ServiceName = ApplicationConfigurations.ServiceName,
});

var app = builder.Build();

// Configure middleware
if (app.Environment.IsDevelopment())
{
    app.UseDeveloperExceptionPage();
}

ApplicationConfigurations.ConfigureTraceContextMiddleware(app);

app.UseRouting();

ApplicationConfigurations.ConfigureAuthMiddleware(app);

app.MapControllers();

app.Run();


