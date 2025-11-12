#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'selise_blocks/lmt/client'

# Configure the LMT Client
SeliseBlocks::LMT::Client.configure do |config|
  config.service_id = ENV['SERVICE_ID'] || 'ruby-demo-service'
  config.connection_string = ENV['AZURE_SERVICEBUS_CONNECTION_STRING'] || 'your-connection-string'
  config.x_blocks_key = ENV['X_BLOCKS_KEY'] || 'your-x-blocks-key'
  config.log_batch_size = 10 # Smaller batch for demo
  config.flush_interval_seconds = 2 # Faster flush for demo
end

# Get logger instance
logger = SeliseBlocks::LMT::BlocksLogger.instance

# Log messages at different levels
logger.trace('This is a trace message')
logger.debug('This is a debug message')
logger.info('User %s logged in at %s', user_id: '12345', timestamp: Time.now)
logger.warn('This operation is taking longer than expected')

# Log with exception
begin
  raise StandardError, 'Something went wrong!'
rescue StandardError => e
  logger.error('An error occurred', exception: e)
end

# Log critical error
begin
  raise RuntimeError, 'Critical system failure'
rescue RuntimeError => e
  logger.critical('Critical error in payment system', exception: e)
end

# Give it time to flush
puts 'Logs sent! Waiting for flush...'
sleep(3)

# Shutdown gracefully
logger.shutdown
puts 'Logger shutdown complete'

