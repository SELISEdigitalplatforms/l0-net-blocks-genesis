# Installation Guide

This guide will help you install and set up the Selise Blocks LMT Client for Ruby.

## Prerequisites

- Ruby 2.7 or higher
- Bundler 2.0 or higher
- Azure Service Bus namespace with connection string
- Selise Blocks account with X-Blocks-Key

## Installation

### Option 1: Using Bundler (Recommended)

Add this line to your application's `Gemfile`:

```ruby
gem 'selise_blocks-lmt-client'
```

Then execute:

```bash
bundle install
```

### Option 2: Install Directly

```bash
gem install selise_blocks-lmt-client
```

### Option 3: From Source (Development)

Clone the repository:

```bash
git clone https://github.com/selise/blocks-lmt-client-ruby.git
cd blocks-lmt-client-ruby
```

Install dependencies:

```bash
bundle install
```

Build and install the gem:

```bash
rake build
gem install pkg/selise_blocks-lmt-client-1.0.0.gem
```

## Configuration

### Environment Variables

Set up the following environment variables:

```bash
export SERVICE_ID="your-service-id"
export AZURE_SERVICEBUS_CONNECTION_STRING="Endpoint=sb://your-namespace.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=your-key"
export X_BLOCKS_KEY="your-x-blocks-key"
```

### Configuration in Code

```ruby
require 'selise_blocks/lmt/client'

SeliseBlocks::LMT::Client.configure do |config|
  config.service_id = ENV['SERVICE_ID']
  config.connection_string = ENV['AZURE_SERVICEBUS_CONNECTION_STRING']
  config.x_blocks_key = ENV['X_BLOCKS_KEY']
  
  # Optional configurations with defaults
  config.log_batch_size = 100          # Number of logs per batch
  config.trace_batch_size = 1000       # Number of traces per batch
  config.flush_interval_seconds = 5    # Auto-flush interval
  config.max_retries = 3               # Max retry attempts
  config.max_failed_batches = 100      # Max failed batches to queue
  config.enable_logging = true         # Enable/disable logging
  config.enable_tracing = true         # Enable/disable tracing
end
```

## Azure Service Bus Setup

### 1. Create Service Bus Namespace

```bash
# Using Azure CLI
az servicebus namespace create \
  --name your-namespace \
  --resource-group your-resource-group \
  --location eastus \
  --sku Standard
```

### 2. Create Topic

The LMT client automatically sends to a topic named `lmt-{service_id}`. You need to create this topic:

```bash
az servicebus topic create \
  --name lmt-your-service-id \
  --namespace-name your-namespace \
  --resource-group your-resource-group
```

### 3. Create Subscriptions

Create two subscriptions for logs and traces:

```bash
# Logs subscription
az servicebus topic subscription create \
  --name blocks-lmt-service-logs \
  --topic-name lmt-your-service-id \
  --namespace-name your-namespace \
  --resource-group your-resource-group

# Traces subscription
az servicebus topic subscription create \
  --name blocks-lmt-service-traces \
  --topic-name lmt-your-service-id \
  --namespace-name your-namespace \
  --resource-group your-resource-group
```

### 4. Get Connection String

```bash
az servicebus namespace authorization-rule keys list \
  --namespace-name your-namespace \
  --resource-group your-resource-group \
  --name RootManageSharedAccessKey \
  --query primaryConnectionString \
  --output tsv
```

## Verification

### Test Basic Logging

Create a file `test_lmt.rb`:

```ruby
require 'selise_blocks/lmt/client'

SeliseBlocks::LMT::Client.configure do |config|
  config.service_id = ENV['SERVICE_ID']
  config.connection_string = ENV['AZURE_SERVICEBUS_CONNECTION_STRING']
  config.x_blocks_key = ENV['X_BLOCKS_KEY']
end

logger = SeliseBlocks::LMT::BlocksLogger.instance

logger.info('Test message from Ruby LMT Client')
logger.debug('This is a debug message')

sleep(6) # Wait for flush

logger.shutdown
puts 'Test complete!'
```

