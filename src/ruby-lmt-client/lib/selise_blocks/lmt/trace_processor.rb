# frozen_string_literal: true

require 'opentelemetry/sdk'
require 'concurrent'

module SeliseBlocks
  module LMT
    # OpenTelemetry Span Processor for Blocks LMT
    class TraceProcessor < OpenTelemetry::SDK::Trace::SpanProcessor
      def initialize(config = nil)
        super()
        @config = config || SeliseBlocks::LMT.configuration
        @config.validate!

        @trace_batch = Concurrent::Array.new
        @batch_mutex = Mutex.new

        @service_bus_sender = ServiceBusSender.new(
          @config.service_id,
          @config.connection_string,
          max_retries: @config.max_retries,
          max_failed_batches: @config.max_failed_batches
        )

        # Start flush timer
        @flush_timer = Concurrent::TimerTask.new(execution_interval: @config.flush_interval_seconds) do
          flush_batch
        end
        @flush_timer.execute
      end

      def on_start(span, parent_context)
        # Called when span starts - we don't need to do anything here
      end

      def on_finish(span)
        return unless @config.enable_tracing

        span_context = span.context
        end_time = span.end_timestamp
        start_time = span.start_timestamp
        duration = ((end_time - start_time) / 1_000_000.0).round(3) # Convert nanoseconds to milliseconds

        trace_data = TraceData.new
        trace_data.timestamp = Time.at(end_time / 1_000_000_000.0).utc
        trace_data.trace_id = span_context.hex_trace_id
        trace_data.span_id = span_context.hex_span_id
        trace_data.parent_span_id = span.parent_span_id&.unpack1('H*') || ''
        trace_data.parent_id = '' # Ruby OpenTelemetry doesn't have parent_id concept
        trace_data.kind = span.kind.to_s
        trace_data.activity_source_name = span.instrumentation_scope.name
        trace_data.operation_name = span.name
        trace_data.start_time = Time.at(start_time / 1_000_000_000.0).utc
        trace_data.end_time = Time.at(end_time / 1_000_000_000.0).utc
        trace_data.duration = duration
        trace_data.attributes = span.attributes&.to_h || {}
        trace_data.status = span.status.code.to_s
        trace_data.status_description = span.status.description || ''
        trace_data.baggage = get_baggage_items
        trace_data.service_name = @config.service_id
        trace_data.tenant_id = @config.x_blocks_key

        @trace_batch << trace_data

        # Flush if batch size reached
        flush_batch if @trace_batch.size >= @config.trace_batch_size
      end

      def force_flush(timeout: nil)
        flush_batch
        OpenTelemetry::SDK::Trace::Export::SUCCESS
      end

      def shutdown(timeout: nil)
        @flush_timer&.shutdown
        flush_batch # Final flush
        @service_bus_sender&.close
        OpenTelemetry::SDK::Trace::Export::SUCCESS
      end

      private

      def get_baggage_items
        baggage = {}
        OpenTelemetry::Baggage.values.each do |key, value|
          baggage[key] = value
        end
        baggage
      end

      def flush_batch
        @batch_mutex.synchronize do
          return if @trace_batch.empty?

          traces = @trace_batch.dup
          @trace_batch.clear

          # Group by tenant_id
          tenant_batches = Hash.new { |h, k| h[k] = [] }
          traces.each do |trace|
            tenant_batches[trace.tenant_id] << trace
          end

          # Send in background to avoid blocking
          Thread.new do
            @service_bus_sender.send_traces(tenant_batches)
          rescue StandardError => e
            puts "Error flushing traces: #{e.message}"
          end
        end
      end
    end
  end
end

