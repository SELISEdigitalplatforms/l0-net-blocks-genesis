# SeliseBlocks::LMT::Client

A robust and high-performance Ruby client library for logging and distributed tracing with Azure Service Bus integration. Designed for enterprise applications requiring centralized log and trace management with built-in resilience, batching, and automatic retry mechanisms.

## ✨ Features

- **🚀 High Performance** - Automatic batching reduces network overhead and improves throughput
- **🔄 Automatic Retry Logic** - Exponential backoff with configurable retry attempts
- **💾 Failed Batch Queue** - Prevents data loss during transient failures
- **🧵 Thread-Safe** - Built with thread-safe queues for multi-threaded environments
- **📊 OpenTelemetry Integration** - Industry-standard distributed tracing support
- **🏢 Multi-Tenant Support** - Automatic tenant isolation via baggage propagation
- **⚡ Zero Dependencies on Logging Frameworks** - Works independently or alongside standard Ruby Logger
- **🎯 Azure Service Bus Native** - Optimized for Azure Service Bus Topics and Subscriptions
- **🔌 Easy Integration** - Simple setup with minimal configuration

## 🏗️ Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                      Your Application                          │
│  ┌──────────────┐              ┌──────────────────────┐        │
│  │ BlocksLogger │              │  OpenTelemetry       │        │
│  │   (Logs)     │              │  (Traces)            │        │
│  └──────┬───────┘              └──────────┬───────────┘        │
│         │                                 │                    │
│         │  Batching & Retry               │  Batching & Retry  │
│         ▼                                 ▼                    │
│  ┌──────────────────────────────────────────────────────┐      │
│  │              Azure Service Bus                       │      │
│  └──────────────────┬───────────────────────────────────┘      │
└─────────────────────┼──────────────────────────────────────────┘
                      │
                      ▼
          ┌───────────────────────┐
          │  LMT Service Worker   │
          │  (Subscriptions)      │
          └───────────┬───────────┘
                      │
                      ▼
          ┌───────────────────────┐
          │   MongoDB Storage     │
          │  • Logs by Service    │
          │  • Traces by Tenant   │
          └───────────────────────┘
```

## 📦 Installation

Add this line to your application's Gemfile:

```ruby
gem 'selise_blocks-lmt-client'
```

Or install it yourself as:

```bash
gem install selise_blocks-lmt-client
```

## 🚀 Quick Start

### 1. Configuration

Create a configuration file or set environment variables:

```ruby
require 'selise_blocks/lmt/client'

SeliseBlocks::LMT::Client.configure do |config|
  config.service_id = 'your-service-id'
  config.connection_string = 'Endpoint=sb://your-namespace.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=your-key'
  config.x_blocks_key = 'your-XBlocksKey'
  config.log_batch_size = 100
  config.trace_batch_size = 1000
  config.flush_interval_seconds = 5
  config.max_retries = 3
  config.max_failed_batches = 100
  config.enable_logging = true
  config.enable_tracing = true
end
```

### 2. Using the Logger

```ruby
require 'selise_blocks/lmt/client'

logger = SeliseBlocks::LMT::BlocksLogger.instance

# Log at different levels
logger.trace('Entering method process_payment')
logger.debug('Payment gateway response received')
logger.info('Payment processed successfully at %s', Time.now)
logger.warn('Payment took longer than expected')
logger.error('Payment failed', exception: error)
logger.critical('Payment gateway is down', exception: error)
```

### 3. Using with OpenTelemetry

```ruby
require 'opentelemetry/sdk'
require 'selise_blocks/lmt/client'

# Setup OpenTelemetry
OpenTelemetry::SDK.configure do |c|
  c.service_name = 'your-service-id'
  
  # Add LMT Trace Processor
  c.add_span_processor(SeliseBlocks::LMT::TraceProcessor.new)
end

# Create spans
tracer = OpenTelemetry.tracer_provider.tracer('your-service-id')

