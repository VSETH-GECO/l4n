require 'httparty'
require 'openssl'

module PayrexxPayment
  class PayrexxOperation < RailsOps::Operation
    without_authorization

    PAYREXX_INSTANCE = 'vseth'.freeze

    # Payrexx gateway statuses are waiting, confirmed, authorized and reserved.
    # `authorized` and `reserved` only occur with preAuthorization / reservation,
    # where the money still has to be captured manually, so only `confirmed`
    # means the order has actually been paid.
    SUCCESSFUL_STATUS = 'confirmed'.freeze

    # A transaction is `waiting` while it has been started but is neither paid nor
    # aborted yet (e.g. a TWINT payment that hasn't been approved in the app yet).
    # It can still become `confirmed`, even quite some time later.
    WAITING_STATUS = 'waiting'.freeze

    # Errors that mean Payrexx could not be reached
    NETWORK_ERRORS = [
      HTTParty::Error, SocketError, Timeout::Error, SystemCallError, OpenSSL::SSL::SSLError, EOFError
    ].freeze

    REQUEST_TIMEOUT = 15 # seconds

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
      PAYREXX_INSTANCE
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

    def transactions_endpoint
      "#{api_base_url}/Transaction/"
    end

    def cancel_transaction_endpoint(transaction_id)
      "#{api_base_url}/Transaction/#{transaction_id}/cancel?instance=#{payrexx_instance}"
    end

    def common_headers
      {
        'accept'    => 'application/json',
        'X-API-KEY' => api_key
      }
    end

    # Sends a request to the Payrexx API. Fails with ExecutionFailed if Payrexx
    # can't be reached, such that callers only need to handle one kind of error.
    def request(method, url, **)
      HTTParty.public_send(method, url, timeout: REQUEST_TIMEOUT, **)
    rescue *NETWORK_ERRORS => e
      Rails.logger.error "Payrexx API request failed: #{method.upcase} #{url}: #{e.class}: #{e.message}"
      fail PayrexxPayment::ExecutionFailed, _('PayrexxPaymentGateway|Could not reach the payment provider, please try again')
    end

    # Returns the data of the gateway with the given id, or nil if Payrexx
    # does not know the gateway (anymore). Fails on any other error.
    def fetch_gateway(gateway_id)
      response = request(:get, gateway_endpoint(gateway_id), headers: common_headers)

      return nil if response.not_found?

      fail PayrexxPayment::ExecutionFailed, _('PayrexxPaymentGateway|Could not verify payment status') unless response.success?

      parsed_response = response.parsed_response

      fail PayrexxPayment::ExecutionFailed, _('PayrexxPaymentGateway|Could not verify payment status') unless valid_gateway_response?(parsed_response)

      parsed_response['data'].first
    end

    # Deletes the gateway with the given id, such that it can't be paid anymore.
    # A gateway that does not exist (anymore) counts as deleted.
    def delete_gateway(gateway_id)
      response = request(:delete, gateway_endpoint(gateway_id), headers: common_headers)

      return if response.success? || response.not_found?

      fail PayrexxPayment::ExecutionFailed, "Could not delete Payrexx gateway #{gateway_id}: #{response.code}"
    end

    # Returns all transactions (payment attempts) for the given order, across all
    # gateways that have been created for it.
    def fetch_transactions(order)
      response = request(
        :get,
        transactions_endpoint,
        query:   { instance: payrexx_instance, filterReference: order.uuid, limit: 100 },
        headers: common_headers
      )

      return [] if response.not_found?

      parsed_response = response.parsed_response

      fail PayrexxPayment::ExecutionFailed, _('PayrexxPaymentGateway|Could not verify payment status') unless response.success? && parsed_response.is_a?(Hash) && parsed_response['status'] == 'success' && parsed_response['data'].is_a?(Array)

      # `filterReference` also matches the purpose, only keep the order's own transactions
      parsed_response['data'].select { |transaction| transaction['referenceId'].to_s == order.uuid }
    end

    # Cancels the given transaction, which Payrexx only does while it is still
    # `waiting`. Returns false if it isn't `waiting` (anymore), e.g. because it
    # has been paid in the meantime.
    def cancel_transaction(transaction_id)
      response = request(:patch, cancel_transaction_endpoint(transaction_id), headers: common_headers)

      return true if response.success?
      return false if response.not_found?

      fail PayrexxPayment::ExecutionFailed, "Could not cancel Payrexx transaction #{transaction_id}: #{response.code}"
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
  end
end
