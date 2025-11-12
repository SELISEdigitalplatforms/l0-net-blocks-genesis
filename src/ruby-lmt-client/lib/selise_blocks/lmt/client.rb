# frozen_string_literal: true

require_relative 'version'
require_relative 'configuration'
require_relative 'log_level'
require_relative 'log_data'
require_relative 'trace_data'
require_relative 'service_bus_sender'
require_relative 'blocks_logger'
require_relative 'trace_processor'

module SeliseBlocks
  module LMT
    class Error < StandardError; end

    class << self
      # Convenience method to get the logger instance
      def logger
        BlocksLogger.instance
      end
    end
  end
end

