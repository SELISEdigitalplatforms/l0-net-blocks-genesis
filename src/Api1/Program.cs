using Blocks.Genesis;


var builder = WebApplication.CreateBuilder(args);
var configuration = builder.Configuration;

ApplicationConfigurations.SetServiceName(configuration);
ApplicationConfigurations.ConfigureLog();

var services = builder.Services;

// Configure services
var blocksSecret = await ApplicationConfigurations.ConfigureServices(services, configuration);
ApplicationConfigurations.ConfigureAuth(services);

ApplicationConfigurations.ConfigureMessage(services, new MessageConfiguration
{
    Connection = $"{blocksSecret.MessageConnectionString}",
    Queues = new List<string> { "demo_queue" },
    Topics = new List<string> { "demo_topic" },
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
