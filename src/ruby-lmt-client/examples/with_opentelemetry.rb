#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'selise_blocks/lmt/client'
require 'opentelemetry/sdk'

# Configure the LMT Client
SeliseBlocks::LMT::Client.configure do |config|
  config.service_id = ENV['SERVICE_ID'] || 'ruby-demo-service'
  config.connection_string = ENV['AZURE_SERVICEBUS_CONNECTION_STRING'] || 'your-connection-string'
  config.x_blocks_key = ENV['X_BLOCKS_KEY'] || 'your-x-blocks-key'
  config.trace_batch_size = 10 # Smaller batch for demo
  config.flush_interval_seconds = 2 # Faster flush for demo
end

# Setup OpenTelemetry with LMT Trace Processor
OpenTelemetry::SDK.configure do |c|
  c.service_name = 'ruby-demo-service'
  
  # Add LMT Trace Processor
  c.add_span_processor(SeliseBlocks::LMT::TraceProcessor.new)
end

# Get logger and tracer
logger = SeliseBlocks::LMT::BlocksLogger.instance
tracer = OpenTelemetry.tracer_provider.tracer('ruby-demo-service')

# Create a span and log within it
tracer.in_span('process_order') do |span|
  span.set_attribute('order.id', '12345')
  span.set_attribute('order.amount', 99.99)
  span.set_attribute('user.id', 'user-789')
  
  logger.info('Processing order %s', order_id: '12345')
  
  # Simulate some work
  sleep(0.1)
  
  # Nested span
  tracer.in_span('validate_payment') do |child_span|
    child_span.set_attribute('payment.method', 'credit_card')
    logger.debug('Validating payment method')
    sleep(0.05)
  end
  
  tracer.in_span('update_inventory') do |child_span|
    child_span.set_attribute('inventory.updated', true)
    logger.debug('Updating inventory')
    sleep(0.05)
  end
  
  logger.info('Order processed successfully')
end

# Another operation with error
tracer.in_span('process_refund') do |span|
  span.set_attribute('refund.id', 'ref-456')
  
  begin
    logger.info('Processing refund %s', refund_id: 'ref-456')
    raise StandardError, 'Refund processing failed'
  rescue StandardError => e
    span.status = OpenTelemetry::Trace::Status.error(e.message)
    logger.error('Refund processing failed', exception: e)
  end
end

# Give it time to flush
puts 'Traces and logs sent! Waiting for flush...'
sleep(3)

# Shutdown gracefully
logger.shutdown
OpenTelemetry.tracer_provider.shutdown
puts 'Complete shutdown'

