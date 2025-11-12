# API Comparison: C# vs Ruby vs Node.js

This document provides side-by-side API comparisons for common operations across all three implementations of the Blocks LMT Client.

## Installation & Setup

### C# (.NET)

```csharp
// Install via NuGet
dotnet add package SeliseBlocks.LMT.Client

// In Program.cs
builder.Services.AddLmtClient(builder.Configuration);

// Configuration in appsettings.json
{
  "Lmt": {
    "ServiceId": "my-service",
    "ConnectionString": "...",
    "XBlocksKey": "..."
  }
}
```

### Ruby

```ruby
# Gemfile
gem 'selise_blocks-lmt-client'

# Installation
bundle install

# Configuration
require 'selise_blocks/lmt/client'

SeliseBlocks::LMT::Client.configure do |config|
  config.service_id = 'my-service'
  config.connection_string = '...'
  config.x_blocks_key = '...'
end
```

### Node.js (TypeScript)

```typescript
// package.json
npm install @selise/blocks-lmt-client

// Configuration
import { createLmtLogger } from '@selise/blocks-lmt-client';

const logger = createLmtLogger({
  serviceId: 'my-service',
  connectionString: '...',
  xBlocksKey: '...'
});
```

## Basic Logging

### C# (.NET)

```csharp
public class MyService
{
    private readonly IBlocksLogger _logger;
    
    public MyService(IBlocksLogger logger)
    {
        _logger = logger;
    }
    
    public void DoWork()
    {
        _logger.LogTrace("Trace message");
        _logger.LogDebug("Debug message");
        _logger.LogInformation("Info message");
        _logger.LogWarning("Warning message");
        _logger.LogError("Error message", exception);
        _logger.LogCritical("Critical message", exception);
    }
}
```

### Ruby

```ruby
class MyService
  def initialize
    @logger = SeliseBlocks::LMT::BlocksLogger.instance
  end
  
  def do_work
    @logger.trace('Trace message')
    @logger.debug('Debug message')
    @logger.info('Info message')
    @logger.warn('Warning message')
    @logger.error('Error message', exception: error)
    @logger.critical('Critical message', exception: error)
  end
end
```

### Node.js (TypeScript)

```typescript
class MyService {
  private logger: ILmtLogger;
  
  constructor(logger: ILmtLogger) {
    this.logger = logger;
  }
  
  doWork(): void {
    this.logger.trace('Trace message');
    this.logger.debug('Debug message');
    this.logger.info('Info message');
    this.logger.warn('Warning message');
    this.logger.error('Error message', exception);
    this.logger.critical('Critical message', exception);
  }
}
```

## Template Formatting

### C# (.NET)

```csharp
_logger.LogInformation("User {userId} logged in at {timestamp}", 
    "12345", DateTime.UtcNow);
```

### Ruby

```ruby
@logger.info('User %s logged in at %s', 
    user_id: '12345', timestamp: Time.now.utc)
```

### Node.js (TypeScript)

```typescript
logger.info('User {userId} logged in at {timestamp}', 
    '12345', new Date());
```

## OpenTelemetry Integration

### C# (.NET)

```csharp
// Setup
builder.Services.AddSingleton(new ActivitySource("my-service"));
builder.Services.AddOpenTelemetry()
    .WithTracing(tracerBuilder =>
    {
        tracerBuilder
            .AddSource("my-service")
            .AddLmtTracing(builder.Services.BuildServiceProvider()
                .GetRequiredService<LmtOptions>());
    });

// Usage
private readonly ActivitySource _activitySource;

using var activity = _activitySource.StartActivity("operation");
activity?.SetTag("key", "value");
// Do work
```

### Ruby

```ruby
# Setup
require 'opentelemetry/sdk'

OpenTelemetry::SDK.configure do |c|
  c.service_name = 'my-service'
  c.add_span_processor(SeliseBlocks::LMT::TraceProcessor.new)
end

# Usage
tracer = OpenTelemetry.tracer_provider.tracer('my-service')

tracer.in_span('operation') do |span|
  span.set_attribute('key', 'value')
  # Do work
end
```

### Node.js (TypeScript)

