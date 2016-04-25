require 'spec_helper'

describe Freddy::SyncResponseContainer do
  let(:container) { described_class.new }

  before do
    container.on_timeout {}
  end

  context 'when timeout' do
    subject { container.wait_for_response(0.01) }

    it 'raises timeout error' do
      expect { subject }.to raise_error do |error|
        expect(error).to be_a(Freddy::TimeoutError)
        expect(error.response).to eq(
          error: 'RequestTimeout',
          message: 'Timed out waiting for response'
        )
      end
    end
  end

  context 'when nil resonse' do
    let(:delivery) { {} }

    before do
      Thread.new do
        default_sleep
        container.call(nil, delivery)
      end
    end

    it 'raises timeout error' do
      expect {
        container.wait_for_response(2)
      }.to raise_error(StandardError, 'unexpected nil value for response')
    end
  end

  describe '#wait_for_response' do
    let(:timeout) { 2 }
    let(:response) { {msg: 'response'} }
    let(:delivery) { OpenStruct.new(type: 'success') }

    context 'when called after #call' do
      let(:max_wait_time_in_seconds) { 0.5 }

      before do
        container.call(response, delivery)
      end

      it 'returns response' do
        expect(container.wait_for_response(timeout)).to eq(response)
      end

      it 'does not wait for timeout' do
        expect {
          container.wait_for_response(timeout)
        }.to change(Time, :now).by_at_most(max_wait_time_in_seconds)
      end
    end
  end
end
