# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-11-12

### Added
- Initial release of Selise Blocks LMT Client for Ruby
- BlocksLogger with singleton pattern for centralized logging
- Support for multiple log levels (Trace, Debug, Information, Warning, Error, Critical)
- Automatic batching of logs with configurable batch size
- Automatic batching of traces with configurable batch size
- Azure Service Bus integration for sending logs and traces
- Exponential backoff retry logic with configurable max retries
- Failed batch queue to prevent data loss during transient failures
- OpenTelemetry integration via TraceProcessor
- Thread-safe implementation using concurrent-ruby
- Automatic flush timers for both logs and traces
- Configuration via block DSL
- Multi-tenant support via x_blocks_key
- Comprehensive documentation and examples
- Example applications (basic usage, OpenTelemetry integration, Sinatra app)

### Features
- High-performance logging with minimal overhead
- Distributed tracing support via OpenTelemetry
- Graceful shutdown with flush on exit
- Template-based message formatting
- Exception tracking and formatting
- Trace context propagation (trace_id, span_id)
- Baggage propagation for multi-tenant scenarios

[1.0.0]: https://github.com/selise/blocks-lmt-client-ruby/releases/tag/v1.0.0

