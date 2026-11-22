module PayrexxPayment
  class ExecutePayment < PayrexxOperation
    schema3 do
      str! :order_id
    end

    # Payrexx gateway statuses are waiting, confirmed, authorized and reserved.
    # `authorized` and `reserved` only occur with preAuthorization / reservation,
    # where the money still has to be captured manually, so only `confirmed`
    # means the order has actually been paid.
    SUCCESSFUL_STATUS = 'confirmed'.freeze

    def perform # rubocop:disable Naming/PredicateMethod
      order = ::Order.find_by(uuid: osparams.order_id)

      fail PayrexxPayment::ExecutionFailed, _('Checkout|The given order was not found') if order.nil?

      # The success URL can be hit multiple times (reload, back button), an order
      # that is already paid must not be processed again.
      return true if order.paid?

      fail PayrexxPayment::ExecutionFailed, _('PayrexxPaymentGateway|Could not verify payment status') if order.payment_gateway_payment_id.blank?

      # Verify the payment status with Payrexx. This is done outside of the lock
      # below, as we don't want to hold a row lock during an HTTP request.
      gateway = fetch_gateway(order.payment_gateway_payment_id)

      fail PayrexxPayment::ExecutionFailed, _('PayrexxPaymentGateway|Payment was not successful') unless payment_successful?(gateway, order)

      # Lock the order (this also reloads it) and check again, such that concurrent
      # requests can't both mark the order as paid.
      order.with_lock do
        unless order.paid?
          run_sub Operations::PaymentGateway::SubmitPaymentResult, {
            gateway_name: 'Payrexx Payment',
            payment_id:   order.payment_gateway_payment_id,
            order_id:     order.uuid
          }
        end
      end

      true
    end

    private

    # Returns the data of the gateway with the given id, or fails if Payrexx
    # did not return a successful response.
    def fetch_gateway(gateway_id)
      response = HTTParty.get(gateway_endpoint(gateway_id), headers: common_headers)

      fail PayrexxPayment::ExecutionFailed, _('PayrexxPaymentGateway|Could not verify payment status') unless response.success?

      parsed_response = response.parsed_response

      fail PayrexxPayment::ExecutionFailed, _('PayrexxPaymentGateway|Could not verify payment status') unless valid_gateway_response?(parsed_response)

      parsed_response['data'].first
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

  class ExecutionFailed < StandardError; end
end
