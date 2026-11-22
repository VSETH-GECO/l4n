module Services
  # Optional hooks that payment gateways (see `config.payment_gateways`) can implement.
  module PaymentGateways
    # Called before an order is marked as paid or as waiting for a delayed payment
    # through the gateway named `gateway_name` (nil if an admin marks it as paid).
    #
    # Gateways can implement `before_order_settled(order, gateway_name:)` to close
    # payments they still have open for the order, such that it can't be paid a
    # second time through them. Errors are reported but don't stop the order from
    # being processed, as the user has already paid (or committed to pay) for it.
    def self.before_order_settled(order, gateway_name:)
      Rails.application.config.payment_gateways.each do |gateway|
        next unless gateway.respond_to?(:before_order_settled)

        gateway.before_order_settled(order, gateway_name: gateway_name)
      rescue StandardError => e
        Rails.logger.error "Payment gateway #{gateway} could not prepare order #{order.uuid} for being settled through #{gateway_name.inspect}: #{e.message}"
        Sentry.capture_exception(e)
      end
    end
  end
end
