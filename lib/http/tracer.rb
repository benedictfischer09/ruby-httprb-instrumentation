# frozen_string_literal: true

require 'http/tracer/version'
require 'opentracing'

module HTTP
  module Tracer
    class << self
      attr_accessor :ignore_request, :tracer

      IngoreRequest = ->(_request, _options) { false }

      def instrument(tracer: OpenTracing.global_tracer, ignore_request: IngoreRequest)
        begin
          require 'http'
        rescue LoadError
          return
        end
        raise IncompatibleGemVersion unless compatible_version?

        @ignore_request = ignore_request
        @tracer = tracer
        patch_perform
      end

      def compatible_version?
        Gem::Version.new(HTTP::VERSION) >= Gem::Version.new("0.1.0")
      end

      def remove
        return unless ::HTTP::Client.method_defined?(:perform_without_tracing)

        ::HTTP::Client.class_eval do
          remove_method :perform
          alias_method :perform, :perform_without_tracing
          remove_method :perform_without_tracing
        end
      end

      def patch_perform
        ::HTTP::Client.class_eval do
          def perform_with_tracing(request, options)
puts ">>>> REQUEST: #{request.inspect}"
puts ">>>> OPTIONS: #{options.inspect}"

            # parsed_uri = uri.is_a?(String) ? URI(uri) : uri

            if ::HTTP::Tracer.ignore_request.call(request, options)
              res = perform_without_tracing(request, options)
            else
              # path, host, port = nil
              # path = parsed_uri.path if parsed_uri.respond_to?(:path)
              # host = parsed_uri.host if parsed_uri.respond_to?(:host)
              # port = parsed_uri.port if parsed_uri.respond_to?(:port)

              tags = {
                'component' => 'ruby-httprb',
                'span.kind' => 'client',
                'http.method' => request.verb.to_s.upcase,
                'http.url' => request.uri.path,
                'peer.host' => request.uri.host,
                'peer.port' => request.uri.port
              }

              tracer = ::HTTP::Tracer.tracer

              tracer.start_active_span('http.request', tags: tags) do |scope|
                OpenTracing.inject(scope.span.context, OpenTracing::FORMAT_RACK, options.headers)

                res = perform_without_tracing(request, options)

puts ">>>> RESPONSE: #{res.inspect}\n"

                scope.span.set_tag('http.status_code', res.status)
                scope.span.set_tag('error', true) if res.is_a?(StandardError)
              end
            end

            res
          end

          alias perform_without_tracing perform
          alias perform perform_with_tracing
        end
      end
    end
  end
end
