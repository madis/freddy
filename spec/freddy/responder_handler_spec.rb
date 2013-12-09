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
      default_deliver
      consumer_handler.cancel
      default_deliver

      expect(@messages_count).to eq 1
    end

  end
end
