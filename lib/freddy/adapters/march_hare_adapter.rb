require 'march_hare'

class Freddy
  module Adapters
    class MarchHareAdapter
      def self.connect(config)
        hare = MarchHare.connect(config)
        new(hare)
      end

      def initialize(hare)
        @hare = hare
      end

      def create_channel(prefetch: nil)
        hare_channel = @hare.create_channel
        hare_channel.basic_qos(prefetch) if prefetch
        Channel.new(hare_channel)
      end

      def close
        @hare.close
      end

      class Channel
        extend Forwardable

        NO_ROUTE = 312

        def initialize(channel)
          @channel = channel
        end

        def_delegators :@channel, :topic, :default_exchange, :consumers, :acknowledge

        def queue(*args)
          Queue.new(@channel.queue(*args))
        end

        def on_no_route(&block)
          @channel.on_return do |reply_code, _, exchange_name, _, properties|
            if exchange_name != Freddy::FREDDY_TOPIC_EXCHANGE_NAME && reply_code == NO_ROUTE
              block.call(properties.correlation_id)
            end
          end
        end
      end

      class Queue < Shared::Queue
        def subscribe(manual_ack: false, &block)
          @queue.subscribe(manual_ack: manual_ack) do |meta, payload|
            parsed_payload = Payload.parse(payload)
            delivery = Delivery.new(
              parsed_payload, meta, meta.routing_key, meta.delivery_tag
            )
            block.call(delivery)
          end
        end
      end
    end
  end
end
