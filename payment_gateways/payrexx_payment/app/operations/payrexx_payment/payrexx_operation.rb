require 'httparty'
require 'openssl'
require 'base64'

module PayrexxPayment
  class PayrexxOperation < RailsOps::Operation
    include ::HTTParty

    without_authorization

    PAYREXX_INSTANCE = 'vseth'.freeze

    # Payrexx gateway statuses are waiting, confirmed, authorized and reserved.
    # `authorized` and `reserved` only occur with preAuthorization / reservation,
    # where the money still has to be captured manually, so only `confirmed`
    # means the order has actually been paid.
    SUCCESSFUL_STATUS = 'confirmed'.freeze

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
      'https://api.payrexx.com/v1.19'
    end

    def gateways_endpoint
      "#{api_base_url}/Gateway/?instance=#{payrexx_instance}"
    end

    def gateway_endpoint(gateway_id)
      "#{api_base_url}/Gateway/#{gateway_id}/?instance=#{payrexx_instance}"
    end

    def common_headers
      {
        'accept'    => 'application/json',
        'X-API-KEY' => api_key
      }
    end

    # Returns the data of the gateway with the given id, or nil if Payrexx
    # does not know the gateway (anymore). Fails on any other error.
    def fetch_gateway(gateway_id)
      response = HTTParty.get(gateway_endpoint(gateway_id), headers: common_headers)

      return nil if response.not_found?

      fail PayrexxPayment::ExecutionFailed, _('PayrexxPaymentGateway|Could not verify payment status') unless response.success?

      parsed_response = response.parsed_response

      fail PayrexxPayment::ExecutionFailed, _('PayrexxPaymentGateway|Could not verify payment status') unless valid_gateway_response?(parsed_response)

      parsed_response['data'].first
    end

    # Deletes the gateway with the given id, such that it can't be paid anymore.
    # A gateway that does not exist (anymore) counts as deleted.
    def delete_gateway(gateway_id)
      response = HTTParty.delete(gateway_endpoint(gateway_id), headers: common_headers)

      return if response.success? || response.not_found?

      fail PayrexxPayment::ExecutionFailed, "Could not delete Payrexx gateway #{gateway_id}: #{response.code}"
    end

    def valid_gateway_response?(parsed_response)
      parsed_response.is_a?(Hash) &&
        parsed_response['status'] == 'success' &&
        parsed_response['data'].is_a?(Array) &&
        parsed_response['data'].any?
    end

    # Checks that the gateway has been paid, and that it actually belongs
    # to the given order and charged the correct amount.
    def payment_successful?(gateway, order)
      total = order.total

      gateway['status'] == SUCCESSFUL_STATUS &&
        gateway['referenceId'].to_s == order.uuid &&
        gateway['amount'].to_i == total.cents &&
        gateway['currency'].to_s.casecmp?(total.currency.iso_code)
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
