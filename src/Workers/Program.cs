using Blocks.Genesis;
using Microsoft.AspNetCore.Builder;
using WorkerOne;


CreateHostBuilder(args).Build().Run();

IHostBuilder CreateHostBuilder(string[] args) =>
        Host.CreateDefaultBuilder(args).ConfigureServices(async (hostContext, services) =>
        {
            var builder = WebApplication.CreateBuilder(args);

            ApplicationConfigurations.SetServiceName(builder.Configuration);
            ApplicationConfigurations.ConfigureLog();

            var blocksSecret = await ApplicationConfigurations.ConfigureServices(services, builder.Configuration);

            services.AddHttpClient();


            services.AddSingleton<IConsumer<W1Context>, W1Consumer>();
            services.AddSingleton<IConsumer<W2Context>, W2Consumer>();

            await ApplicationConfigurations.ConfigureMessageWorker(services, new MessageConfiguration
            {
                Connection = $"{blocksSecret.MessageConnectionString}",
                Queues = new List<string> { "demo_queue" },
                Topics = new List<string> { "demo_topic", "demo_topic_1" },
                ServiceName = ApplicationConfigurations.ServiceName
            });
        });
