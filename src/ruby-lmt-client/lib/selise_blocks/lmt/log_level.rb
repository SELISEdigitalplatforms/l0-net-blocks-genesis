# frozen_string_literal: true

module SeliseBlocks
  module LMT
    # Log levels matching the C# implementation
    module LogLevel
      TRACE = 0
      DEBUG = 1
      INFORMATION = 2
      WARNING = 3
      ERROR = 4
      CRITICAL = 5

      NAMES = {
        TRACE => 'Trace',
        DEBUG => 'Debug',
        INFORMATION => 'Information',
        WARNING => 'Warning',
        ERROR => 'Error',
        CRITICAL => 'Critical'
      }.freeze

      def self.name(level)
        NAMES[level] || 'Unknown'
      end
    end
  end
end

