module PayrexxPayment
  # Makes sure the Payrexx gateway of an unpaid order can't be paid anymore,
  # e.g. before the order is deleted or before a new gateway is created for it.
  #
  # If the gateway turns out to have been paid in the meantime (e.g. the user
  # paid but never returned to the success URL), the order is marked as paid
  # instead and `paid?` returns true. The caller must then not delete the order.
  #
  # With `settled_elsewhere`, the order is about to be paid through another
  # gateway. A gateway that has been paid then means the user paid twice, which
  # fails with ExecutionFailed instead of marking the order as paid.
  #
  # A payment that is in progress (e.g. a TWINT payment that hasn't been approved
  # in the app yet) shows up as a `waiting` transaction and can still complete.
  # Deleting the gateway is not documented to stop it, so all waiting transactions
  # are cancelled first. Payrexx only cancels a transaction while it is waiting,
  # so a payment either completes or is cancelled, but never gets lost. If a
  # transaction can't be cancelled and the gateway still isn't paid, this fails
  # with PaymentPending and the caller should try again later. The same happens if
  # a transaction is confirmed but the gateway doesn't show it as paid yet.
  #
  # There remains a window of a few milliseconds between listing the transactions
  # and deleting the gateway, in which the user could start a new payment.
  class ReleaseGateway < PayrexxOperation
    schema3 do
      obj! :order, classes: [::Order], strict: false
      boo? :settled_elsewhere, default: false
    end

    # How often to re-check the gateway if a transaction changed its status
    # while we tried to cancel it.
    CANCEL_ATTEMPTS = 2

    def perform
      order = osparams.order
      gateway_id = order.payment_gateway_payment_id

      # Nothing to do if the order has no (or another payment gateway's) payment
      return if order.paid? || order.payment_gateway_name != PayrexxPayment::GATEWAY_NAME || gateway_id.blank?

      CANCEL_ATTEMPTS.times do
        gateway = fetch_gateway(gateway_id)

        # Gateway does not exist anymore, nothing that could still be paid
        return if gateway.nil?

        return handle_paid_gateway(order, gateway_id) if payment_successful?(gateway, order)

        transactions = fetch_transactions(order)

        # A transaction has been paid, but the gateway doesn't show it yet
        break if transactions.any? { |transaction| transaction['status'] == SUCCESSFUL_STATUS }

        if cancel_waiting_transactions(transactions)
          delete_gateway(gateway_id)
          return
        end
      end

      fail PayrexxPayment::PaymentPending, _('PayrexxPaymentGateway|A payment for this order is still being processed, please try again in a moment')
    end

    def paid?
      @paid || false
    end

    private

    def handle_paid_gateway(order, gateway_id)
      fail PayrexxPayment::ExecutionFailed, "Order #{order.uuid} is being paid through another gateway, but its Payrexx gateway #{gateway_id} has already been paid" if osparams.settled_elsewhere

      run_sub! PayrexxPayment::ExecutePayment, order_id: order.uuid
      @paid = true
    end

    # Returns true if none of the given transactions is waiting anymore. Tries to
    # cancel all of them (not stopping at the first failure).
    def cancel_waiting_transactions(transactions) # rubocop:disable Naming/PredicateMethod
      transactions.select { |transaction| transaction['status'] == WAITING_STATUS }
                  .map { |transaction| cancel_transaction(transaction['id']) }
                  .all?
    end
  end
end
