module PayrexxPayment
  class ExecutePayment < PayrexxOperation
    schema3 do
      str! :order_id
      str? :gateway_id
    end

    def perform
      # Get data from the backend about the payment
      # begin
      #   result = Operations::PaymentGateway::GetPaymentInfo.run!(order_id: osparams.order_id).result
      #
      #   # Check that the order is still valid
      #   fail PayrexxPayment::ExecutionFailed, _('PayrexxPaymentGateway|Order is expired, payment was not executed') if result[:valid_until] <= Time.zone.now
      # rescue Operations::PaymentGateway::InvalidOrder => e
      #   fail PayrexxPayment::ExecutionFailed, e.message
      # end

      # Verify the payment status with Payrexx
      order = ::Order.find_by(uuid: osparams.order_id)
      gateway_info = get_gateway_info(order)

      # Check if payment was successful
      unless payment_successful?(gateway_info)
        fail PayrexxPayment::ExecutionFailed, _('PayrexxPaymentGateway|Payment was not successful')
      end

      # If the payment is approved, mark the order as paid
      run_sub Operations::PaymentGateway::SubmitPaymentResult, {
        gateway_name: 'Payrexx Payment',
        payment_id: order.payment_gateway_payment_id,
        order_id: osparams.order_id
      }

      true
    end

    private

    def get_gateway_info(order)
      # If we have a gateway_id, use it, otherwise try to find it by reference
      response = HTTParty.get(
        "https://api.payrexx.com/v1.11/Gateway/#{order.payment_gateway_payment_id}",
        headers: {
          'accept'    => 'application/json',
          'X-API-KEY' => api_key
        },
        query:   {
          instance: "#{payrexx_instance}"
        }
      )

      unless response.success?
        fail PayrexxPayment::ExecutionFailed, _('PayrexxPaymentGateway|Could not verify payment status')
      end

      response.parsed_response
    end

    def payment_successful?(gateway_info)
      return false unless gateway_info['status'] == 'success'
      return false unless gateway_info['data']&.any?

      gateway_data = gateway_info['data'].first

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
