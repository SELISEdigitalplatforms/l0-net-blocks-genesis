# Testing Guide for Selise Blocks LMT Client (Ruby)

This guide covers different ways to test the Ruby LMT Client implementation.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Unit Tests](#unit-tests)
3. [Manual Testing](#manual-testing)
4. [Integration Testing](#integration-testing)
5. [Testing Checklist](#testing-checklist)

---

## Prerequisites

### 1. Install Dependencies

```bash
cd /Users/kazilakit/Selise/Repos/l0-net-blocks-genesis/src/ruby-lmt-client
bundle install
```

### 2. Set Up Azure Service Bus (for integration testing)

You'll need:
- Azure Service Bus namespace
- Connection string
- A topic created: `lmt-test-service`
- Two subscriptions on that topic:
  - `blocks-lmt-service-logs`
  - `blocks-lmt-service-traces`

### 3. Environment Variables

```bash
export SERVICE_ID="test-service"
export AZURE_SERVICEBUS_CONNECTION_STRING="Endpoint=sb://your-namespace.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=your-key"
export X_BLOCKS_KEY="your-x-blocks-key"
```

---

## Unit Tests

### Run All Tests

```bash
bundle exec rspec
```

### Run Specific Test Files

```bash
# Configuration tests
bundle exec rspec spec/selise_blocks/lmt/configuration_spec.rb

# Log level tests
bundle exec rspec spec/selise_blocks/lmt/log_level_spec.rb

# Log data tests
bundle exec rspec spec/selise_blocks/lmt/log_data_spec.rb
```

### Run with Detailed Output

```bash
bundle exec rspec --format documentation
```

### Expected Output

```
SeliseBlocks::LMT::Configuration
  #initialize
    sets default values
  #validate!
    raises error when service_id is empty
    raises error when connection_string is empty
    raises error when x_blocks_key is empty
    does not raise error when all required fields are set

SeliseBlocks::LMT
  .configure
    yields configuration object
    sets configuration values
    validates configuration after block
  .reset_configuration!
    resets configuration to defaults

SeliseBlocks::LMT::Constants
  .topic_name
    returns correctly formatted topic name
  constants
    defines LOG_SUBSCRIPTION
    defines TRACE_SUBSCRIPTION

SeliseBlocks::LMT::LogLevel
  .name
    returns correct name for TRACE
    returns correct name for DEBUG
    returns correct name for INFORMATION
    returns correct name for WARNING
    returns correct name for ERROR
    returns correct name for CRITICAL
    returns Unknown for invalid level
  constants
    defines correct numeric values

SeliseBlocks::LMT::LogData
  #initialize
    sets default values
  #to_h
    converts to hash with all fields

SeliseBlocks::LMT::FailedLogBatch
  #initialize
    sets default values
    accepts custom values

Finished in 0.05 seconds (files took 0.5 seconds to load)
20 examples, 0 failures
```

---

## Manual Testing

### Test 1: Basic Logging (Mock Mode)

Create a test file `test_basic_logging.rb`:

```ruby
#!/usr/bin/env ruby
require_relative 'lib/selise_blocks/lmt/client'

# Configure without real Azure connection (for structure testing)
SeliseBlocks::LMT::Client.configure do |config|
  config.service_id = 'test-service'
  config.connection_string = 'mock-connection'
  config.x_blocks_key = 'mock-key'
  config.enable_logging = false  # Disable actual sending
end

logger = SeliseBlocks::LMT::BlocksLogger.instance

# Test all log levels
logger.trace('This is a trace message')
logger.debug('This is a debug message')
logger.info('This is an info message')
logger.warn('This is a warning message')

begin
  raise StandardError, 'Test error'
rescue => e
  logger.error('This is an error message', exception: e)
  logger.critical('This is a critical message', exception: e)
end

# Test template formatting
logger.info('User %s logged in at %s', user_id: '12345', timestamp: Time.now)

puts '✅ Basic logging test completed'
```

Run it:
```bash
ruby test_basic_logging.rb
```

### Test 2: Configuration Validation

Create `test_configuration.rb`:

```ruby
#!/usr/bin/env ruby
require_relative 'lib/selise_blocks/lmt/client'

puts "Testing configuration validation..."

# Test 1: Missing service_id
begin
  SeliseBlocks::LMT::Client.configure do |config|
    config.connection_string = 'test'
    config.x_blocks_key = 'test'
  end
  puts "❌ Should have raised error for missing service_id"
rescue ArgumentError => e
  puts "✅ Correctly raised error: #{e.message}"
end

SeliseBlocks::LMT.reset_configuration!

# Test 2: Missing connection_string
begin
  SeliseBlocks::LMT::Client.configure do |config|
    config.service_id = 'test'
    config.x_blocks_key = 'test'
  end
  puts "❌ Should have raised error for missing connection_string"
rescue ArgumentError => e
  puts "✅ Correctly raised error: #{e.message}"
end

SeliseBlocks::LMT.reset_configuration!

# Test 3: Valid configuration
begin
  SeliseBlocks::LMT::Client.configure do |config|
    config.service_id = 'test-service'
    config.connection_string = 'test-connection'
    config.x_blocks_key = 'test-key'
  end
  puts "✅ Valid configuration accepted"
rescue => e
  puts "❌ Should not have raised error: #{e.message}"
end

puts "\n✅ Configuration validation tests completed"
```

Run it:
```bash
ruby test_configuration.rb
```

### Test 3: Real Azure Service Bus Integration

Create `test_azure_integration.rb`:

```ruby
#!/usr/bin/env ruby
require_relative 'lib/selise_blocks/lmt/client'

# Check environment variables
unless ENV['AZURE_SERVICEBUS_CONNECTION_STRING'] && ENV['X_BLOCKS_KEY']
  puts "❌ Please set AZURE_SERVICEBUS_CONNECTION_STRING and X_BLOCKS_KEY environment variables"
  exit 1
end

puts "🚀 Testing Azure Service Bus integration..."

# Configure with real connection
SeliseBlocks::LMT::Client.configure do |config|
  config.service_id = ENV['SERVICE_ID'] || 'ruby-test-service'
  config.connection_string = ENV['AZURE_SERVICEBUS_CONNECTION_STRING']
  config.x_blocks_key = ENV['X_BLOCKS_KEY']
  config.log_batch_size = 5  # Small batch for quick testing
  config.flush_interval_seconds = 2  # Quick flush for testing
end

logger = SeliseBlocks::LMT::BlocksLogger.instance

# Send test logs
puts "📝 Sending test logs..."
5.times do |i|
  logger.info("Test log message #{i + 1}")
end

# Test with exception
begin
  raise StandardError, 'Test exception for Azure'
rescue => e
  logger.error('Test error with exception', exception: e)
end

puts "⏳ Waiting for batch to flush (3 seconds)..."
sleep(3)

# Force flush
logger.flush
sleep(1)

puts "✅ Logs sent to Azure Service Bus!"
puts "📊 Check your Azure Portal to verify messages in topic: lmt-#{ENV['SERVICE_ID'] || 'ruby-test-service'}"
puts "   Subscription: blocks-lmt-service-logs"

# Shutdown
logger.shutdown
puts "✅ Azure integration test completed"
```

Run it:
```bash
ruby test_azure_integration.rb
```

### Test 4: OpenTelemetry Tracing

Create `test_tracing.rb`:

```ruby
#!/usr/bin/env ruby
require_relative 'lib/selise_blocks/lmt/client'
require 'opentelemetry/sdk'

unless ENV['AZURE_SERVICEBUS_CONNECTION_STRING'] && ENV['X_BLOCKS_KEY']
  puts "❌ Please set AZURE_SERVICEBUS_CONNECTION_STRING and X_BLOCKS_KEY environment variables"
  exit 1
end

puts "🔍 Testing OpenTelemetry tracing..."

# Configure LMT
SeliseBlocks::LMT::Client.configure do |config|
  config.service_id = ENV['SERVICE_ID'] || 'ruby-test-service'
  config.connection_string = ENV['AZURE_SERVICEBUS_CONNECTION_STRING']
  config.x_blocks_key = ENV['X_BLOCKS_KEY']
  config.trace_batch_size = 5
  config.flush_interval_seconds = 2
end

# Configure OpenTelemetry
OpenTelemetry::SDK.configure do |c|
  c.service_name = ENV['SERVICE_ID'] || 'ruby-test-service'
  c.add_span_processor(SeliseBlocks::LMT::TraceProcessor.new)
end

logger = SeliseBlocks::LMT::BlocksLogger.instance
tracer = OpenTelemetry.tracer_provider.tracer(ENV['SERVICE_ID'] || 'ruby-test-service')

# Create test spans
puts "📊 Creating test spans..."

tracer.in_span('test_operation') do |span|
  span.set_attribute('test.id', 'test-001')
  span.set_attribute('test.type', 'integration')
  logger.info('Inside traced operation')
  
  sleep(0.1)
  
  # Nested span
  tracer.in_span('nested_operation') do |child_span|
    child_span.set_attribute('nested.level', 1)
    logger.debug('Inside nested operation')
    sleep(0.05)
  end
end

# Test span with error
tracer.in_span('error_operation') do |span|
  span.set_attribute('error.test', true)
  begin
    raise StandardError, 'Test error in span'
  rescue => e
    span.status = OpenTelemetry::Trace::Status.error(e.message)
    logger.error('Error in traced operation', exception: e)
  end
end

puts "⏳ Waiting for traces to flush (3 seconds)..."
sleep(3)

# Shutdown
logger.shutdown
OpenTelemetry.tracer_provider.shutdown

puts "✅ Tracing test completed!"
puts "📊 Check your Azure Portal to verify messages in topic: lmt-#{ENV['SERVICE_ID'] || 'ruby-test-service'}"
puts "   Subscription: blocks-lmt-service-traces"
```

Run it:
```bash
ruby test_tracing.rb
```

---

## Integration Testing

### Using the Example Files

The examples directory contains ready-to-use integration tests:

#### 1. Basic Usage Example

```bash
cd examples
ruby basic_usage.rb
```

#### 2. OpenTelemetry Example

```bash
ruby with_opentelemetry.rb
```

#### 3. Sinatra Web Application

```bash
# Install Sinatra if not already installed
gem install sinatra

# Run the app
ruby sinatra_app.rb

# In another terminal, test the endpoints:
curl http://localhost:4567/
curl http://localhost:4567/api/users/123
curl http://localhost:4567/api/health
curl -X POST http://localhost:4567/api/orders \
  -H "Content-Type: application/json" \
  -d '{"user_id": "123", "amount": 99.99, "payment_method": "credit_card"}'
```

---

## Testing Checklist

### ✅ Unit Tests

- [ ] Configuration validation works correctly
- [ ] Log levels are properly defined
- [ ] Data models serialize correctly
- [ ] All specs pass: `bundle exec rspec`

### ✅ Functional Tests

- [ ] Logger can be initialized with valid config
- [ ] All log levels work (trace, debug, info, warn, error, critical)
- [ ] Template formatting works with parameters
- [ ] Exception logging captures stack traces
- [ ] Logs are batched correctly
- [ ] Auto-flush timer works

### ✅ Integration Tests

- [ ] Can connect to Azure Service Bus
- [ ] Logs are sent to correct topic
- [ ] Messages have correct properties
- [ ] Retry logic works on failures
- [ ] Failed batch queue works
- [ ] Graceful shutdown flushes pending messages

### ✅ Tracing Tests

- [ ] OpenTelemetry integration works
- [ ] Spans are created and captured
- [ ] Span attributes are recorded
- [ ] Parent-child relationships work
- [ ] Traces are batched correctly
- [ ] Traces are sent to correct subscription

### ✅ Performance Tests

- [ ] High-volume logging doesn't block
- [ ] Batching reduces network calls
- [ ] Background threads don't cause issues
- [ ] Memory usage is reasonable

---

## Verifying Messages in Azure

### Using Azure Portal

1. Go to your Service Bus namespace
2. Navigate to "Topics"
3. Click on `lmt-test-service` (or your service name)
4. Click on a subscription (`blocks-lmt-service-logs` or `blocks-lmt-service-traces`)
5. Click "Service Bus Explorer"
6. Click "Peek from start" to see messages

### Using Azure CLI

```bash
# List messages in logs subscription
az servicebus topic subscription show \
  --namespace-name your-namespace \
  --topic-name lmt-test-service \
  --name blocks-lmt-service-logs \
  --resource-group your-resource-group

# List messages in traces subscription
az servicebus topic subscription show \
  --namespace-name your-namespace \
  --topic-name lmt-test-service \
  --name blocks-lmt-service-traces \
  --resource-group your-resource-group
```

---

## Troubleshooting

### Issue: Tests fail with connection errors

**Solution**: Verify your Azure Service Bus connection string and that the topic exists.

```bash
# Check environment variables
echo $AZURE_SERVICEBUS_CONNECTION_STRING
echo $X_BLOCKS_KEY
```

### Issue: No messages appear in Azure

**Possible causes**:
1. Batching hasn't flushed yet - wait for flush interval or call `logger.flush`
2. Wrong topic name - verify topic is named `lmt-{service_id}`
3. Wrong subscription name - must be exactly `blocks-lmt-service-logs` or `blocks-lmt-service-traces`
4. Connection string is invalid

### Issue: RSpec tests fail

**Solution**: Make sure all dependencies are installed:

```bash
bundle install
```

### Issue: "Could not find gem" errors

**Solution**: The gem isn't published yet. Use it locally:

```bash
# In your test file
require_relative 'lib/selise_blocks/lmt/client'

# Or add to your Gemfile
gem 'selise_blocks-lmt-client', path: './src/ruby-lmt-client'
```

---

## Quick Test Script

Here's a complete test script you can run:

```bash
#!/bin/bash

echo "🧪 Testing Ruby LMT Client..."

cd /Users/kazilakit/Selise/Repos/l0-net-blocks-genesis/src/ruby-lmt-client

# 1. Install dependencies
echo "📦 Installing dependencies..."
bundle install

# 2. Run unit tests
echo "🧪 Running unit tests..."
bundle exec rspec --format documentation

# 3. Check if Azure credentials are set
if [ -z "$AZURE_SERVICEBUS_CONNECTION_STRING" ]; then
    echo "⚠️  AZURE_SERVICEBUS_CONNECTION_STRING not set - skipping integration tests"
    exit 0
fi

# 4. Run basic example
echo "📝 Running basic logging example..."
ruby examples/basic_usage.rb

# 5. Run OpenTelemetry example
echo "🔍 Running tracing example..."
ruby examples/with_opentelemetry.rb

echo "✅ All tests completed!"
```

Save as `run_tests.sh`, make executable, and run:

```bash
chmod +x run_tests.sh
./run_tests.sh
```

---

## Next Steps

1. **Start with unit tests**: `bundle exec rspec`
2. **Test configuration**: Run the configuration test script
3. **Test locally**: Use mock mode to test structure
4. **Test with Azure**: Set up environment variables and run integration tests
5. **Test tracing**: Run OpenTelemetry integration tests
6. **Test in production**: Use the Sinatra example as a reference

Happy testing! 🎉

