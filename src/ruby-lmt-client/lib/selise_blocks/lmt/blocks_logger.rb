# frozen_string_literal: true

require 'singleton'
require 'concurrent'
require 'opentelemetry/api'

module SeliseBlocks
  module LMT
    # Main logger class for Blocks LMT Client
    class BlocksLogger
      include Singleton

      def initialize
        @initialized = false
        @mutex = Mutex.new
      end

      def init(config = nil)
        @mutex.synchronize do
          return if @initialized

          @config = config || SeliseBlocks::LMT.configuration
          @config.validate!

          @log_batch = Concurrent::Array.new
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

          @initialized = true
        end
      end

      def log(level, message_template, exception: nil, **args)
        init unless @initialized
        return unless @config.enable_logging

        span = OpenTelemetry::Trace.current_span
        properties = {}
        formatted_message = format_log_message(message_template, args, properties)

        log_data = LogData.new
        log_data.timestamp = Time.now.utc
        log_data.level = LogLevel.name(level)
        log_data.message = formatted_message
        log_data.exception = exception ? "#{exception.class}: #{exception.message}\n#{exception.backtrace&.join("\n")}" : ''
        log_data.service_name = @config.service_id
        log_data.properties = properties
        log_data.tenant_id = @config.x_blocks_key

        # Add trace context if available
        if span && span.context.valid?
          log_data.properties['trace_id'] = span.context.hex_trace_id
          log_data.properties['span_id'] = span.context.hex_span_id
        end

        @log_batch << log_data

        # Flush if batch size reached
        flush_batch if @log_batch.size >= @config.log_batch_size
      end

      def trace(message_template, **args)
        log(LogLevel::TRACE, message_template, **args)
      end

      def debug(message_template, **args)
        log(LogLevel::DEBUG, message_template, **args)
      end

      def info(message_template, **args)
        log(LogLevel::INFORMATION, message_template, **args)
      end

      def warn(message_template, **args)
        log(LogLevel::WARNING, message_template, **args)
      end

      def error(message_template, exception: nil, **args)
        log(LogLevel::ERROR, message_template, exception: exception, **args)
      end

      def critical(message_template, exception: nil, **args)
        log(LogLevel::CRITICAL, message_template, exception: exception, **args)
      end

      def flush
        flush_batch
      end

      def shutdown
        return unless @initialized

        @flush_timer&.shutdown
        flush_batch # Final flush
        @service_bus_sender&.close
        @initialized = false
      end

      private

      def format_log_message(message_template, args, properties)
        return message_template if args.empty?

        formatted = message_template.dup
        arg_values = args.values

        # Store all args in properties
        args.each_with_index do |(key, value), index|
          properties["arg#{index}"] = value
        end

        # Replace {placeholder} patterns with values
        index = 0
        formatted.gsub!(/\{[^}]*\}/) do |match|
          if index < arg_values.size
            value = arg_values[index]
            index += 1
            value.to_s
          else
            match
          end
        end

        formatted
      end

      def flush_batch
        @batch_mutex.synchronize do
          return if @log_batch.empty?

          logs = @log_batch.dup
          @log_batch.clear

          # Send in background to avoid blocking
          Thread.new do
            @service_bus_sender.send_logs(logs)
          rescue StandardError => e
            puts "Error flushing logs: #{e.message}"
          end
        end
      end
    end
  end
end

