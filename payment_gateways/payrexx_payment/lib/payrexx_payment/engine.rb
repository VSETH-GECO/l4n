module PayrexxPayment
  class Engine < ::Rails::Engine
    isolate_namespace PayrexxPayment

    initializer 'payrexx_payment.configuration' do |app|
      app.routes.append do
        mount PayrexxPayment::Engine => '/paymentgateway/payrexx'
      end

      app.config.payment_gateways << ::PayrexxPayment

      app.config.assets.precompile += %w[payrexx_payment_manifest.js]
    end
  end
end
