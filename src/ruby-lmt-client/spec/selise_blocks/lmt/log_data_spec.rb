# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SeliseBlocks::LMT::LogData do
  describe '#initialize' do
    it 'sets default values' do
      log_data = described_class.new

      expect(log_data.timestamp).to be_a(Time)
      expect(log_data.level).to eq('')
      expect(log_data.message).to eq('')
      expect(log_data.exception).to eq('')
      expect(log_data.service_name).to eq('')
      expect(log_data.properties).to eq({})
      expect(log_data.tenant_id).to eq('')
    end
  end

  describe '#to_h' do
    it 'converts to hash with all fields' do
      log_data = described_class.new
      log_data.level = 'Information'
      log_data.message = 'Test message'
      log_data.service_name = 'test-service'
      log_data.properties = { 'key' => 'value' }
      log_data.tenant_id = 'tenant-123'

      hash = log_data.to_h

      expect(hash[:level]).to eq('Information')
      expect(hash[:message]).to eq('Test message')
      expect(hash[:service_name]).to eq('test-service')
      expect(hash[:properties]).to eq({ 'key' => 'value' })
      expect(hash[:tenant_id]).to eq('tenant-123')
      expect(hash[:timestamp]).to be_a(String)
    end
  end
end

RSpec.describe SeliseBlocks::LMT::FailedLogBatch do
  describe '#initialize' do
    it 'sets default values' do
      batch = described_class.new

      expect(batch.logs).to eq([])
      expect(batch.retry_count).to eq(0)
      expect(batch.next_retry_time).to be_a(Time)
    end

    it 'accepts custom values' do
      logs = [SeliseBlocks::LMT::LogData.new]
      next_time = Time.now.utc + 60

      batch = described_class.new(logs: logs, retry_count: 2, next_retry_time: next_time)

      expect(batch.logs).to eq(logs)
      expect(batch.retry_count).to eq(2)
      expect(batch.next_retry_time).to eq(next_time)
    end
  end
end

