require 'payrexx_payment/version'
require 'payrexx_payment/engine'

module PayrexxPayment
  # Stored as `payment_gateway_name` on orders, both when a Payrexx gateway is
  # created for the order and when the order has been paid through Payrexx.
  GATEWAY_NAME = 'Payrexx Payment'.freeze

  # Called before an unpaid order is deleted. Deletes the order's Payrexx gateway,
  # such that it can't be paid anymore. Returns true if the order turned out to
  # be paid already, in which case it is now marked as paid and must not be deleted.
  def self.before_order_cleanup(order) # rubocop:disable Naming/PredicateMethod
    PayrexxPayment::ReleaseGateway.run!(order: order).paid?
  end

  def self.payment_path(*)
    PayrexxPayment::Engine.routes.url_helpers.start_payment_path(*)
  end

  def self.name
    _('PayrexxPaymentGateway')
  end

  def self.payment_button_text
    _('PayrexxPaymentGateway|Pay')
  end
end
