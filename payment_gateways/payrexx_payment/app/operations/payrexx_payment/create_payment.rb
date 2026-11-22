module PayrexxPayment
  class CreatePayment < PayrexxOperation
    schema3 do
      str! :order_id
    end

    attr_accessor :payment_id
    attr_accessor :gateway_url
    attr_accessor :already_paid

    def perform
      order_data = Operations::PaymentGateway::GetPaymentInfo.run!(order_id: osparams.order_id).result
      order = ::Order.find_by!(uuid: osparams.order_id)

      # If the user already started a payment for this order (e.g. went back from
      # the Payrexx page and clicked "Pay now" again), the previous gateway must not
      # stay payable. If it has been paid already, the order is now marked as paid.
      if run_sub!(PayrexxPayment::ReleaseGateway, order: order).paid?
        @already_paid = true
        return
      end

      create_payment_gateway(order_data, order)
    end

    private

    def create_payment_gateway(order_data, order)
      # Payrexx expects the amount as an integer in cents. Use Money#cents directly,
      # converting through a float truncates (e.g. 19.99 * 100 => 1998).
      total = order_data[:total]

      # Prepare success, failure, and cancel URLs
      success_url = "#{base_url}/success?order_id=#{osparams.order_id}"
      failure_url = "#{base_url}/failure?order_id=#{osparams.order_id}"
      cancel_url = "#{base_url}/cancel?order_id=#{osparams.order_id}"

      body = {
        amount:             total.cents,
        currency:           total.currency.iso_code,
        successRedirectUrl: success_url,
        failedRedirectUrl:  failure_url,
        cancelRedirectUrl:  cancel_url,
        pm:                 %w[TWINT], # Payment methods
        referenceId:        osparams.order_id,
        skipResultPage:     false,
        validity:           validity_in_minutes(order_data[:valid_until])
      }

      # Add purpose/description
      if order_data[:items].any?
        purpose = order_data[:items].map { |item| "#{item[:quantity]}x #{item[:product]}" }.join(', ')
        body[:purpose] = purpose.truncate(100) # Payrexx has limits on purpose length
      end

      response = request(
        :post,
        gateways_endpoint,
        body:    body,
        headers: common_headers.merge('content-type' => 'application/x-www-form-urlencoded')
      )

      response_data = response.parsed_response

      unless response.success? && valid_gateway_response?(response_data) && response_data['data'][0]['link'].present?
        Rails.logger.error "Could not create Payrexx gateway for order #{osparams.order_id}: #{response.code} - #{response.body.to_s.truncate(500)}"
        fail PayrexxPayment::ExecutionFailed, _('PayrexxPaymentGateway|Something went wrong, please try again')
      end

      order.update!(
        payment_gateway_name:       PayrexxPayment::GATEWAY_NAME,
        payment_gateway_payment_id: response_data['data'][0]['id']
      )

      @payment_id = response_data['data'][0]['id']
      @gateway_url = response_data['data'][0]['link']
    end

    # The gateway must expire before the order does, otherwise the user could
    # still pay after the order has been cleaned up. `valid_until` already
    # contains some padding before the order actually expires.
    def validity_in_minutes(valid_until)
      minutes = ((valid_until - Time.zone.now) / 1.minute).floor

      fail Operations::PaymentGateway::InvalidOrder, _('Checkout|Order expired') if minutes < 1

      minutes
    end

    def base_url
      # This should be the base URL of your application
      # You might need to configure this in your Rails app
      if Rails.env.development?
        'https://localhost:3000/paymentgateway/payrexx'
      else
        "#{Rails.application.config.force_ssl ? 'https' : 'http'}://#{Rails.application.config.action_mailer.default_url_options[:host]}/paymentgateway/payrexx"
      end
    end
  end
end
