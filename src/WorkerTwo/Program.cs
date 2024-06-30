using Blocks.Genesis;
using WorkerTwo;


const string _serviceName = "Service-Worker-Test_Two";
ApplicationConfigurations.SetServiceName(_serviceName);
ApplicationConfigurations.ConfigureLog();
CreateHostBuilder(args).Build().Run();


IHostBuilder CreateHostBuilder(string[] args) =>
        Host.CreateDefaultBuilder(args).ConfigureServices((hostContext, services) =>
        {

            services.AddHttpClient();

            ApplicationConfigurations.ConfigureServices(services);


            services.AddSingleton<IConsumer<W1Context>, W1Consumer>();
            services.AddSingleton<IConsumer<W2Context>, W2Consumer>();

            ApplicationConfigurations.ConfigureMessageWorker(services, new MessageConfiguration
            {
                Connection = "Endpoint=sb://blocks-rnd.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=yrPedlcfEp0/jHeh6m0ndC0qoyYeg5UT2+ASbObmPYU=",
                Queues = new List<string> { "demo_queue_1" },
                Topics = new List<string> { "demo_topic" },
                ServiceName = _serviceName,
            });

        });
