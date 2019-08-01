# frozen_string_literal: true

require 'http/instrumentation/version'
require 'opentracing'

module HTTP
  module Instrumentation
    class << self
      attr_accessor :ignore_request, :tracer

      IngoreRequest = ->(_verb, _uri, _opts) { false }

      def instrument(tracer: OpenTracing.global_tracer, ignore_request: IngoreRequest)
        @ignore_request = ignore_request
        @tracer = tracer
        patch_request
      end

      def remove
        return unless ::HTTP::Client.method_defined?(:request_original)

        ::HTTP::Client.class_eval do
          remove_method :request
          alias_method :request, :request_original
          remove_method :request_original
        end
      end

      def patch_request
        ::HTTP::Client.class_eval do
          alias_method :request_original, :request

          def request(verb, uri, opts = {})
            if ::HTTP::Instrumentation.ignore_request.call(verb, uri, opts)
              res = request_original(verb, uri, opts)
            else
              tags = {
                'component' => 'HTTP',
                'span.kind' => 'client',
                'http.method' => verb,
                'http.url' => uri.path,
                'peer.host' => uri.host,
                'peer.port' => uri.port
              }

              tracer = ::HTTP::Instrumentation.tracer

              tracer.start_active_span('http.request', tags: tags) do |scope|
                OpenTracing.inject(scope.span.context, OpenTracing::FORMAT_RACK, opts.headers)

                res = request_original(verb, uri, opts)

                scope.span.set_tag('http.status_code', res.status)
                scope.span.set_tag('error', true) if res.is_a?(StandardError)
              end
            end

            res
          end
        end
      end
    end
  end
end
