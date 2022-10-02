module Operations::PaymentGateway
  class MarkForDelayedPayment < RailsOps::Operation
    without_authorization

    schema3 do
      str! :order_id
      str! :gateway_name
    end

    def perform
      fail 'No order_id given' if osparams.order_id.blank?

      # Get order
      order = ::Order.find_by(uuid: osparams.order_id)

      fail 'Order not found' if order.nil?

      run_sub Operations::Shop::Order::ProcessMarkedForDelayedPayment, order: order, gateway_name: osparams.gateway_name
    end
  end
end
