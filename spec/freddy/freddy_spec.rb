require 'spec_helper'

describe Freddy do
  default_let

  let(:destination2) { random_destination }
  let(:test_response) { {custom: 'response'}}
  let(:freddy) { Freddy.build(logger, config) }

  def deliver_with_response(&block)
    got_response = false
    freddy.deliver_with_response destination, payload do |response|
      got_response = true
      @received_response = response
      block.call response if block
    end
    wait_for { got_response }
  end

  def respond_to(&block)
    @responder = freddy.respond_to destination do |request_payload, msg_handler|
      @message_received = true
      @received_payload = request_payload
      block.call request_payload, msg_handler if block
    end
  end

  context 'when making a synchronized request' do
    it 'returns response as soon as possible' do
      respond_to { |payload, msg_handler| msg_handler.ack(res: 'yey') }
      response = freddy.deliver_with_response(destination, {a: 'b'})

      expect(response).to eq(res: 'yey')
    end

    it 'does not leak consumers' do
      respond_to { |payload, msg_handler| msg_handler.ack(res: 'yey') }

      old_count = freddy.channel.consumers.keys.count

      response1 = freddy.deliver_with_response(destination, {a: 'b'})
      response2 = freddy.deliver_with_response(destination, {a: 'b'})

      expect(response1).to eq(res: 'yey')
      expect(response2).to eq(res: 'yey')

      new_count = freddy.channel.consumers.keys.count
      expect(new_count).to be(old_count + 1)
    end

    context 'when queue does not exist' do
      it 'gives timeout error immediately' do
        begin
          Timeout::timeout(0.5) do
            response = freddy.deliver_with_response(destination, {a: 'b'}, timeout: 3)
            expect(response).to eq(error: 'Timed out waiting for response')
          end
        rescue Timeout::Error
          fail('Received a long timeout instead of the immediate one')
        end
      end
    end

    context 'on timeout' do
      it 'gives timeout error' do
        respond_to { |payload, msg_handler| msg_handler.ack(res: 'yey') }
        response = freddy.deliver_with_response('invalid', {a: 'b'}, timeout: 0.1)

        expect(response).to eq(error: 'Timed out waiting for response')
      end

      context 'with delete_on_timeout is set to true' do
        it 'removes the message from the queue' do
          # Assume that there already is a queue. Otherwise will get an early
          # return.
          freddy.channel.queue(destination)

          response = freddy.deliver_with_response(destination, {}, timeout: 0.1)

          processed_after_timeout = false
          respond_to { processed_after_timeout = true }

          default_sleep

          expect(response).to eq(error: 'Timed out waiting for response')
          expect(processed_after_timeout).to be(false)
        end
      end

      context 'with delete_on_timeout is set to false' do
        it 'removes the message from the queue' do
          # Assume that there already is a queue. Otherwise will get an early
          # return.
          freddy.channel.queue(destination)

          response = freddy.deliver_with_response(destination, {}, timeout: 0.1, delete_on_timeout: false)

          processed_after_timeout = false
          respond_to { processed_after_timeout = true }

          default_sleep

          expect(response).to eq(error: 'Timed out waiting for response')
          expect(processed_after_timeout).to be(true)
        end
      end
    end
  end

  describe "when producing with response" do

    it 'sends the request to responder' do
      respond_to
      deliver_with_response
      expect(@message_received).to be(true)
    end

    it 'sends the payload in request to the responder' do
      respond_to { }
      payload = {a: {b: 'c'}}
      freddy.deliver_with_response destination, payload do end
      wait_for { @message_received }

      expect(@received_payload).to eq Symbolizer.symbolize(payload)
    end

    it 'sends the response to requester' do
      freddy.respond_to destination do |message, msg_handler|
        msg_handler.ack test_response
      end
      deliver_with_response
      expect(@received_response).to eq(Symbolizer.symbolize(test_response))
    end

    it 'responds to the correct requester' do
      freddy.respond_to(destination) { }

      responses = []
      responses << freddy.deliver_with_response(destination, payload)
      responses << freddy.deliver_with_response(destination2, payload)

      expect(responses).to eql([
        {},
        {error: 'Timed out waiting for response'}
      ])
    end

    it 'times out when no response comes' do
      freddy.deliver_with_response destination, payload, timeout: 0.1 do |response|
        @error = response[:error]
      end
      wait_for { @error }
      expect(@error).not_to be_nil
    end

    it 'responds with error if the message was nacked' do
      freddy.respond_to destination do |message, msg_handler|
        msg_handler.nack
      end
      freddy.deliver_with_response destination, payload do |response|
        @error = response[:error]
      end

      wait_for { @error }

      expect(@error).not_to be_nil
    end

  end

  describe 'when tapping' do

    def tap(custom_destination = destination, &callback)
      freddy.tap_into custom_destination do |message, origin|
        @tapped = true
        @tapped_message = message
        callback.call message, origin if callback
      end
    end

    it 'can tap' do
      tap
    end

    it 'receives messages' do
      tap
      deliver
      expect(@tapped_message).to eq(Symbolizer.symbolize payload)
    end

    it 'has the destination' do
      tap "somebody.*.love" do |message, destination|
        @destination = destination
      end
      deliver "somebody.to.love"
      expect(@destination).to eq("somebody.to.love")
    end

    it "doesn't consume the message" do
      tap
      respond_to
      deliver
      expect(@tapped).to be(true)
      expect(@message_received).to be(true)
    end

    it "allows * wildcard" do
      tap "somebody.*.love"
      deliver "somebody.to.love"
      expect(@tapped).to be(true)
    end

    it "* matches only one word" do
      tap "somebody.*.love"
      deliver "somebody.not.to.love"
      expect(@tapped).not_to be(true)
    end

    it "allows # wildcard" do
      tap "i.#.free"
      deliver "i.want.to.break.free"
      expect(@tapped).to be(true)
    end

  end
end
