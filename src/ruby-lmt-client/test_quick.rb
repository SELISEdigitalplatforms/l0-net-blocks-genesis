#!/usr/bin/env ruby
# frozen_string_literal: true

# Quick test script to verify basic functionality
require_relative 'lib/selise_blocks/lmt/client'

puts '🧪 Quick Test: Ruby LMT Client'
puts '=' * 50

# Test 1: Configuration
puts "\n1️⃣  Testing Configuration..."
begin
  SeliseBlocks::LMT::Client.configure do |config|
    config.service_id = 'test-service'
    config.connection_string = 'mock-connection-string'
    config.x_blocks_key = 'mock-x-blocks-key'
    config.enable_logging = false # Don't actually send during quick test
    config.enable_tracing = false
  end
  puts '   ✅ Configuration successful'
rescue StandardError => e
  puts "   ❌ Configuration failed: #{e.message}"
  exit 1
end

# Test 2: Logger Instance
puts "\n2️⃣  Testing Logger Instance..."
begin
  logger = SeliseBlocks::LMT::BlocksLogger.instance
  puts '   ✅ Logger instance created'
rescue StandardError => e
  puts "   ❌ Logger creation failed: #{e.message}"
  exit 1
end

# Test 3: Log Levels
puts "\n3️⃣  Testing Log Levels..."
begin
  logger.trace('Trace message')
  logger.debug('Debug message')
  logger.info('Info message')
  logger.warn('Warning message')
  
  begin
    raise StandardError, 'Test error'
  rescue StandardError => e
    logger.error('Error message', exception: e)
    logger.critical('Critical message', exception: e)
  end
  
  puts '   ✅ All log levels working'
rescue StandardError => e
  puts "   ❌ Logging failed: #{e.message}"
  exit 1
end

# Test 4: Template Formatting
puts "\n4️⃣  Testing Template Formatting..."
begin
  logger.info('User %s logged in at %s', user_id: '12345', timestamp: Time.now)
  logger.debug('Order %s for amount %s', order_id: 'ORD-001', amount: 99.99)
  puts '   ✅ Template formatting working'
rescue StandardError => e
  puts "   ❌ Template formatting failed: #{e.message}"
  exit 1
end

# Test 5: Log Levels Constants
puts "\n5️⃣  Testing Log Level Constants..."
begin
  levels = [
    SeliseBlocks::LMT::LogLevel::TRACE,
    SeliseBlocks::LMT::LogLevel::DEBUG,
    SeliseBlocks::LMT::LogLevel::INFORMATION,
    SeliseBlocks::LMT::LogLevel::WARNING,
    SeliseBlocks::LMT::LogLevel::ERROR,
    SeliseBlocks::LMT::LogLevel::CRITICAL
  ]
  
  level_names = levels.map { |l| SeliseBlocks::LMT::LogLevel.name(l) }
  expected = %w[Trace Debug Information Warning Error Critical]
  
  if level_names == expected
    puts '   ✅ Log level constants correct'
  else
    puts "   ❌ Log level constants incorrect: #{level_names}"
    exit 1
  end
rescue StandardError => e
  puts "   ❌ Log level test failed: #{e.message}"
  exit 1
end

# Test 6: Configuration Access
puts "\n6️⃣  Testing Configuration Access..."
begin
  config = SeliseBlocks::LMT.configuration
  
  tests = [
    ['service_id', config.service_id, 'test-service'],
    ['connection_string', config.connection_string, 'mock-connection-string'],
    ['x_blocks_key', config.x_blocks_key, 'mock-x-blocks-key'],
    ['log_batch_size', config.log_batch_size, 100],
    ['enable_logging', config.enable_logging, false]
  ]
  
  all_correct = tests.all? { |name, actual, expected| actual == expected }
  
  if all_correct
    puts '   ✅ Configuration values correct'
  else
    puts '   ❌ Some configuration values incorrect'
    tests.each do |name, actual, expected|
      puts "      #{name}: expected #{expected}, got #{actual}" if actual != expected
    end
    exit 1
  end
rescue StandardError => e
  puts "   ❌ Configuration access failed: #{e.message}"
  exit 1
end

# Test 7: Data Models
puts "\n7️⃣  Testing Data Models..."
begin
  log_data = SeliseBlocks::LMT::LogData.new
  log_data.level = 'Information'
  log_data.message = 'Test message'
  log_data.service_name = 'test-service'
  
  hash = log_data.to_h
  
  if hash[:level] == 'Information' && hash[:message] == 'Test message'
    puts '   ✅ Data models working'
  else
    puts '   ❌ Data model conversion failed'
    exit 1
  end
rescue StandardError => e
  puts "   ❌ Data model test failed: #{e.message}"
  exit 1
end

# Summary
puts "\n" + '=' * 50
puts '✅ All quick tests passed!'
puts "\n📝 Next steps:"
puts '   1. Run full test suite: bundle exec rspec'
puts '   2. Run integration tests: ./run_tests.sh'
puts '   3. Try the examples in the examples/ directory'
puts "\n💡 To test with Azure Service Bus, set these env vars:"
puts '   export SERVICE_ID="your-service"'
puts '   export AZURE_SERVICEBUS_CONNECTION_STRING="your-connection"'
puts '   export X_BLOCKS_KEY="your-key"'
puts "\nThen run: ruby examples/basic_usage.rb"

