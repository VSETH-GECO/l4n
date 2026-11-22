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
  class ReleaseGateway < PayrexxOperation
    schema3 do
      obj! :order, classes: [::Order], strict: false
      boo? :settled_elsewhere, default: false
    end

    def perform
      order = osparams.order
      gateway_id = order.payment_gateway_payment_id

      # Nothing to do if the order has no (or another payment gateway's) payment
      return if order.paid? || order.payment_gateway_name != PayrexxPayment::GATEWAY_NAME || gateway_id.blank?

      gateway = fetch_gateway(gateway_id)

      # Gateway does not exist anymore, nothing that could still be paid
      return if gateway.nil?

      if !payment_successful?(gateway, order)
        delete_gateway(gateway_id)
      elsif osparams.settled_elsewhere
        fail PayrexxPayment::ExecutionFailed, "Order #{order.uuid} is being paid through another gateway, but its Payrexx gateway #{gateway_id} has already been paid"
      else
        run_sub! PayrexxPayment::ExecutePayment, order_id: order.uuid
        @paid = true
      end
    end

    def paid?
      @paid || false
    end
  end
end
