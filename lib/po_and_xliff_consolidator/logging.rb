require 'logger'

class SkipLogDevice

  attr_accessor :messages_to_skip
  attr_reader :messages

  def initialize
    @messages_to_skip = []
    @messages = []
  end

  def skip(messages)
    @messages_to_skip += messages
    @messages_to_skip.uniq!
  end

  def write(message)
    m = message.strip
    return if @messages_to_skip.include? m
    @messages << m
    puts message
  end

  def close

  end


end

class SkipLogger < Logger
  def messages
    @logdev.dev.messages
  end

  def skip(messages)
    @logdev.dev.skip(messages)
  end
end


module Logging
  class << self
    def logger
      @logger ||= SkipLogger.new(SkipLogDevice.new)
    end

    def logger=(logger)
      @logger = logger
    end
  end

  # Addition
  def self.included(base)
    class << base
      def logger
        Logging.logger
      end
    end
  end

  def logger
    Logging.logger
  end
end