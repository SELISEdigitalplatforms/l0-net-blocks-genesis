# C# to Ruby Conversion - Implementation Comparison

This document provides a detailed comparison between the C# .NET implementation and the Ruby implementation of the Blocks LMT Client.

## Overview

The Ruby implementation maintains feature parity with the C# version while following Ruby idioms and best practices.

## Architecture Comparison

### C# Implementation
- Uses `System.Threading` for timers and async operations
- `ConcurrentQueue<T>` for thread-safe collections
- `SemaphoreSlim` for synchronization
- `IDisposable` pattern for resource cleanup
- Dependency injection via `IServiceCollection`
- OpenTelemetry `BaseProcessor<Activity>` for traces

### Ruby Implementation
- Uses `Concurrent::TimerTask` from concurrent-ruby gem
- `Concurrent::Array` for thread-safe collections
- `Mutex` for synchronization
- Explicit `close`/`shutdown` methods for cleanup
- Singleton pattern for logger instance
- OpenTelemetry `SpanProcessor` for traces

## File-by-File Comparison

### 1. Configuration

**C# (`LmtOptions.cs`)**
```csharp
public class LmtOptions
{
    public string ServiceId { get; set; } = string.Empty;
    public string ConnectionString { get; set; } = string.Empty;
    // ... other properties
}
```

**Ruby (`configuration.rb`)**
```ruby
class Configuration
  attr_accessor :service_id, :connection_string
  # ... other attributes
  
  def validate!
    raise ArgumentError, 'service_id is required' if service_id.nil? || service_id.empty?
  end
end

# Module-level configuration
SeliseBlocks::LMT.configure do |config|
  config.service_id = 'my-service'
end
```

**Key Differences:**
- Ruby uses module-level configuration with block syntax
- Ruby adds explicit validation method
- Ruby follows snake_case naming convention

### 2. Logger Implementation

**C# (`BlocksLogger.cs`)**
```csharp
public class BlocksLogger : IBlocksLogger
{
    private readonly LmtOptions _options;
    private readonly ConcurrentQueue<LogData> _logBatch;
    private readonly Timer _flushTimer;
    private readonly LmtServiceBusSender _serviceBusSender;
    private readonly SemaphoreSlim _semaphore = new SemaphoreSlim(1, 1);
    
    public void Log(LmtLogLevel level, string messageTemplate, 
                    Exception exception = null, params object[] args) { }
}
```

**Ruby (`blocks_logger.rb`)**
```ruby
class BlocksLogger
  include Singleton
  
  def initialize
    @initialized = false
    @mutex = Mutex.new
  end
  
  def log(level, message_template, exception: nil, **args)
    init unless @initialized
    # ...
  end
end
```

**Key Differences:**
- Ruby uses Singleton pattern instead of dependency injection
- Ruby uses keyword arguments (`exception:`, `**args`) instead of params array
- Ruby has lazy initialization pattern
- Ruby uses `Mutex` instead of `SemaphoreSlim`

### 3. Service Bus Sender

**C# (`LmtServiceBusSender.cs`)**
```csharp
public class LmtServiceBusSender : IDisposable
{
    private ServiceBusClient? _serviceBusClient;
    private ServiceBusSender? _serviceBusSender;
    
    public async Task SendLogsAsync(List<LogData> logs, int retryCount = 0)
    {
        var message = new ServiceBusMessage(json)
        {
            ContentType = "application/json",
            MessageId = messageId
        };
        await _serviceBusSender.SendMessageAsync(message);
    }
}
```

**Ruby (`service_bus_sender.rb`)**
```ruby
class ServiceBusSender
  def initialize(service_name, connection_string, max_retries: 3, max_failed_batches: 100)
    @client = Azure::Messaging::ServiceBus::ServiceBusClient.new(connection_string)
    @sender = @client.create_sender(Constants.topic_name(service_name))
  end
  
  def send_logs(logs, retry_count = 0)
    message = Azure::Messaging::ServiceBus::ServiceBusMessage.new(json)
    message.message_id = message_id
    @sender.send_message(message)
  end
end
```

