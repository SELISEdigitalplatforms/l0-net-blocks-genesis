using Blocks.Genesis;
using MongoDB.Driver;



const string _serviceName = "Service-API-Test_Two";

ApplicationConfigurations.SetServiceName(_serviceName);
ApplicationConfigurations.ConfigureLog();

var builder = WebApplication.CreateBuilder(args);

// Configure services
var services = builder.Services;

services.AddSingleton<IMongoClient, MongoClient>(sp => new MongoClient("mongodb://localhost:27017"));

ApplicationConfigurations.ConfigureAuth(services);

await ApplicationConfigurations.ConfigureServices(services);

ApplicationConfigurations.ConfigureMessage(services, new MessageConfiguration
{
    Connection = "Endpoint=sb://blocks-rnd.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=yrPedlcfEp0/jHeh6m0ndC0qoyYeg5UT2+ASbObmPYU=",
    Queues = new List<string> { "demo_queue_1" },
    Topics = new List<string> { "demo_topic_1" },
    ServiceName = _serviceName,
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


