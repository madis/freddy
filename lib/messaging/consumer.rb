require 'messaging/responder_handler'
require 'messaging/message_handler'
require 'messaging/request'

module Messaging
  class Consumer

    class EmptyConsumer < Exception
    end

    def initialize(channel = Messaging.channel, logger=Messaging.logger)
      @channel, @logger = channel, logger
    end

    def consume(destination, &block)
      raise EmptyConsumer unless block
      consume_from_queue create_queue(destination), &block
    end

    def consume_from_queue(queue, &block)
      consumer = queue.subscribe do |delivery_info, properties, payload|
        @logger.debug "Received message on #{queue.name}"
        block.call (parse_payload payload), MessageHandler.new(delivery_info, properties)
      end
      @logger.debug "Consuming messages on #{queue.name}"
      ResponderHandler.new consumer
    end

    private

    def parse_payload(payload)
      if payload == 'null'
        {}
      else
        Messaging.symbolize_keys(JSON(payload))
      end
    end

    def create_queue(destination)
      @channel.queue(destination)
    end

  end
end