**Key Differences:**
- Ruby uses synchronous API (Azure SDK for Ruby doesn't use async/await)
- Ruby uses keyword arguments for optional parameters
- Ruby's method names follow snake_case convention
- Ruby uses `Thread.new` for background processing instead of `Task.Run`

### 4. Trace Processor

**C# (`LmtTraceProcessor.cs`)**
```csharp
public class LmtTraceProcessor : BaseProcessor<Activity>
{
    public override void OnEnd(Activity activity)
    {
        var traceData = new TraceData
        {
            TraceId = activity.TraceId.ToString(),
            SpanId = activity.SpanId.ToString(),
            Duration = activity.Duration.TotalMilliseconds
        };
        _traceBatch.Enqueue(traceData);
    }
}
```

**Ruby (`trace_processor.rb`)**
```ruby
class TraceProcessor < OpenTelemetry::SDK::Trace::SpanProcessor
  def on_finish(span)
    span_context = span.context
    duration = ((span.end_timestamp - span.start_timestamp) / 1_000_000.0).round(3)
    
    trace_data = TraceData.new
    trace_data.trace_id = span_context.hex_trace_id
    trace_data.span_id = span_context.hex_span_id
    trace_data.duration = duration
    
    @trace_batch << trace_data
  end
end
```

**Key Differences:**
- Ruby inherits from `SpanProcessor` instead of `BaseProcessor<Activity>`
- Ruby uses `on_finish` instead of `OnEnd`
- Ruby calculates duration from nanosecond timestamps
- Ruby's OpenTelemetry API has different method names

### 5. Data Models

**C# (`LogData.cs`)**
```csharp
public class LogData
{
    public DateTime Timestamp { get; set; }
    public string Level { get; set; } = string.Empty;
    public Dictionary<string, object> Properties { get; set; } = new();
}
```

**Ruby (`log_data.rb`)**
```ruby
class LogData
  attr_accessor :timestamp, :level, :properties
  
  def initialize
    @timestamp = Time.now.utc
    @level = ''
    @properties = {}
  end
  
  def to_h
    {
      timestamp: @timestamp.iso8601(3),
      level: @level,
      properties: @properties
    }
  end
end
```

**Key Differences:**
- Ruby adds explicit `to_h` method for serialization
- Ruby uses `attr_accessor` for getters/setters
- Ruby defaults to UTC time explicitly
- Ruby uses ISO8601 format for timestamp serialization

## Feature Parity Checklist

| Feature | C# | Ruby | Notes |
|---------|:--:|:----:|-------|
| **Logging** |
| Multiple log levels | ✅ | ✅ | Trace, Debug, Info, Warning, Error, Critical |
| Template formatting | ✅ | ✅ | Both support parameter substitution |
| Exception logging | ✅ | ✅ | Full stack traces captured |
| Batching | ✅ | ✅ | Configurable batch sizes |
| Auto-flush | ✅ | ✅ | Timer-based flushing |
| **Tracing** |
| OpenTelemetry integration | ✅ | ✅ | Standard span processor |
| Span attributes | ✅ | ✅ | Custom attributes supported |
| Nested spans | ✅ | ✅ | Parent-child relationships |
| Baggage propagation | ✅ | ✅ | Multi-tenant support |
| **Azure Service Bus** |
| Topic-based messaging | ✅ | ✅ | lmt-{service_id} topic |
| Subscription filtering | ✅ | ✅ | Separate logs/traces subscriptions |
| Message properties | ✅ | ✅ | Metadata in application properties |
| **Reliability** |
| Retry logic | ✅ | ✅ | Exponential backoff |
| Failed batch queue | ✅ | ✅ | Prevents data loss |
| Max retries | ✅ | ✅ | Configurable limit |
| **Configuration** |
| Batch sizes | ✅ | ✅ | Separate for logs and traces |
| Flush interval | ✅ | ✅ | Configurable in seconds |
| Enable/disable flags | ✅ | ✅ | Independent logging/tracing control |
| **Thread Safety** |
| Concurrent operations | ✅ | ✅ | Thread-safe collections |
| Synchronization | ✅ | ✅ | Mutex/Semaphore protection |
| **Resource Management** |
| Graceful shutdown | ✅ | ✅ | Flush on exit |
| Connection cleanup | ✅ | ✅ | Proper disposal |

## Key Design Decisions

### 1. Singleton vs Dependency Injection

**C#**: Uses dependency injection, logger injected via constructor
```csharp
public class MyService
{
    private readonly IBlocksLogger _logger;
    
    public MyService(IBlocksLogger logger)
    {
        _logger = logger;
    }
}
```

**Ruby**: Uses singleton pattern for simplicity
```ruby
class MyService
  def initialize
    @logger = SeliseBlocks::LMT::BlocksLogger.instance
  end
end
```

**Rationale**: Ruby's ecosystem commonly uses singletons for loggers. More idiomatic and simpler for Ruby developers.

### 2. Async vs Sync

**C#**: Heavily async/await based
```csharp
public async Task SendLogsAsync(List<LogData> logs)
{
    await _serviceBusSender.SendMessageAsync(message);
}
```

**Ruby**: Synchronous with background threads
```ruby
def send_logs(logs)
  Thread.new do
    @sender.send_message(message)
  end
end
```

**Rationale**: Ruby's Azure SDK doesn't use async/await pattern. Background threads provide similar non-blocking behavior.

### 3. Configuration Style

**C#**: Via `appsettings.json` and DI
```csharp
services.AddLmtClient(builder.Configuration);
```

**Ruby**: Via block configuration
```ruby
SeliseBlocks::LMT::Client.configure do |config|
  config.service_id = 'my-service'
end
```

**Rationale**: Block-style configuration is more idiomatic in Ruby (similar to Rails, RSpec, etc.).

### 4. Naming Conventions

**C#**: PascalCase
- `ServiceId`
- `ConnectionString`
- `LogBatchSize`

**Ruby**: snake_case
- `service_id`
- `connection_string`
- `log_batch_size`

**Rationale**: Following language-specific conventions for better integration with existing codebases.

## Performance Considerations

### C# Advantages
- Native async/await for better I/O performance
- `ConcurrentQueue<T>` highly optimized
- Better integration with .NET thread pool

### Ruby Advantages
- Simpler concurrency model for maintenance
- `concurrent-ruby` gem provides battle-tested primitives
- Less memory overhead for small to medium loads

### Performance Recommendations

**C#**: Better for high-throughput scenarios (>10,000 logs/second)

**Ruby**: Suitable for most web applications (<10,000 logs/second)

Both implementations support:
- Batching to reduce network calls
- Background processing to avoid blocking
- Retry logic with exponential backoff
- Failed batch queue for reliability

## Testing Approach

### C# Testing
```csharp
[Fact]
public void Logger_Should_LogMessage()
{
    var options = new LmtOptions { /* config */ };
    var logger = new BlocksLogger(options);
    
    logger.LogInformation("Test");
    
    // Assertions
}
```

### Ruby Testing
```ruby
RSpec.describe SeliseBlocks::LMT::BlocksLogger do
  before do
    SeliseBlocks::LMT::Client.configure do |config|
      # test config
    end
  end
  
  it 'logs message' do
    logger = described_class.instance
    logger.info('Test')
    
    # expectations
  end
end
```

## Migration Guide

For teams migrating from C# to Ruby:

1. **Logger Instantiation**
   - C#: `IBlocksLogger` via DI
   - Ruby: `BlocksLogger.instance`

2. **Method Names**
   - C#: `LogInformation()` → Ruby: `info()`
   - C#: `LogError()` → Ruby: `error()`

3. **Configuration**
   - C#: `appsettings.json` → Ruby: `configure` block
   - C#: `AddLmtClient()` → Ruby: `SeliseBlocks::LMT::Client.configure`

4. **Tracing**
   - C#: `AddLmtTracing()` → Ruby: `add_span_processor(TraceProcessor.new)`
   - C#: `ActivitySource` → Ruby: `OpenTelemetry.tracer_provider.tracer()`

## Conclusion

The Ruby implementation successfully replicates all core functionality of the C# version while maintaining Ruby idioms and best practices. Both implementations are production-ready and offer the same features for logging and distributed tracing with Azure Service Bus integration.

