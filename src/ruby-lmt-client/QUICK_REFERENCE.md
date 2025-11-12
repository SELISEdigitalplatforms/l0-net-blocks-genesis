# Quick Reference Guide

A quick reference for the Selise Blocks LMT Client for Ruby.

## Installation

```ruby
# Gemfile
gem 'selise_blocks-lmt-client'

# Then run
bundle install
```

## Basic Setup

```ruby
require 'selise_blocks/lmt/client'

# Configure once at application startup
SeliseBlocks::LMT::Client.configure do |config|
  config.service_id = 'my-service'
  config.connection_string = 'Endpoint=sb://...'
  config.x_blocks_key = 'your-key'
end

# Get logger instance
logger = SeliseBlocks::LMT::BlocksLogger.instance
```

## Logging

### Basic Logging

```ruby
logger.trace('Detailed trace information')
logger.debug('Debug information')
logger.info('General information')
logger.warn('Warning message')
logger.error('Error message', exception: error)
logger.critical('Critical failure', exception: error)
```

### Logging with Parameters

```ruby
# Template-style formatting
logger.info('User %s logged in at %s', user_id: '12345', timestamp: Time.now)
logger.debug('Processing order %s for amount %s', order_id: 'ORD-001', amount: 99.99)
```

### Logging with Exceptions

```ruby
begin
  # risky code
rescue StandardError => e
  logger.error('Operation failed', exception: e)
end
```

## Tracing with OpenTelemetry

### Setup

```ruby
require 'opentelemetry/sdk'

OpenTelemetry::SDK.configure do |c|
  c.service_name = 'my-service'
  c.add_span_processor(SeliseBlocks::LMT::TraceProcessor.new)
end

tracer = OpenTelemetry.tracer_provider.tracer('my-service')
```

### Creating Spans

```ruby
# Simple span
tracer.in_span('operation_name') do
  # Your code here
end

# Span with attributes
tracer.in_span('process_payment') do |span|
  span.set_attribute('payment.id', payment_id)
  span.set_attribute('payment.amount', amount)
  span.set_attribute('user.id', user_id)
  
  # Your code here
end

# Nested spans
tracer.in_span('parent_operation') do
  # Parent work
  
  tracer.in_span('child_operation') do
    # Child work
  end
end
```

### Error Handling in Spans

```ruby
tracer.in_span('risky_operation') do |span|
  begin
    # risky code
  rescue StandardError => e
    span.status = OpenTelemetry::Trace::Status.error(e.message)
    logger.error('Operation failed', exception: e)
    raise
  end
end
```

## Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `service_id` | String | *required* | Service identifier |
| `connection_string` | String | *required* | Azure Service Bus connection |
| `x_blocks_key` | String | *required* | Blocks cloud key |
| `log_batch_size` | Integer | 100 | Logs per batch |
| `trace_batch_size` | Integer | 1000 | Traces per batch |
| `flush_interval_seconds` | Integer | 5 | Auto-flush interval |
| `max_retries` | Integer | 3 | Max retry attempts |
| `max_failed_batches` | Integer | 100 | Max failed batches |
| `enable_logging` | Boolean | true | Enable logging |
| `enable_tracing` | Boolean | true | Enable tracing |

## Manual Operations

### Force Flush

```ruby
# Force immediate flush of pending logs
logger.flush
```

### Graceful Shutdown

```ruby
# Flush and close connections
logger.shutdown

# For OpenTelemetry
OpenTelemetry.tracer_provider.shutdown
```

### Automatic Shutdown

```ruby
# At application exit
at_exit do
  logger.shutdown
  OpenTelemetry.tracer_provider.shutdown
end
```

## Framework Integration

### Rails

```ruby
# config/initializers/lmt_client.rb
SeliseBlocks::LMT::Client.configure do |config|
  config.service_id = Rails.application.credentials.service_id
  config.connection_string = Rails.application.credentials.azure_servicebus_connection_string
  config.x_blocks_key = Rails.application.credentials.x_blocks_key
end

# Shutdown hook
at_exit do
  SeliseBlocks::LMT::BlocksLogger.instance.shutdown
end
```

