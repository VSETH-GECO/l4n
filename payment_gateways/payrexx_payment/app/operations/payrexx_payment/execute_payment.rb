module PayrexxPayment
  class ExecutePayment < PayrexxOperation
    schema3 do
      str! :order_id
    end

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

      fail PayrexxPayment::ExecutionFailed, _('PayrexxPaymentGateway|Could not verify payment status') if gateway.nil?
      fail PayrexxPayment::ExecutionFailed, _('PayrexxPaymentGateway|Payment was not successful') unless payment_successful?(gateway, order)

      # Lock the order (this also reloads it) and check again, such that concurrent
      # requests can't both mark the order as paid.
      order.with_lock do
        unless order.paid?
          run_sub Operations::PaymentGateway::SubmitPaymentResult, {
            gateway_name: PayrexxPayment::GATEWAY_NAME,
            payment_id:   order.payment_gateway_payment_id,
            order_id:     order.uuid
          }
        end
      end

      true
    end
  end
end
