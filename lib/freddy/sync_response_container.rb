require 'thread'
require 'timeout'

class Freddy
  class SyncResponseContainer
    def initialize
      @mutex = Mutex.new
    end

    def call(response, delivery)
      @response = response
      @delivery = delivery
      @mutex.synchronize { @waiting.wakeup }
    end

    def wait_for_response(timeout)
      @mutex.synchronize do
        @waiting = Thread.current
        @mutex.sleep(timeout)
      end

      if !defined?(@response)
        raise Timeout::Error, 'execution expired'
      elsif @response.nil?
        raise StandardError, 'unexpected nil value for response'
      elsif @response[:error] == 'RequestTimeout'
        raise TimeoutError.new(@response)
      elsif !@delivery || @delivery.type == 'error'
        raise InvalidRequestError.new(@response)
      else
        @response
      end
    end

    private

    def to_proc
      Proc.new {|*args| self.call(*args)}
    end
  end
end
