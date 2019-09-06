# frozen_string_literal: true

require 'http/tracer/version'
require 'opentracing'

module HTTP
  module Tracer
    class << self
      attr_accessor :ignore_request, :tracer

      IngoreRequest = ->(_verb, _uri, _opts) { false }

      def instrument(tracer: OpenTracing.global_tracer, ignore_request: IngoreRequest)
        begin
          require 'http'
        rescue LoadError
          return
        end
        raise IncompatibleGemVersion unless compatible_version?

        @ignore_request = ignore_request
        @tracer = tracer
        patch_request
      end

      def compatible_version?
        Gem::Version.new(HTTP::VERSION) >= Gem::Version.new("0.1.0")
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
            options = HTTP::Options.new.merge(opts)
            parsed_uri = uri.is_a?(String) ? URI(uri) : uri

            if ::HTTP::Tracer.ignore_request.call(verb, uri, options)
              res = request_original(verb, uri, options)
            else
              path, host, port = nil
              path = parsed_uri.path if parsed_uri.respond_to?(:path)
              host = parsed_uri.host if parsed_uri.respond_to?(:host)
              port = parsed_uri.port if parsed_uri.respond_to?(:port)

              tags = {
                'component' => 'ruby-httprb',
                'span.kind' => 'client',
                'http.method' => verb,
                'http.url' => path,
                'peer.host' => host,
                'peer.port' => port
              }

              tracer = ::HTTP::Tracer.tracer

              tracer.start_active_span('http.request', tags: tags) do |scope|
                OpenTracing.inject(scope.span.context, OpenTracing::FORMAT_RACK, options.headers)

                res = request_original(verb, uri, options)

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
