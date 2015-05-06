require 'timeout'

class Freddy
  class SyncResponseContainer
    def call(response, _delivery)
      @response = response
    end

    def wait_for_response(timeout)
      Timeout::timeout(timeout) do
        sleep 0.001 until filled?
      end
      @response
    end

    private

    def to_proc
      Proc.new {|*args| self.call(*args)}
    end

    def filled?
      !@response.nil?
    end
  end
end
