# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SeliseBlocks::LMT::Configuration do
  describe '#initialize' do
    it 'sets default values' do
      config = described_class.new

      expect(config.service_id).to eq('')
      expect(config.connection_string).to eq('')
      expect(config.x_blocks_key).to eq('')
      expect(config.log_batch_size).to eq(100)
      expect(config.trace_batch_size).to eq(1000)
      expect(config.flush_interval_seconds).to eq(5)
      expect(config.max_retries).to eq(3)
      expect(config.max_failed_batches).to eq(100)
      expect(config.enable_logging).to eq(true)
      expect(config.enable_tracing).to eq(true)
    end
  end

  describe '#validate!' do
    it 'raises error when service_id is empty' do
      config = described_class.new
      config.connection_string = 'test-connection'
      config.x_blocks_key = 'test-key'

      expect { config.validate! }.to raise_error(ArgumentError, 'service_id is required')
    end

    it 'raises error when connection_string is empty' do
      config = described_class.new
      config.service_id = 'test-service'
      config.x_blocks_key = 'test-key'

      expect { config.validate! }.to raise_error(ArgumentError, 'connection_string is required')
    end

    it 'raises error when x_blocks_key is empty' do
      config = described_class.new
      config.service_id = 'test-service'
      config.connection_string = 'test-connection'

      expect { config.validate! }.to raise_error(ArgumentError, 'x_blocks_key is required')
    end

    it 'does not raise error when all required fields are set' do
      config = described_class.new
      config.service_id = 'test-service'
      config.connection_string = 'test-connection'
      config.x_blocks_key = 'test-key'

      expect { config.validate! }.not_to raise_error
    end
  end
end

RSpec.describe SeliseBlocks::LMT do
  describe '.configure' do
    it 'yields configuration object' do
      expect { |b| described_class.configure(&b) }.to yield_with_args(SeliseBlocks::LMT::Configuration)
    end

    it 'sets configuration values' do
      described_class.configure do |config|
        config.service_id = 'my-service'
        config.connection_string = 'my-connection'
        config.x_blocks_key = 'my-key'
        config.log_batch_size = 50
      end

      expect(described_class.configuration.service_id).to eq('my-service')
      expect(described_class.configuration.connection_string).to eq('my-connection')
      expect(described_class.configuration.x_blocks_key).to eq('my-key')
      expect(described_class.configuration.log_batch_size).to eq(50)
    end

    it 'validates configuration after block' do
      expect do
        described_class.configure do |config|
          config.service_id = '' # Invalid
        end
      end.to raise_error(ArgumentError)
    end
  end

  describe '.reset_configuration!' do
    it 'resets configuration to defaults' do
      described_class.configure do |config|
        config.service_id = 'test-service'
        config.connection_string = 'test-connection'
        config.x_blocks_key = 'test-key'
        config.log_batch_size = 999
      end

      described_class.reset_configuration!

      expect(described_class.configuration.service_id).to eq('')
      expect(described_class.configuration.log_batch_size).to eq(100)
    end
  end
end

RSpec.describe SeliseBlocks::LMT::Constants do
  describe '.topic_name' do
    it 'returns correctly formatted topic name' do
      expect(described_class.topic_name('my-service')).to eq('lmt-my-service')
    end
  end

  describe 'constants' do
    it 'defines LOG_SUBSCRIPTION' do
      expect(described_class::LOG_SUBSCRIPTION).to eq('blocks-lmt-service-logs')
    end

    it 'defines TRACE_SUBSCRIPTION' do
      expect(described_class::TRACE_SUBSCRIPTION).to eq('blocks-lmt-service-traces')
    end
  end
end