```typescript
// Setup
import { NodeTracerProvider } from '@opentelemetry/sdk-trace-node';
import { createLmtSpanProcessor } from '@selise/blocks-lmt-client';

const provider = new NodeTracerProvider();
provider.addSpanProcessor(createLmtSpanProcessor(options));
provider.register();

// Usage
import { trace } from '@opentelemetry/api';

const tracer = trace.getTracer('my-service');

const span = tracer.startSpan('operation');
span.setAttribute('key', 'value');
// Do work
span.end();
```

## Error Handling

### C# (.NET)

```csharp
try
{
    // Risky operation
}
catch (Exception ex)
{
    _logger.LogError("Operation failed: {message}", ex, ex.Message);
    throw;
}
```

### Ruby

```ruby
begin
  # Risky operation
rescue StandardError => e
  @logger.error('Operation failed: %s', message: e.message, exception: e)
  raise
end
```

### Node.js (TypeScript)

```typescript
try {
  // Risky operation
} catch (error) {
  logger.error(`Operation failed: ${error.message}`, error);
  throw error;
}
```

## Graceful Shutdown

### C# (.NET)

```csharp
// Automatic via IDisposable and DI container
// Manual if needed:
public void Dispose()
{
    _logger?.Dispose();
}
```

### Ruby

```ruby
# At application exit
at_exit do
  logger = SeliseBlocks::LMT::BlocksLogger.instance
  logger.shutdown
end

# Or manually
logger.shutdown
```

### Node.js (TypeScript)

```typescript
// At application shutdown
process.on('SIGTERM', async () => {
  await logger.flush();
  await logger.close();
  process.exit(0);
});

// Or manually
await logger.close();
```

## Configuration Options

### C# (.NET)

```csharp
{
  "Lmt": {
    "ServiceId": "my-service",
    "ConnectionString": "Endpoint=sb://...",
    "XBlocksKey": "key",
    "LogBatchSize": 100,
    "TraceBatchSize": 1000,
    "FlushIntervalSeconds": 5,
    "MaxRetries": 3,
    "MaxFailedBatches": 100,
    "EnableLogging": true,
    "EnableTracing": true
  }
}
```

### Ruby

```ruby
SeliseBlocks::LMT::Client.configure do |config|
  config.service_id = 'my-service'
  config.connection_string = 'Endpoint=sb://...'
  config.x_blocks_key = 'key'
  config.log_batch_size = 100
  config.trace_batch_size = 1000
  config.flush_interval_seconds = 5
  config.max_retries = 3
  config.max_failed_batches = 100
  config.enable_logging = true
  config.enable_tracing = true
end
```

### Node.js (TypeScript)

```typescript
const options: LmtOptions = {
  serviceId: 'my-service',
  connectionString: 'Endpoint=sb://...',
  xBlocksKey: 'key',
  logBatchSize: 100,
  traceBatchSize: 1000,
  flushIntervalSeconds: 5,
  maxRetries: 3,
  maxFailedBatches: 100,
  enableLogging: true,
  enableTracing: true
};
```

## Web Framework Integration

### C# (ASP.NET Core)

```csharp
// Program.cs
var builder = WebApplication.CreateBuilder(args);
builder.Services.AddLmtClient(builder.Configuration);

// Controller
[ApiController]
[Route("api/[controller]")]
public class UsersController : ControllerBase
{
    private readonly IBlocksLogger _logger;
    
    public UsersController(IBlocksLogger logger)
    {
        _logger = logger;
    }
    
    [HttpGet("{id}")]
    public IActionResult GetUser(string id)
    {
        _logger.LogInformation("Fetching user {userId}", id);
        // Implementation
    }
}
```

### Ruby (Sinatra)

```ruby
require 'sinatra'
require 'selise_blocks/lmt/client'

SeliseBlocks::LMT::Client.configure do |config|
  # configuration
end

logger = SeliseBlocks::LMT::BlocksLogger.instance

get '/api/users/:id' do
  user_id = params[:id]
  logger.info('Fetching user %s', user_id: user_id)
  # Implementation
end

at_exit do
  logger.shutdown
end
```

### Node.js (Express)

```typescript
import express from 'express';
import { createLmtLogger } from '@selise/blocks-lmt-client';

const app = express();
const logger = createLmtLogger(options);

app.get('/api/users/:id', (req, res) => {
  const userId = req.params.id;
  logger.info(`Fetching user ${userId}`);
  // Implementation
});

process.on('SIGTERM', async () => {
  await logger.close();
  process.exit(0);
});
```

