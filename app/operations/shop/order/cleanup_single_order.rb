module Operations::Shop::Order
  class CleanupSingleOrder < RailsOps::Operation
    schema3 do
      obj! :order, classes: [Order], strict: false
    end

    without_authorization

    delegate :order, to: :osparams

    def perform
      fail 'Not possible to cleanup this order' unless order.expired? || order.created? || order.delayed_payment_pending?

      # Let the payment gateways close any payment that is still open for this order,
      # such that it can't be paid after it has been deleted. Keep the order if it
      # turns out it has been paid in the meantime, or if the gateway couldn't be
      # reached (we'll try again during the next cleanup).
      return unless payment_gateways_released?

      order.order_items.each do |order_item|
        next if order_item.product_variant.nil?

        # increase availability of product_item
        order_item.product.availability += order_item.quantity
        order_item.product.save!

        # Run any behaviour on_cleanup actions we might have
        order_item.product.on_cleanup_behaviour_actions(order_item)
      end

      order.destroy!
    end

    private

    # Payment gateways can implement `before_order_cleanup(order)`, which returns true
    # if the order turned out to be paid already and therefore must not be deleted.
    def payment_gateways_released?
      Rails.application.config.payment_gateways.none? do |gateway|
        next false unless gateway.respond_to?(:before_order_cleanup)

        gateway.before_order_cleanup(order)
      rescue StandardError => e
        Rails.logger.error "Could not release payment gateway #{gateway} for order #{order.uuid}: #{e.message}"
        Sentry.capture_exception(e)
        true
      end
    end
  end
end
