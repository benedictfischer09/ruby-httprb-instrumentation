# frozen_string_literal: true

require 'uri'

RSpec.describe HTTP::Instrumentation do
  Options = Struct.new(:headers)

  module HTTP
    class Client
      def request(_verb, _uri, _opts = {}); end
    end
  end

  context 'without instrumentation' do
    it 'does not add headers' do
      uri = URI('http://localhost:3000')
      opts = Options.new('x-test' => 'foobar')
      client = HTTP::Client.new

      allow(client).to receive(:request)

      client.request('GET', uri, opts)

      expect(client).to have_received(:request).with('GET', uri, opts)
    end
  end

  context 'with instrumentation' do
    after do
      HTTP::Instrumentation.remove
    end

    it 'starts a span for the request' do
      tracer = double(start_active_span: true)
      HTTP::Instrumentation.instrument(tracer: tracer)
      client = HTTP::Client.new

      client.request('GET', URI('http://localhost:3000'))

      expect(tracer).to have_received(:start_active_span)
    end

    it 'can be configured to skip creating a span for some requests' do
      tracer = double(start_active_span: true)
      HTTP::Instrumentation.instrument(
        tracer: tracer,
        ignore_request: ->(_, uri, _) { uri.host == 'localhost' }
      )
      client = HTTP::Client.new

      client.request('GET', URI('http://localhost:3000'))

      expect(tracer).not_to have_received(:start_active_span)

      client.request('GET', URI('http://myhost.com:3000'))

      expect(tracer).to have_received(:start_active_span)
    end

    it 'follows semantic conventions for the span tags' do
      tracer = double(start_active_span: true)
      HTTP::Instrumentation.instrument(tracer: tracer)
      client = HTTP::Client.new

      client.request('POST', URI('http://localhost/api/data'))

      expect(tracer).to have_received(:start_active_span).with(
        'http.request',
        tags: {
          'component' => 'HTTP',
          'span.kind' => 'client',
          'http.method' => 'POST',
          'http.url' => '/api/data',
          'peer.host' => 'localhost',
          'peer.port' => 80
        }
      )
    end

    it 'tags the span as an error when the response is an error' do
      error = StandardError.new('500 error')
      allow(error).to receive(:status).and_return(500)

      span = double(set_tag: true, context: nil)
      scope = double(span: span)
      tracer = double(start_active_span: true)
      allow(tracer).to receive(:start_active_span).and_yield(scope)

      HTTP::Instrumentation.instrument(tracer: tracer)
      client = HTTP::Client.new
      allow(client).to receive(:request_original).and_return(error)

      client.request('GET', URI('http://localhost:3000'), Options.new)

      expect(span).to have_received(:set_tag).with('http.status_code', 500)
      expect(span).to have_received(:set_tag).with('error', true)
    end
  end
end
