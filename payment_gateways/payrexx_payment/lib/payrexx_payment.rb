require 'payrexx_payment/version'
require 'payrexx_payment/engine'

module PayrexxPayment
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