tracer.in_span('process_payment') do |span|
  logger.info('Processing payment')
  # Your code here
end
```

### 4. Complete Example with Sinatra

```ruby
require 'sinatra'
require 'opentelemetry/sdk'
require 'opentelemetry/instrumentation/sinatra'
require 'selise_blocks/lmt/client'

# Configure LMT Client
SeliseBlocks::LMT::Client.configure do |config|
  config.service_id = 'my-api-service'
  config.connection_string = ENV['AZURE_SERVICEBUS_CONNECTION_STRING']
  config.x_blocks_key = ENV['X_BLOCKS_KEY']
end

# Setup OpenTelemetry
OpenTelemetry::SDK.configure do |c|
  c.service_name = 'my-api-service'
  c.use 'OpenTelemetry::Instrumentation::Sinatra'
  c.add_span_processor(SeliseBlocks::LMT::TraceProcessor.new)
end

# Get logger instance
logger = SeliseBlocks::LMT::BlocksLogger.instance

get '/api/users/:id' do
  logger.info('Fetching user %s', params[:id])
  
  begin
    user = User.find(params[:id])
    logger.debug('User found: %s', user.email)
    user.to_json
  rescue => e
    logger.error('Failed to fetch user', exception: e)
    status 500
    { error: 'Internal server error' }.to_json
  end
end

# Graceful shutdown
at_exit do
  SeliseBlocks::LMT::BlocksLogger.instance.shutdown
end
```

## ⚙️ Configuration Options

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `service_id` | `String` | *required* | Unique identifier for your service |
| `connection_string` | `String` | *required* | Azure Service Bus connection string |
| `x_blocks_key` | `String` | *required* | Selise blocks cloud key |
| `log_batch_size` | `Integer` | `100` | Number of logs to batch before sending |
| `trace_batch_size` | `Integer` | `1000` | Number of traces to batch before sending |
| `flush_interval_seconds` | `Integer` | `5` | Interval to flush batches automatically |
| `max_retries` | `Integer` | `3` | Maximum retry attempts for failed sends |
| `max_failed_batches` | `Integer` | `100` | Maximum failed batches to queue |
| `enable_logging` | `Boolean` | `true` | Enable/disable logging |
| `enable_tracing` | `Boolean` | `true` | Enable/disable tracing |

## 📊 Log Levels

```ruby
logger = SeliseBlocks::LMT::BlocksLogger.instance

# Trace - Most detailed information
logger.trace('Entering method process_payment')

# Debug - Debugging information
logger.debug('Payment gateway response received')

# Information - General flow
logger.info('Payment processed successfully at %s', Time.now)

# Warning - Unexpected but handled situations
logger.warn('Payment took longer than expected')

# Error - Errors and exceptions
logger.error('Payment failed', exception: error)

# Critical - Critical failures
logger.critical('Payment gateway is down', exception: error)
```

## 🔧 Advanced Usage

### Custom Span Attributes

```ruby
tracer = OpenTelemetry.tracer_provider.tracer('my-service')

tracer.in_span('process_order') do |span|
  span.set_attribute('order.id', order_id)
  span.set_attribute('order.amount', amount)
  span.set_attribute('user.id', user_id)
  
  logger.info('Processing order %s', order_id)
  # Your code here
end
```

### Manual Flush

```ruby
logger = SeliseBlocks::LMT::BlocksLogger.instance

# Log some messages
logger.info('Message 1')
logger.info('Message 2')

# Force flush immediately
logger.flush
```

### Graceful Shutdown

```ruby
# In your application shutdown handler
at_exit do
  logger = SeliseBlocks::LMT::BlocksLogger.instance
  logger.shutdown # Flushes all pending logs and closes connections
end
```

## 🧪 Testing

Run the test suite:

```bash
bundle exec rspec
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

1. Fork it
2. Create your feature branch (`git checkout -b feature/my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin feature/my-new-feature`)
5. Create new Pull Request

