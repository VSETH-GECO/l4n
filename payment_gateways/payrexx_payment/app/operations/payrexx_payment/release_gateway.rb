module PayrexxPayment
  # Makes sure the Payrexx gateway of an unpaid order can't be paid anymore,
  # e.g. before the order is deleted or before a new gateway is created for it.
  #
  # If the gateway turns out to have been paid in the meantime (e.g. the user
  # paid but never returned to the success URL), the order is marked as paid
  # instead and `paid?` returns true. The caller must then not delete the order.
  class ReleaseGateway < PayrexxOperation
    schema3 do
      obj! :order, classes: [::Order], strict: false
    end

    def perform
      order = osparams.order
      gateway_id = order.payment_gateway_payment_id

      # Nothing to do if the order has no (or another payment gateway's) payment
      return if order.paid? || order.payment_gateway_name != PayrexxPayment::GATEWAY_NAME || gateway_id.blank?

      gateway = fetch_gateway(gateway_id)

      # Gateway does not exist anymore, nothing that could still be paid
      return if gateway.nil?

      if payment_successful?(gateway, order)
        run_sub! PayrexxPayment::ExecutePayment, order_id: order.uuid
        @paid = true
      else
        delete_gateway(gateway_id)
      end
    end

    def paid?
      @paid || false
    end
  end
end
