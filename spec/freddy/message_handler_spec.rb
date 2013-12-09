require 'messaging_spec_helper'

module Messaging
  describe MessageHandler do

    default_let

    def default_consume(&block)
      freddy.respond_to destination do |payload, msg_handler|
        @msg_handler = msg_handler
        block.call payload, msg_handler if block
      end
    end

    def produce_with_ack
      freddy.deliver_with_ack destination, payload do end
      default_sleep
    end

    it 'has properties about message' do 
      properties = nil
      default_consume do |payload, msg_handler|
        properties = msg_handler.properties
      end
      default_deliver
      expect(properties).not_to be_nil
    end

    it 'can ack message' do 
      default_consume do |payload, msg_handler|
        msg_handler.ack
      end
      produce_with_ack
      expect(@msg_handler.error).to be_nil
    end

    it 'can nack message' do 
      default_consume do |payload, msg_handler|
        msg_handler.nack "bad message"
      end
      produce_with_ack
      expect(@msg_handler.error).not_to be_nil
    end

    it 'can ack with response' do 
      default_consume do |payload, msg_handler|
        msg_handler.ack(ack: 'smack')
      end
      produce_with_ack

      expect(@msg_handler.error).to be_nil
      expect(@msg_handler.response).not_to be_nil
    end

  end
end