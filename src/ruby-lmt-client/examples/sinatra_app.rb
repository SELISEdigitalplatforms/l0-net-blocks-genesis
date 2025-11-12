#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'sinatra'
require 'json'
require 'selise_blocks/lmt/client'
require 'opentelemetry/sdk'
require 'opentelemetry/instrumentation/sinatra'

# Configure the LMT Client
SeliseBlocks::LMT::Client.configure do |config|
  config.service_id = ENV['SERVICE_ID'] || 'ruby-sinatra-demo'
  config.connection_string = ENV['AZURE_SERVICEBUS_CONNECTION_STRING'] || 'your-connection-string'
  config.x_blocks_key = ENV['X_BLOCKS_KEY'] || 'your-x-blocks-key'
end

# Setup OpenTelemetry
OpenTelemetry::SDK.configure do |c|
  c.service_name = 'ruby-sinatra-demo'
  c.use 'OpenTelemetry::Instrumentation::Sinatra'
  c.add_span_processor(SeliseBlocks::LMT::TraceProcessor.new)
end

# Get logger and tracer
logger = SeliseBlocks::LMT::BlocksLogger.instance
tracer = OpenTelemetry.tracer_provider.tracer('ruby-sinatra-demo')

set :port, 4567
set :bind, '0.0.0.0'

# Middleware to add request context
use(Class.new do
  def initialize(app)
    @app = app
  end

  def call(env)
    request_id = SecureRandom.uuid
    env['REQUEST_ID'] = request_id
    @app.call(env)
  end
end)

# Routes
get '/' do
  logger.info('Root endpoint accessed')
  content_type :json
  { message: 'Welcome to Blocks LMT Demo API', status: 'ok' }.to_json
end

get '/api/users/:id' do
  user_id = params[:id]
  logger.info('Fetching user %s', user_id: user_id)
  
  tracer.in_span('fetch_user') do |span|
    span.set_attribute('user.id', user_id)
    
    begin
      # Simulate database query
      sleep(0.05)
      
      user = {
        id: user_id,
        name: "User #{user_id}",
        email: "user#{user_id}@example.com"
      }
      
      logger.debug('User found: %s', email: user[:email])
      content_type :json
      user.to_json
    rescue StandardError => e
      logger.error('Failed to fetch user', exception: e)
      status 500
      content_type :json
      { error: 'Internal server error' }.to_json
    end
  end
end

post '/api/orders' do
  request_body = JSON.parse(request.body.read)
  logger.info('Creating order', order_data: request_body)
  
  tracer.in_span('create_order') do |span|
    span.set_attribute('order.user_id', request_body['user_id'])
    span.set_attribute('order.amount', request_body['amount'])
    
    begin
      # Validate
      tracer.in_span('validate_order') do
        logger.debug('Validating order data')
        sleep(0.02)
        raise ArgumentError, 'Invalid amount' if request_body['amount'].to_f <= 0
      end
      
      # Process payment
      tracer.in_span('process_payment') do |payment_span|
        payment_span.set_attribute('payment.method', request_body['payment_method'])
        logger.info('Processing payment')
        sleep(0.05)
      end
      
      # Create order
      order_id = SecureRandom.uuid
      logger.info('Order created successfully', order_id: order_id)
      
      content_type :json
      status 201
      { order_id: order_id, status: 'created' }.to_json
    rescue ArgumentError => e
      logger.warn('Invalid order data: %s', error: e.message)
      status 400
      content_type :json
      { error: e.message }.to_json
    rescue StandardError => e
      logger.error('Failed to create order', exception: e)
      status 500
      content_type :json
      { error: 'Internal server error' }.to_json
    end
  end
end

get '/api/health' do
  logger.trace('Health check')
  content_type :json
  { status: 'healthy', timestamp: Time.now.iso8601 }.to_json
end

# Error handler
error do
  e = env['sinatra.error']
  logger.critical('Unhandled error', exception: e)
  content_type :json
  status 500
  { error: 'Internal server error' }.to_json
end

# Graceful shutdown
at_exit do
  logger.info('Shutting down application')
  logger.shutdown
  OpenTelemetry.tracer_provider.shutdown
  puts 'Application shutdown complete'
end

puts "Starting Sinatra app on port #{settings.port}"
puts 'Press Ctrl+C to stop'

