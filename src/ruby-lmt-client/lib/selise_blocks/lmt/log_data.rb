# frozen_string_literal: true

module SeliseBlocks
  module LMT
    # Data structure for log entries
    class LogData
      attr_accessor :timestamp,
                    :level,
                    :message,
                    :exception,
                    :service_name,
                    :properties,
                    :tenant_id

      def initialize
        @timestamp = Time.now.utc
        @level = ''
        @message = ''
        @exception = ''
        @service_name = ''
        @properties = {}
        @tenant_id = ''
      end

      def to_h
        {
          timestamp: @timestamp.iso8601(3),
          level: @level,
          message: @message,
          exception: @exception,
          service_name: @service_name,
          properties: @properties,
          tenant_id: @tenant_id
        }
      end

      def to_json(*args)
        to_h.to_json(*args)
      end
    end

    # Failed batch tracking for logs
    class FailedLogBatch
      attr_accessor :logs, :retry_count, :next_retry_time

      def initialize(logs: [], retry_count: 0, next_retry_time: Time.now.utc)
        @logs = logs
        @retry_count = retry_count
        @next_retry_time = next_retry_time
      end
    end
  end
end

