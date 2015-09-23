require 'pry'
require 'securerandom'
require 'freddy'
require 'logger'

Thread.abort_on_exception = true

RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  config.filter_run :focus
  config.order = 'random'
end

class Freddy::Consumer
  def create_queue(queue_name, options={})
    #want to auto_delete queues while testing
    Freddy::AdaptiveQueue.new @channel.queue(queue_name, options.merge(auto_delete: true))
  end
end

def random_destination
  SecureRandom.hex
end

def default_sleep
  sleep 0.05
end

def wait_for(&block)
  100.times do
    return if block.call
    sleep 0.005
  end
end

def deliver(custom_destination = destination)
  freddy.deliver custom_destination, payload
  default_sleep
end

def logger
  Logger.new(STDOUT).tap { |l| l.level = Logger::ERROR }
end

def config
  {host: 'localhost', port: 5672, user: 'guest', pass: 'guest'}
end
