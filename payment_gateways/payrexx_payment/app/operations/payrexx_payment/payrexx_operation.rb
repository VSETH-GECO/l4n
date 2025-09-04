require 'httparty'
require 'openssl'
require 'base64'

module PayrexxPayment
  class PayrexxOperation < RailsOps::Operation
    include ::HTTParty

    without_authorization

    PAYREXX_INSTANCE = 'vseth'.freeze

    def perform
      # Can't execute this operations, inheriting operations
      # need to implement this themselves
      fail NotImplementedError
    end

    private

    def api_key
      Figaro.env.payrexx_api_key!
    end

    def payrexx_instance
      Rails.env.development? ? 'vseth' : PAYREXX_INSTANCE
    end

    def api_base_url
      'https://api.payrexx.com/v1.0'
    end

    def gateway_url
      "#{api_base_url}/Gateway/?instance=#{payrexx_instance}"
    end

    def common_headers
      {
        'accept'    => 'application/json',
        'X-API-KEY' => api_key
      }
    end

    def handle_api_response(response)
      unless response.success?
        Rails.logger.error "Payrexx API Error: #{response.code} - #{response.message}"
        fail "API request failed: #{response.code} - #{response.message}"
      end

      parsed_response = response.parsed_response

      if parsed_response['status'] != 'success'
        error_message = parsed_response['message'] || 'Unknown error'
        Rails.logger.error "Payrexx API Error: #{error_message}"
        fail "API error: #{error_message}"
      end

      parsed_response
    end
  end
end
