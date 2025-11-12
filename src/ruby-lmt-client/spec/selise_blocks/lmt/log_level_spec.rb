# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SeliseBlocks::LMT::LogLevel do
  describe '.name' do
    it 'returns correct name for TRACE' do
      expect(described_class.name(described_class::TRACE)).to eq('Trace')
    end

    it 'returns correct name for DEBUG' do
      expect(described_class.name(described_class::DEBUG)).to eq('Debug')
    end

    it 'returns correct name for INFORMATION' do
      expect(described_class.name(described_class::INFORMATION)).to eq('Information')
    end

    it 'returns correct name for WARNING' do
      expect(described_class.name(described_class::WARNING)).to eq('Warning')
    end

    it 'returns correct name for ERROR' do
      expect(described_class.name(described_class::ERROR)).to eq('Error')
    end

    it 'returns correct name for CRITICAL' do
      expect(described_class.name(described_class::CRITICAL)).to eq('Critical')
    end

    it 'returns Unknown for invalid level' do
      expect(described_class.name(999)).to eq('Unknown')
    end
  end

  describe 'constants' do
    it 'defines correct numeric values' do
      expect(described_class::TRACE).to eq(0)
      expect(described_class::DEBUG).to eq(1)
      expect(described_class::INFORMATION).to eq(2)
      expect(described_class::WARNING).to eq(3)
      expect(described_class::ERROR).to eq(4)
      expect(described_class::CRITICAL).to eq(5)
    end
  end
end