Run it:

```bash
ruby test_lmt.rb
```

### Test with OpenTelemetry

```ruby
require 'selise_blocks/lmt/client'
require 'opentelemetry/sdk'

SeliseBlocks::LMT::Client.configure do |config|
  config.service_id = ENV['SERVICE_ID']
  config.connection_string = ENV['AZURE_SERVICEBUS_CONNECTION_STRING']
  config.x_blocks_key = ENV['X_BLOCKS_KEY']
end

OpenTelemetry::SDK.configure do |c|
  c.service_name = ENV['SERVICE_ID']
  c.add_span_processor(SeliseBlocks::LMT::TraceProcessor.new)
end

logger = SeliseBlocks::LMT::BlocksLogger.instance
tracer = OpenTelemetry.tracer_provider.tracer(ENV['SERVICE_ID'])

tracer.in_span('test_operation') do |span|
  span.set_attribute('test.attribute', 'value')
  logger.info('Inside traced operation')
end

sleep(6)
logger.shutdown
OpenTelemetry.tracer_provider.shutdown
puts 'Trace test complete!'
```

## Framework Integration

### Ruby on Rails

In `config/initializers/lmt_client.rb`:

```ruby
require 'selise_blocks/lmt/client'

SeliseBlocks::LMT::Client.configure do |config|
  config.service_id = Rails.application.credentials.service_id
  config.connection_string = Rails.application.credentials.azure_servicebus_connection_string
  config.x_blocks_key = Rails.application.credentials.x_blocks_key
end

# Setup OpenTelemetry
OpenTelemetry::SDK.configure do |c|
  c.service_name = Rails.application.credentials.service_id
  c.use 'OpenTelemetry::Instrumentation::Rails'
  c.add_span_processor(SeliseBlocks::LMT::TraceProcessor.new)
end

# Graceful shutdown
at_exit do
  SeliseBlocks::LMT::BlocksLogger.instance.shutdown
  OpenTelemetry.tracer_provider.shutdown
end
```

### Sinatra

See `examples/sinatra_app.rb` for a complete example.

### Sidekiq

In your Sidekiq initializer:

```ruby
require 'selise_blocks/lmt/client'

SeliseBlocks::LMT::Client.configure do |config|
  config.service_id = ENV['SERVICE_ID']
  config.connection_string = ENV['AZURE_SERVICEBUS_CONNECTION_STRING']
  config.x_blocks_key = ENV['X_BLOCKS_KEY']
end

# Use in workers
class MyWorker
  include Sidekiq::Worker

  def perform(*args)
    logger = SeliseBlocks::LMT::BlocksLogger.instance
    logger.info('Processing job', args: args)
    
    # Your job logic
    
    logger.info('Job completed')
  end
end
```

## Troubleshooting

### Connection Issues

If you're having trouble connecting to Azure Service Bus:

1. Verify your connection string is correct
2. Check your firewall settings
3. Ensure the Service Bus namespace exists
4. Verify the topic and subscriptions are created

### Messages Not Appearing

If messages aren't showing up:

1. Check the batch size and flush interval - you may need to wait
2. Call `logger.flush` manually to force flush
3. Ensure `enable_logging` and `enable_tracing` are `true`
4. Check Service Bus metrics in Azure Portal

### Performance Issues

If you're experiencing performance issues:

1. Increase batch sizes for less frequent sends
2. Adjust flush interval based on your needs
3. Monitor failed batch queue size
4. Check retry settings

## Getting Help

- GitHub Issues: https://github.com/selise/blocks-lmt-client-ruby/issues
- Documentation: https://github.com/selise/blocks-lmt-client-ruby
- Email: support@selise.ch

## Next Steps

- Read the [README](README.md) for usage examples
- Check out the [examples](examples/) directory
- Review the [CHANGELOG](CHANGELOG.md) for version history