### Sinatra

```ruby
require 'sinatra'
require 'selise_blocks/lmt/client'

SeliseBlocks::LMT::Client.configure do |config|
  # configuration
end

logger = SeliseBlocks::LMT::BlocksLogger.instance

get '/endpoint' do
  logger.info('Request received')
  # handler code
end

at_exit do
  logger.shutdown
end
```

### Rack Middleware

```ruby
class LMTMiddleware
  def initialize(app)
    @app = app
    @logger = SeliseBlocks::LMT::BlocksLogger.instance
  end

  def call(env)
    @logger.info('Request: %s %s', method: env['REQUEST_METHOD'], path: env['PATH_INFO'])
    status, headers, body = @app.call(env)
    @logger.info('Response: %s', status: status)
    [status, headers, body]
  rescue => e
    @logger.error('Request failed', exception: e)
    raise
  end
end

# Use it
use LMTMiddleware
```

## Common Patterns

### Request/Response Logging

```ruby
def handle_request(request)
  logger.info('Incoming request', 
    method: request.method,
    path: request.path,
    user_id: request.user_id
  )
  
  response = process(request)
  
  logger.info('Request completed',
    status: response.status,
    duration: response.duration
  )
  
  response
rescue => e
  logger.error('Request failed', exception: e)
  raise
end
```

### Background Job Logging

```ruby
class MyJob
  def perform(*args)
    logger = SeliseBlocks::LMT::BlocksLogger.instance
    logger.info('Job started', args: args)
    
    # job logic
    
    logger.info('Job completed')
  rescue => e
    logger.error('Job failed', exception: e)
    raise
  end
end
```

### Database Query Tracing

```ruby
def fetch_user(user_id)
  tracer = OpenTelemetry.tracer_provider.tracer('my-service')
  
  tracer.in_span('db.query.users') do |span|
    span.set_attribute('db.operation', 'SELECT')
    span.set_attribute('db.table', 'users')
    span.set_attribute('user.id', user_id)
    
    User.find(user_id)
  end
end
```

## Environment Variables

```bash
# Required
export SERVICE_ID="my-service"
export AZURE_SERVICEBUS_CONNECTION_STRING="Endpoint=sb://..."
export X_BLOCKS_KEY="your-key"

# Optional - Override defaults
export LOG_BATCH_SIZE="200"
export TRACE_BATCH_SIZE="2000"
export FLUSH_INTERVAL_SECONDS="10"
export MAX_RETRIES="5"
```

## Testing

```ruby
# spec/spec_helper.rb
require 'selise_blocks/lmt/client'

RSpec.configure do |config|
  config.before(:each) do
    # Reset configuration for each test
    SeliseBlocks::LMT.reset_configuration!
  end
end

# In tests
RSpec.describe MyClass do
  before do
    SeliseBlocks::LMT::Client.configure do |config|
      config.service_id = 'test-service'
      config.connection_string = 'test-connection'
      config.x_blocks_key = 'test-key'
      config.enable_logging = false  # Disable during tests if needed
    end
  end
  
  it 'logs correctly' do
    # test code
  end
end
```

## Troubleshooting

### Check if initialized

```ruby
logger = SeliseBlocks::LMT::BlocksLogger.instance
# Automatically initializes on first use
```

### Check configuration

```ruby
config = SeliseBlocks::LMT.configuration
puts config.service_id
puts config.enable_logging
```

### Manual flush for testing

```ruby
logger.info('Test message')
logger.flush  # Force immediate send
sleep(1)      # Give it time to complete
```

## Performance Tips

1. **Batch Size**: Increase for high-throughput applications
2. **Flush Interval**: Adjust based on your latency requirements
3. **Disable in Tests**: Set `enable_logging = false` in test environment
4. **Async Operations**: Batching and sending happens in background threads
5. **Connection Pooling**: Single sender per service instance

## Links

- [Full Documentation](README.md)
- [Installation Guide](INSTALLATION.md)
- [Examples](examples/)
- [GitHub](https://github.com/selise/blocks-lmt-client-ruby)

