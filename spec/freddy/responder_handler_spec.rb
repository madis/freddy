require 'messaging_spec_helper'
require 'messaging/responder_handler'

module Messaging
  describe ResponderHandler do

    default_let

    it 'can cancel listening for messages' do 
      consumer_handler = freddy.respond_to destination do
        @messages_count ||= 0
        @messages_count += 1
      end
      deliver
      consumer_handler.cancel
      deliver

      expect(@messages_count).to eq 1
    end

    it 'can join the thread to the consumer' do 
      consumer_handler = freddy.respond_to destination do 
      end
      unreachable = true
      Thread.new do 
        consumer_handler.join
        unreachable = false
      end
      wait_for { unreachable }
      expect(unreachable).to be_true
    end

  end
end
