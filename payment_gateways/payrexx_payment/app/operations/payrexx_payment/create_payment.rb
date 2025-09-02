module PayrexxPayment
  class CreatePayment < PayrexxOperation
    schema3 do
      str! :order_id
    end

    attr_accessor :payment_id
    attr_accessor :gateway_url

    def perform
      order_data = Operations::PaymentGateway::GetPaymentInfo.run!(order_id: osparams.order_id).result

      create_payment_gateway(order_data)
    end

    private

    def create_payment_gateway(order_data)
      # Calculate total amount in cents (Payrexx expects amount in cents)
      total_amount = (order_data[:total].to_f * 100).to_i

      # Prepare success, failure, and cancel URLs
      success_url = "#{base_url}/success?order_id=#{osparams.order_id}"
      failure_url = "#{base_url}/failure?order_id=#{osparams.order_id}"
      cancel_url = "#{base_url}/cancel?order_id=#{osparams.order_id}"

      body = {
        amount:             total_amount,
        currency:           order_data[:currency] || 'CHF',
        successRedirectUrl: success_url,  
        failedRedirectUrl:  failure_url,
        cancelRedirectUrl:  cancel_url,
        pm:                 %w[TWINT], # Payment methods
        referenceId:        osparams.order_id,
        skipResultPage:     false,
        validity:           30 # 30 minutes validity
      }

      # Add purpose/description
      if order_data[:items].any?
        purpose = order_data[:items].map { |item| "#{item[:quantity]}x #{item[:product]}" }.join(', ')
        body[:purpose] = purpose.truncate(100) # Payrexx has limits on purpose length
      end

      response = HTTParty.post(
        payment_url,
        body:    body,
        headers: {
          'accept'       => 'application/json',
          'X-API-KEY'    => api_key,
          'content-type' => 'application/x-www-form-urlencoded'
        }
      )
     
      fail "API request failed: #{response.code} - #{response.message}" unless response.success?

      response_data = response.parsed_response
      
      pp ("---- REEEESPONSE INFO DUMP ----")
      pp (response_data)
      pp ("---------------------------")


      fail "Gateway creation failed: #{response_data['message'] || 'Unknown error'}" unless response_data['status'] == 'success' && response_data['data']

     
      @payment_id = response_data['data'][0]['id']
      @gateway_url = response_data['data'][0]['link']

      $gatewaymap[osparams.order_id]=@payment_id

      pp("the thing is this here #{$gatewaymap[osparams.order_id]}")
    end

    def payment_url
      if Rails.env.development?
        "https://api.payrexx.com/v1.0/Gateway/?instance=#{payrexx_instance}"
      else
        "https://api.payrexx.com/v1.0/Gateway/?instance=#{payrexx_instance}"
      end
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

    def api_key
      Figaro.env.payrexx_api_key!
    end

    def payrexx_instance
      Rails.env.development? ? 'vseth' : PAYREXX_INSTANCE
    end
  end
end
