# frozen_string_literal: true

require 'json'
require 'securerandom'
require 'azure/messaging/service_bus'
require 'concurrent'

module SeliseBlocks
  module LMT
    # Handles sending logs and traces to Azure Service Bus with retry logic
    class ServiceBusSender
      def initialize(service_name, connection_string, max_retries: 3, max_failed_batches: 100)
        @service_name = service_name
        @max_retries = max_retries
        @max_failed_batches = max_failed_batches
        @failed_log_batches = Concurrent::Array.new
        @failed_trace_batches = Concurrent::Array.new
        @retry_mutex = Mutex.new
        @disposed = false

        # Initialize Azure Service Bus client
        if connection_string && !connection_string.empty?
          @client = Azure::Messaging::ServiceBus::ServiceBusClient.new(connection_string)
          @sender = @client.create_sender(Constants.topic_name(service_name))
        end

        # Start retry timer (runs every 30 seconds)
        @retry_timer = Concurrent::TimerTask.new(execution_interval: 30) do
          retry_failed_batches
        end
        @retry_timer.execute
      end

      def send_logs(logs, retry_count = 0)
        return unless @sender

        current_retry = 0

        while current_retry <= @max_retries
          begin
            payload = {
              type: 'logs',
              service_name: @service_name,
              data: logs.map(&:to_h)
            }

            json = JSON.generate(payload)
            timestamp = Time.now.utc
            message_id = "logs_#{@service_name}_#{timestamp.strftime('%Y%m%d%H%M%S%L')}_#{SecureRandom.hex(16)}"

            message = Azure::Messaging::ServiceBus::ServiceBusMessage.new(json)
            message.message_id = message_id
            message.correlation_id = Constants::LOG_SUBSCRIPTION
            message.content_type = 'application/json'
            message.application_properties = {
              'serviceName' => @service_name,
              'timestamp' => timestamp.iso8601,
              'source' => 'LogsSender',
              'type' => 'logs'
            }

            @sender.send_message(message)
            return
          rescue StandardError => e
            puts "Exception sending logs to Service Bus: #{e.message}, Retry: #{current_retry}/#{@max_retries}"
          end

          current_retry += 1

          if current_retry <= @max_retries
            delay = 2**(current_retry - 1)
            sleep(delay)
          end
        end

        # Queue for later retry
        if @failed_log_batches.size < @max_failed_batches
          failed_batch = FailedLogBatch.new(
            logs: logs,
            retry_count: retry_count + 1,
            next_retry_time: Time.now.utc + (2**retry_count) * 60
          )

          @failed_log_batches << failed_batch
          puts "Queued log batch for later retry. Failed batches in queue: #{@failed_log_batches.size}"
        else
          puts "Failed log batch queue is full (#{@max_failed_batches}). Dropping batch."
        end
      end

      def send_traces(tenant_batches, retry_count = 0)
        return unless @sender

        current_retry = 0

        while current_retry <= @max_retries
          begin
            # Convert tenant_batches hash to serializable format
            data = {}
            tenant_batches.each do |tenant_id, traces|
              data[tenant_id] = traces.map(&:to_h)
            end

            payload = {
              type: 'traces',
              service_name: @service_name,
              data: data
            }

            json = JSON.generate(payload)
            timestamp = Time.now.utc
            message_id = "traces_#{@service_name}_#{timestamp.strftime('%Y%m%d%H%M%S%L')}_#{SecureRandom.hex(16)}"

            message = Azure::Messaging::ServiceBus::ServiceBusMessage.new(json)
            message.message_id = message_id
            message.correlation_id = Constants::TRACE_SUBSCRIPTION
            message.content_type = 'application/json'
            message.application_properties = {
              'serviceName' => @service_name,
              'timestamp' => timestamp.iso8601,
              'source' => 'TracesSender',
              'type' => 'traces'
            }

            @sender.send_message(message)
            return
          rescue StandardError => e
            puts "Exception sending traces to Service Bus: #{e.message}, Retry: #{current_retry}/#{@max_retries}"
          end

          current_retry += 1

          if current_retry <= @max_retries
            delay = 2**(current_retry - 1)
            sleep(delay)
          end
        end

        # Queue for later retry
        if @failed_trace_batches.size < @max_failed_batches
          failed_batch = FailedTraceBatch.new(
            tenant_batches: tenant_batches,
            retry_count: retry_count + 1,
            next_retry_time: Time.now.utc + (2**retry_count) * 60
          )

          @failed_trace_batches << failed_batch
          puts "Queued trace batch for later retry. Failed batches in queue: #{@failed_trace_batches.size}"
        else
          puts "Failed trace batch queue is full (#{@max_failed_batches}). Dropping batch."
        end
      end

      def close
        return if @disposed

        @retry_timer&.shutdown
        retry_failed_batches # Final attempt to send failed batches
        @sender&.close
        @client&.close
        @disposed = true
      end

      private

      def retry_failed_batches
        @retry_mutex.synchronize do
          now = Time.now.utc

          # Retry failed logs
          retry_failed_logs(now)

          # Retry failed traces
          retry_failed_traces(now)
        end
      end

      def retry_failed_logs(now)
        batches_to_retry = []
        batches_to_requeue = []

        @failed_log_batches.each do |batch|
          if batch.next_retry_time <= now
            batches_to_retry << batch
          else
            batches_to_requeue << batch
          end
        end

        @failed_log_batches.clear
        batches_to_requeue.each { |batch| @failed_log_batches << batch }

        batches_to_retry.each do |failed_batch|
          if failed_batch.retry_count >= @max_retries
            puts "Log batch exceeded max retries (#{@max_retries}). Dropping batch with #{failed_batch.logs.size} logs."
            next
          end

          puts "Retrying failed log batch (Attempt #{failed_batch.retry_count + 1}/#{@max_retries})"
          send_logs(failed_batch.logs, failed_batch.retry_count)
        end
      end

      def retry_failed_traces(now)
        batches_to_retry = []
        batches_to_requeue = []

        @failed_trace_batches.each do |batch|
          if batch.next_retry_time <= now
            batches_to_retry << batch
          else
            batches_to_requeue << batch
          end
        end

        @failed_trace_batches.clear
        batches_to_requeue.each { |batch| @failed_trace_batches << batch }

        batches_to_retry.each do |failed_batch|
          if failed_batch.retry_count >= @max_retries
            puts "Trace batch exceeded max retries (#{@max_retries}). Dropping batch."
            next
          end

          puts "Retrying failed trace batch (Attempt #{failed_batch.retry_count + 1}/#{@max_retries})"
          send_traces(failed_batch.tenant_batches, failed_batch.retry_count)
        end
      end
    end
  end
end

