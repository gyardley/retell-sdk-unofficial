require 'httparty'
require 'json'

require_relative 'api/agent'
require_relative 'api/call'
require_relative 'api/retell_llm'
require_relative 'api/phone_number'
require_relative 'api/voice'
require_relative 'api/concurrency'
require_relative 'api/webhook'

module Retell
  module SDK
    module Unofficial
      class Client
        DEFAULT_BASE_URL = 'https://api.retellai.com'.freeze
        DEFAULT_TIMEOUT = 60

        def initialize(api_key:, base_url: nil, timeout: DEFAULT_TIMEOUT)
          @api_key = api_key
          @base_url = base_url || DEFAULT_BASE_URL
          @timeout = timeout
        end

        def agent
          @agent ||= Retell::SDK::Unofficial::API::Agent.new(self)
        end

        def call
          @call ||= Retell::SDK::Unofficial::API::Call.new(self)
        end

        def retell_llm
          @retell_llm ||= Retell::SDK::Unofficial::API::RetellLLM.new(self)
        end

        def phone_number
          @phone_number ||= Retell::SDK::Unofficial::API::PhoneNumber.new(self)
        end

        def voice
          @voice ||= Retell::SDK::Unofficial::API::Voice.new(self)
        end

        def concurrency
          @concurrency ||= Retell::SDK::Unofficial::API::Concurrency.new(self)
        end

        def webhook
          @webhook ||= Retell::SDK::Unofficial::API::Webhook.new(self)
        end

        def agents
          agent.list
        end

        def calls(**params)
          call.list(**params)
        end

        def retell_llms
          retell_llm.list
        end

        def phone_numbers
          phone_number.list
        end

        def voices
          voice.list
        end

        def request(method, path, params = {}, **options)
          url = "#{@base_url}#{path}"

          http_options = {
            headers: headers.merge(options[:headers] || {}),
            format: :json,
            timeout: options[:timeout] || @timeout
          }

          body_params = options[:body] || {}

          if [:get, :delete].include?(method)
            options[:query] = options[:query].merge(params)
          else
            options[:body] = options[:body].merge(params)
          end

          http_options[:query] = options[:query] unless options[:query].empty?

          if [:post, :patch].include?(method)
            http_options[:body] = options[:body].to_json
          elsif !body_params.empty?
            http_options[:body] = body_params.to_json
          end

          begin
            response = HTTParty.send(
              method,
              url,
              http_options
            )
          rescue Net::OpenTimeout, Net::ReadTimeout, Timeout::Error, Errno::ETIMEDOUT => e
            raise APITimeoutError.new(http_options)
          end

          handle_response(response)
        end

        def get(path, params = {}, **options)
          request(:get, path, params, **options)
        end

        def post(path, params = {}, **options)
          request(:post, path, params, **options)
        end

        def patch(path, params = {}, **options)
          request(:patch, path, params, **options)
        end

        def delete(path, params = {}, **options)
          request(:delete, path, params, **options)
          nil
        end

        def make_request_options(extra_headers: nil, extra_query: nil, extra_body: nil, timeout: nil)
          options = {}
          options[:headers] = extra_headers || {}
          options[:query] = extra_query || {}
          options[:body] = extra_body || {}
          options[:timeout] = timeout if timeout
          options
        end

        private

        def headers
          {
            'Authorization' => "Bearer #{@api_key}",
            'Content-Type' => 'application/json',
            'Accept' => 'application/json'
          }
        end

        def handle_response(response)
          case response.code
          when 204
            return nil
          when 200..299
            parse_response(response)
          when 400..499
            raise Retell::SDK::Unofficial::Error.new(response.code, "Client error: #{response.body}")
          when 500..599
            raise Retell::SDK::Unofficial::Error.new(response.code, "Server error: #{response.body}")
          else
            raise Retell::SDK::Unofficial::Error.new(response.code, "Unknown error: #{response.body}")
          end
        end

        def parse_response(response)
          data = response.parsed_response
          if data.is_a?(Array)
            parse_array_response(data)
          elsif data.is_a?(Hash)
            parse_single_response(data)
          else
            raise Retell::SDK::Unofficial::Error, "Unexpected data format: #{data.class}"
          end
        end

        def parse_array_response(data)
          type_key = data.first&.keys&.find { |key|
            key.end_with?('_id') || key == 'phone_number'
          }&.gsub('_id', '')

          return unknown_response_error('array') unless type_key

          list_class = "Retell::SDK::Unofficial::#{process_type_key(type_key)}List"
          item_class = "Retell::SDK::Unofficial::#{process_type_key(type_key)}"

          items = data.map { |item_data| constantize_item_class(item_class).new(
            self,
            **process_data(item_data, type_key)
          )}
          raw_response = { "#{type_key}s".to_sym => items }

          constantize_list_class(list_class).new(**raw_response)
        end

        def parse_single_response(data)
          type_key = data.keys.find { |key|
            key.end_with?('_id') || key == 'phone_number' || key == 'concurrency_limit'
          }&.gsub('_id', '')

          return unknown_response_error('single object') unless type_key

          response_class = "Retell::SDK::Unofficial::#{process_type_key(type_key)}"
          processed_data = process_data(data, type_key)

          constantize_item_class(response_class).new(self, **processed_data)
        end

        # yes, same as constantize_list_class - to circumvent type checking issues
        def constantize_item_class(class_name)
          class_name.split('::').inject(Object) { |mod, class_name| mod.const_get(class_name) }
        end

        # yes, same as constantize_item_class - Ruby type checking isn't where it should be
        def constantize_list_class(class_name)
          class_name.split('::').inject(Object) { |mod, class_name| mod.const_get(class_name) }
        end

        def process_type_key(type_key)
          case type_key
          when 'llm'
            'RetellLLM'
          when 'concurrency_limit'
            'Concurrency'
          when 'phone_number'
            'PhoneNumber'
          else
            type_key.capitalize
          end
        end

        def process_data(data, type_key)
          case data
          when Hash
            data.map do |key, value|
              processed_value = process_data(value, type_key)
              [
                key.to_sym,
                convert_to_float(processed_value, type_key, key.to_sym)
              ]
            end.to_h
          when Array
            data.map { |item| process_data(item, type_key) }
          else
            data
          end
        end

        def convert_to_float(value, type_key, field_name)
          if value.is_a?(Integer) && float_fields(type_key).include?(field_name)
            value.to_f
          else
            value
          end
        end

        def float_fields(type_key)
          case type_key
          when 'agent'
            [:ambient_sound_volume, :backchannel_frequency, :interruption_sensitivity, :responsiveness, :voice_speed, :voice_temperature, :volume]
          when 'llm'
            [:model_temperature]
          else
            []
          end
        end

        def unknown_response_error(type)
          raise Retell::SDK::Unofficial::Error, "Unknown response type for #{type} data"
        end
      end

      class Error < StandardError
        attr_reader :code, :message

        def initialize(code, message)
          @code = code
          @message = message
          super("#{code}: #{message}")
        end
      end


      class APITimeoutError < Error
        attr_reader :request

        def initialize(request)
          @request = request
          super(500, "API request timed out")
        end
      end
    end
  end
end
