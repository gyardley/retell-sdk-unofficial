require 'openssl'
require 'time'

FIVE_MINUTES = 5 * 60 * 1000 # milliseconds

module Retell
  module SDK
    module Unofficial
      module API
        class Webhook
          def initialize(client)
            @client = client
          end

          def verify(body, api_key, signature)
            symmetric_verify(body, api_key, signature)
          end

          def sanitize(body, secret, signature)
            raise "Signature mismatch" unless verify(body, secret, signature)
            json = JSON.parse(body)
            deep_to_ostruct(json) # httparty returns an openstruct, so match it
          end

          private
          def symmetric_sign(input, secret, timestamp = (Time.now.to_f * 1000).to_i)
            digest = OpenSSL::HMAC.hexdigest('SHA256', secret, "#{input}#{timestamp}")
            "v=#{timestamp},d=#{digest}"
          end

          def symmetric_verify(input, secret, signature, opts = {})
            match = signature.match(/^v=(\d+),d=(.+)$/)
            return false unless match

            poststamp = match[1].to_i
            post_digest = match[2]
            timestamp = opts[:timestamp] || (Time.now.to_f * 1000).to_i
            timeout = opts[:timeout] || FIVE_MINUTES

            difference = (timestamp - poststamp).abs
            return false if difference > timeout

            expected_digest = OpenSSL::HMAC.hexdigest('SHA256', secret, "#{input}#{poststamp}")
            expected_digest == post_digest
          end

          # Helper method to deeply convert a hash to OpenStruct
          def deep_to_ostruct(obj)
            case obj
            when Hash
              OpenStruct.new(obj.transform_values { |v| deep_to_ostruct(v) })
            when Array
              obj.map { |v| deep_to_ostruct(v) }
            else
              obj
            end
          end
        end
      end
    end
  end
end
