# frozen_string_literal: true

module SeliseBlocks
  module LMT
    class Configuration
      attr_accessor :service_id,
                    :connection_string,
                    :x_blocks_key,
                    :log_batch_size,
                    :trace_batch_size,
                    :flush_interval_seconds,
                    :max_retries,
                    :max_failed_batches,
                    :enable_logging,
                    :enable_tracing

      def initialize
        @service_id = ''
        @connection_string = ''
        @x_blocks_key = ''
        @log_batch_size = 100
        @trace_batch_size = 1000
        @flush_interval_seconds = 5
        @max_retries = 3
        @max_failed_batches = 100
        @enable_logging = true
        @enable_tracing = true
      end

      def validate!
        raise ArgumentError, 'service_id is required' if service_id.nil? || service_id.empty?
        raise ArgumentError, 'connection_string is required' if connection_string.nil? || connection_string.empty?
        raise ArgumentError, 'x_blocks_key is required' if x_blocks_key.nil? || x_blocks_key.empty?
      end
    end

    class << self
      attr_writer :configuration

      def configuration
        @configuration ||= Configuration.new
      end

      def configure
        yield(configuration)
        configuration.validate!
      end

      def reset_configuration!
        @configuration = Configuration.new
      end
    end

    # Constants
    module Constants
      LOG_SUBSCRIPTION = 'blocks-lmt-service-logs'
      TRACE_SUBSCRIPTION = 'blocks-lmt-service-traces'

      def self.topic_name(service_name)
        "lmt-#{service_name}"
      end
    end
  end
end