## Testing

### C# (.NET)

```csharp
[Fact]
public void Should_Log_Message()
{
    var options = new LmtOptions 
    { 
        ServiceId = "test",
        ConnectionString = "test-conn",
        XBlocksKey = "test-key"
    };
    var logger = new BlocksLogger(options);
    
    logger.LogInformation("Test message");
    
    // Assertions
}
```

### Ruby

```ruby
RSpec.describe 'Logger' do
  before do
    SeliseBlocks::LMT::Client.configure do |config|
      config.service_id = 'test'
      config.connection_string = 'test-conn'
      config.x_blocks_key = 'test-key'
    end
  end
  
  it 'logs message' do
    logger = SeliseBlocks::LMT::BlocksLogger.instance
    logger.info('Test message')
    
    # expectations
  end
end
```

### Node.js (TypeScript)

```typescript
import { createLmtLogger } from '@selise/blocks-lmt-client';

describe('Logger', () => {
  it('should log message', () => {
    const logger = createLmtLogger({
      serviceId: 'test',
      connectionString: 'test-conn',
      xBlocksKey: 'test-key'
    });
    
    logger.info('Test message');
    
    // assertions
  });
});
```

## Key Differences Summary

| Aspect | C# | Ruby | Node.js |
|--------|:--:|:----:|:-------:|
| **Configuration** | appsettings.json | Block DSL | Object literal |
| **Logger Access** | DI Container | Singleton | Factory function |
| **Method Names** | PascalCase | snake_case | camelCase |
| **Async** | async/await | Threads | Promises/async |
| **Tracing** | ActivitySource | OpenTelemetry SDK | OpenTelemetry API |
| **Shutdown** | IDisposable | Explicit shutdown | async close |
| **Thread Safety** | ConcurrentQueue | Concurrent::Array | N/A (single-threaded) |

## Migration Tips

### From C# to Ruby

1. Replace DI with Singleton: `_logger` → `BlocksLogger.instance`
2. Change method names: `LogInformation` → `info`
3. Use keyword args: `exception: error` instead of positional
4. Add explicit shutdown: `at_exit { logger.shutdown }`

### From Node.js to Ruby

1. Replace factory with Singleton: `createLmtLogger(options)` → `BlocksLogger.instance`
2. Move config to setup: Options object → `configure` block
3. Change method style: `logger.info()` → `logger.info()`
4. Replace promises with threads (automatic in Ruby)

### From C# to Node.js

1. Replace DI with factory: `IBlocksLogger` → `createLmtLogger()`
2. Change to camelCase: `LogInformation` → `info`
3. Use async/await: `Dispose()` → `await close()`
4. Configure via object: appsettings.json → options object

## Best Practices (All Languages)

1. **Configure once** at application startup
2. **Use tracing** for distributed operations
3. **Flush on shutdown** to avoid data loss
4. **Batch appropriately** for your throughput
5. **Handle exceptions** in spans
6. **Add attributes** to spans for context
7. **Monitor failed batches** in production

## Common Patterns

### Request/Response Logging (All Languages)

**C#**
```csharp
_logger.LogInformation("Request: {method} {path}", method, path);
// Process
_logger.LogInformation("Response: {status}", statusCode);
```

**Ruby**
```ruby
@logger.info('Request: %s %s', method: method, path: path)
# Process
@logger.info('Response: %s', status: status_code)
```

**Node.js**
```typescript
logger.info(`Request: ${method} ${path}`);
// Process
logger.info(`Response: ${statusCode}`);
```

### Distributed Tracing (All Languages)

**C#**
```csharp
using var span = _activitySource.StartActivity("operation");
span?.SetTag("key", "value");
// Nested
using var child = _activitySource.StartActivity("child");
```

**Ruby**
```ruby
tracer.in_span('operation') do |span|
  span.set_attribute('key', 'value')
  # Nested
  tracer.in_span('child') do |child_span|
  end
end
```

**Node.js**
```typescript
const span = tracer.startSpan('operation');
span.setAttribute('key', 'value');
// Nested
const child = tracer.startSpan('child');
child.end();
span.end();
```

---

**Note**: All three implementations provide the same core features and reliability guarantees. Choose based on your application's language and framework requirements.

