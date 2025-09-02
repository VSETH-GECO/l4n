module PayrexxPayment
  class ExecutePayment < PayrexxOperation
    schema3 do
      str! :order_id
      str? :gateway_id
    end


    def perform
      # Get data from the backend about the payment
      begin
        result = Operations::PaymentGateway::GetPaymentInfo.run!(order_id: osparams.order_id).result

        # Check that the order is still valid
        fail PayrexxPayment::ExecutionFailed, _('PayrexxPaymentGateway|Order is expired, payment was not executed') if result[:valid_until] <= Time.zone.now
      rescue Operations::PaymentGateway::InvalidOrder => e
        fail PayrexxPayment::ExecutionFailed, e.message
      end

      # Verify the payment status with Payrexx
      gateway_info = get_gateway_info


      pp ("---- GATEWAY INFO DUMP ----")
      pp (gateway_info)
      pp ("---------------------------")

        # Check if payment was successful
      unless payment_successful?(gateway_info)
        fail PayrexxPayment::ExecutionFailed, _('PayrexxPaymentGateway|Payment was not successful')
      end

      # Extract payment information
      #payment_id = gateway_info.dig('data','0', 'id') || osparams.gateway_id

      # If the payment is approved, mark the order as paid
      run_sub Operations::PaymentGateway::SubmitPaymentResult, {
        gateway_name: 'Payrexx Payment',
        payment_id: payment_id.to_s,
        order_id: osparams.order_id
      }

      true
    end

    private

    def get_gateway_info

      pp('Sdaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaergershndgjnsrz')
      pp($gatewaymap[osparams.order_id])
      # If we have a gateway_id, use it, otherwise try to find it by reference
      response = HTTParty.get(
        "https://api.payrexx.com/v1.11/Gateway/#{$gatewaymap[osparams.order_id]}",
        headers: {
          'accept'    => 'application/json',
          'X-API-KEY' => api_key
        },
        query:   {
          instance: "#{payrexx_instance}"
        }
      )
        pp("dfsssssssssssssssssss")
        pp("https://api.payrexx.com/v1.11/Gateway/#{$gatewaymap[osparams.order_id]}")
      unless response.success?
        fail PayrexxPayment::ExecutionFailed, _('PayrexxPaymentGateway|Could not verify payment status')
      end

      response.parsed_response
    end

    def payment_successful?(gateway_info)
      return false unless gateway_info['status'] == 'success'
      return false unless gateway_info['data']&.any?

      gateway_data = gateway_info['data'].first

      pp('YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYyyyyaa')
      pp(gateway_data)

      # Check if the gateway status indicates successful payment
      # Payrexx gateway statuses: waiting, authorized, partially-authorized, confirmed, cancelled, declined, error  
      successful_statuses = %w[authorized confirmed]

      successful_statuses.include?(gateway_data['status'])
    end

    def gateway_url
      if Rails.env.development?
        "https://api.payrexx.com/v1.0/Gateway/?instance=#{payrexx_instance}"
      else
        "https://api.payrexx.com/v1.0/Gateway/?instance=#{payrexx_instance}"
      end
    end

    def api_key
      Figaro.env.payrexx_api_key!
    end

    def payrexx_instance
      Rails.env.development? ? 'vseth' : PAYREXX_INSTANCE
    end
  end

  class ExecutionFailed < StandardError; end
end
