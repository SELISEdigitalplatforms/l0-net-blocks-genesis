# frozen_string_literal: true

module SeliseBlocks
  module LMT
    # Data structure for trace/span entries
    class TraceData
      attr_accessor :timestamp,
                    :trace_id,
                    :span_id,
                    :parent_span_id,
                    :parent_id,
                    :kind,
                    :activity_source_name,
                    :operation_name,
                    :start_time,
                    :end_time,
                    :duration,
                    :attributes,
                    :status,
                    :status_description,
                    :baggage,
                    :service_name,
                    :tenant_id

      def initialize
        @timestamp = Time.now.utc
        @trace_id = ''
        @span_id = ''
        @parent_span_id = ''
        @parent_id = ''
        @kind = ''
        @activity_source_name = ''
        @operation_name = ''
        @start_time = Time.now.utc
        @end_time = Time.now.utc
        @duration = 0.0
        @attributes = {}
        @status = ''
        @status_description = ''
        @baggage = {}
        @service_name = ''
        @tenant_id = ''
      end

      def to_h
        {
          timestamp: @timestamp.iso8601(3),
          trace_id: @trace_id,
          span_id: @span_id,
          parent_span_id: @parent_span_id,
          parent_id: @parent_id,
          kind: @kind,
          activity_source_name: @activity_source_name,
          operation_name: @operation_name,
          start_time: @start_time.iso8601(3),
          end_time: @end_time.iso8601(3),
          duration: @duration,
          attributes: @attributes,
          status: @status,
          status_description: @status_description,
          baggage: @baggage,
          service_name: @service_name,
          tenant_id: @tenant_id
        }
      end

      def to_json(*args)
        to_h.to_json(*args)
      end
    end

    # Failed batch tracking for traces
    class FailedTraceBatch
      attr_accessor :tenant_batches, :retry_count, :next_retry_time

      def initialize(tenant_batches: {}, retry_count: 0, next_retry_time: Time.now.utc)
        @tenant_batches = tenant_batches
        @retry_count = retry_count
        @next_retry_time = next_retry_time
      end
    end
  end
end

