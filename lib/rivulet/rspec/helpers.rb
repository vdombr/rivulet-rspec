require 'oj'
require 'rack'
require 'rack/multipart'

module Rivulet
  module RSpec
    module Helpers
      def get(url, params: {}, headers: {})
        env = Rack::MockRequest.env_for(
          url,
          method: 'GET',
          params: params,
          **env_headers(headers)
        )

        @response = Rack::MockResponse.new(*Rivulet.app.call(env))
      end

      %i[post put patch delete].each do |method_name|
        define_method(method_name) do |url, params: {}, headers: {}, content_type: 'application/json'|
          opts = {
            method: method_name,
            **env_headers(headers),
            **build_payload(params, content_type)
          }

          env = Rack::MockRequest.env_for(url, opts)

          @response = Rack::MockResponse.new(*Rivulet.app.call(env))
        end
      end

      def response
        @response
      end

      def json_response
        payload = Oj.strict_load(@response.body)

        unless payload.is_a?(Hash)
          raise ArgumentError, "expected a JSON object in the response body, got #{payload.class}"
        end

        payload.deep_symbolize_keys
      end

      private

      def env_headers(headers)
        headers.to_h do |key, value|
          ["HTTP_#{key.to_s.upcase.tr('-', '_')}", value]
        end
      end

      def build_payload(params, content_type)
        case content_type
        when 'application/x-www-form-urlencoded'
          { params: params }
        when 'multipart/form-data'
          unless multipart_upload?(params)
            raise ArgumentError,
              "multipart/form-data requires Rack::Multipart::UploadedFile values in params, got plain params"
          end

          { params: params }
        when 'application/json', 'text/json'
          { input: Oj.dump(params, mode: :strict), 'CONTENT_TYPE' => content_type }
        else
          if params.is_a?(Hash)
            raise ArgumentError,
              "cannot encode Hash params with #{content_type}; pass a String or IO body"
          end

          { input: params, 'CONTENT_TYPE' => content_type }
        end
      end

      # Mirrors Rack::Multipart::Generator#multipart? without consuming the
      # upload IOs, so Rack can still build the multipart body itself.
      def multipart_upload?(value)
        case value
        when Array
          value.any? { |item| multipart_upload?(item) }
        when Hash
          value.values.any? { |item| multipart_upload?(item) }
        else
          value.is_a?(Rack::Multipart::UploadedFile)
        end
      end
    end
  end
end
