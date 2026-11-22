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
      return true if paid_through_payrexx?(order)

      fail PayrexxPayment::ExecutionFailed, _('PayrexxPaymentGateway|Could not verify payment status') if order.payment_gateway_payment_id.blank?

      # Verify the payment status with Payrexx. This is done outside of the lock
      # below, as we don't want to hold a row lock during an HTTP request.
      gateway = fetch_gateway(order.payment_gateway_payment_id)

      fail PayrexxPayment::ExecutionFailed, _('PayrexxPaymentGateway|Could not verify payment status') if gateway.nil?

      unless payment_successful?(gateway, order)
        # Payrexx can take a moment to confirm a payment (e.g. TWINT), during which
        # its transaction is still waiting, or confirmed while the gateway isn't yet.
        fail PayrexxPayment::PaymentPending, _('PayrexxPaymentGateway|Your payment is still being confirmed') if payment_in_progress?(order)

        fail PayrexxPayment::ExecutionFailed, _('PayrexxPaymentGateway|Payment was not successful')
      end

      mark_as_paid(order)

      true
    end

    private

    # Lock the order (this also reloads it) and check again, such that concurrent
    # requests can't both mark the order as paid.
    #
    # `requires_new` uses a savepoint, such that a failure rolls back everything
    # done here even if we're running inside an outer transaction (e.g. the order
    # cleanup) that catches the error and continues.
    def mark_as_paid(order)
      order.with_lock(requires_new: true) do
        next if paid_through_payrexx?(order)

        run_sub! Operations::PaymentGateway::SubmitPaymentResult, {
          gateway_name: PayrexxPayment::GATEWAY_NAME,
          payment_id:   order.payment_gateway_payment_id,
          order_id:     order.uuid
        }
      end
    rescue RailsOps::Exceptions::SubOpValidationFailed => e
      # The user has paid, but we couldn't mark the order as paid (e.g. a product's
      # inventory would become negative). This needs to be fixed manually.
      Rails.logger.error "Payrexx payment #{order.payment_gateway_payment_id} for order #{order.uuid} could not be processed: #{e.message}"
      Sentry.capture_exception(e)
      fail PayrexxPayment::ExecutionFailed, _('PayrexxPaymentGateway|Your payment was received, but the order could not be completed. Please contact us.')
    end

    def payment_in_progress?(order)
      fetch_transactions(order).any? { |transaction| [WAITING_STATUS, SUCCESSFUL_STATUS].include?(transaction['status']) }
    end

    # Returns true if the order has already been paid through Payrexx. Fails if it
    # has been paid in another way, as the user then probably paid twice.
    def paid_through_payrexx?(order)
      return false unless order.paid?
      return true if order.payment_gateway_name == PayrexxPayment::GATEWAY_NAME

      Rails.logger.error "Returned from a Payrexx payment for order #{order.uuid}, which has already been paid through #{order.payment_gateway_name.inspect}"
      Sentry.capture_message("Returned from a Payrexx payment for order #{order.uuid}, which has already been paid through #{order.payment_gateway_name.inspect}")
      fail PayrexxPayment::ExecutionFailed, _('PayrexxPaymentGateway|This order has already been paid in another way. If you have been charged twice, please contact us.')
    end
  end
end
