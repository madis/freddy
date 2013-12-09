require 'messaging_spec_helper'

module Messaging
  describe Freddy do 

    default_let
    let(:destination2) { random_destination }
    let(:test_response) { {custom: 'response'}}
    let(:freddy) { Freddy.new }

     def default_deliver_with_response(&block)
      freddy.deliver_with_response destination, payload do |response|
        @received_response = response
        block.call response if block
      end
      default_sleep
    end

    def default_respond_to(&block)
      @responder = freddy.respond_to destination do |request_payload|
        @message_received = true
        @received_payload = request_payload
        block.call request_payload if block
      end
    end


    def default_deliver_with_ack(&block)
      freddy.deliver_with_ack destination, payload do |error|
        @ack_error = error
        block.call error if block
      end
      default_sleep
    end

    describe "when producing with response" do 

      it 'sends the request to responder' do 
        default_respond_to
        default_deliver_with_response
        expect(@message_received).to be_true
      end

      it 'sends the payload in request to the responder' do 
        default_respond_to do end
        payload = {a: 'ari'}
        freddy.deliver_with_response destination, payload do end
        default_sleep

        expect(@received_payload).to eq Messaging.symbolize_keys(payload)
      end

      it 'sends the response to requester' do 
        freddy.respond_to destination do |message, msg_handler|
          msg_handler.ack test_response
        end
        default_deliver_with_response
        expect(@received_response).to eq(Messaging.symbolize_keys(test_response))
      end

      it 'responds to the correct requester' do
        freddy.respond_to destination do end

        freddy.deliver_with_response destination, payload do 
          @dest_response_received = true
        end

        freddy.deliver_with_response destination2, payload do 
          @dest2_response_received = true
        end
        default_sleep

        expect(@dest_response_received).to be_true
        expect(@dest2_response_received).to be_nil
      end

      it 'times out when no response comes' do 
        freddy.deliver_with_response destination, payload, 0.1 do |response|
          @error = response[:error]
        end
        sleep 0.25
        expect(@error).not_to be_nil
      end

      it 'responds with error if the message was nacked' do 
        freddy.respond_to destination do |message, msg_handler|
          msg_handler.nack
        end
        freddy.deliver_with_response destination, payload do |response|
          @error = response[:error]
        end
        default_sleep

        expect(@error).not_to be_nil
      end

    end

    describe 'when producing with ack' do 
      it "reports error if message wasn't acknowledged" do 
        freddy.respond_to destination do end
        default_deliver_with_ack
        expect(@ack_error).not_to be_nil
      end

      it 'returns error if there are no responder' do 
        default_deliver_with_ack

        expect(@ack_error).not_to be_nil
      end

      it "reports error if messages was nacked" do 
        freddy.respond_to destination do |message, msg_handler|
          msg_handler.nack "bad message"
        end
        default_deliver_with_ack
        expect(@ack_error).not_to be_nil
      end

      it "doesn't report error if message was acked" do 
        freddy.respond_to destination do |message, msg_handler|
          msg_handler.ack
        end
        default_deliver_with_ack
        expect(@ack_error).to be_nil
      end

      it "reports error if message timed out" do 
        freddy.deliver_with_ack destination, payload, 0.1 do |error|
          @error = error
        end
        sleep 0.25
        expect(@error).not_to be_nil
      end
    end

  end
end