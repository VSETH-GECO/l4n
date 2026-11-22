module PayrexxPayment
  class PaymentController < ApplicationController
    # Wait up to about a minute for a pending payment to be confirmed
    MAX_PENDING_ATTEMPTS = 20
    PENDING_RETRY_DELAY = 3 # seconds

    def index
      run Operations::PaymentGateway::GetPaymentInfo
    rescue Operations::PaymentGateway::InvalidOrder => e
      flash[:danger] = e.message
      redirect_to main_app.shop_cart_path
    end

    def create_payment
      if run PayrexxPayment::CreatePayment
        render json: { status: 'ok', payment_id: op.payment_id }
      else
        render json: { status: 'error', message: _('PayrexxPaymentGateway|Something went wrong, please try again') }
      end
    end

    def execute_payment
      if run PayrexxPayment::ExecutePayment
        flash[:success] = _('Order|Successfully paid for the order')
        render json: { status: 'ok', path: main_app.shop_order_path(id: params[:order_id]) }
      else
        render json: { status: 'error', message: _('PayrexxPaymentGateway|Something went wrong, please try again') }
      end
    rescue PayrexxPayment::ExecutionFailed => e
      render json: { status: 'error', message: e.message }
    end

    def complete_payment
      if !run(PayrexxPayment::CreatePayment)
        flash[:danger] = _('PayrexxPaymentGateway|Something went wrong, please try again')
        redirect_to main_app.shop_cart_path
      elsif op.already_paid
        # A previously started payment for this order has been paid in the meantime
        flash[:success] = _('Order|Successfully paid for the order')
        redirect_to main_app.shop_order_path(id: params[:order_id])
      else
        # Redirect to the Payrexx gateway URL
        redirect_to op.gateway_url, allow_other_host: true
      end
    rescue Operations::PaymentGateway::InvalidOrder, PayrexxPayment::ExecutionFailed => e
      # Also handles PaymentPending, if a previous payment for the order is still in progress
      flash[:danger] = e.message
      redirect_to main_app.shop_cart_path
    end

    def success
      if run PayrexxPayment::ExecutePayment, order_id: params[:order_id]
        flash[:success] = _('Order|Successfully paid for the order')
        redirect_to main_app.shop_order_path(id: params[:order_id])
      else
        flash[:danger] = _('PayrexxPaymentGateway|Payment could not be verified')
        redirect_to main_app.shop_cart_path
      end
    rescue PayrexxPayment::PaymentPending
      payment_pending
    rescue PayrexxPayment::ExecutionFailed => e
      flash[:danger] = e.message
      redirect_to main_app.shop_cart_path
    end

    def failure
      flash[:danger] = _('PayrexxPaymentGateway|Payment was cancelled or failed')
      redirect_to main_app.shop_cart_path
    end

    private

    # Shows a page that reloads the success URL every few seconds, until the
    # payment is confirmed or we give up.
    def payment_pending
      @attempt = params[:attempt].to_i + 1

      if @attempt <= MAX_PENDING_ATTEMPTS
        @retry_path = success_payment_path(order_id: params[:order_id], attempt: @attempt)
        @retry_delay = PENDING_RETRY_DELAY
        render :pending
      else
        # The order is marked as paid once Payrexx confirms the payment, at the
        # latest when the order would be cleaned up.
        flash[:warning] = _('PayrexxPaymentGateway|Your payment has not been confirmed yet. As soon as it is, your order will be marked as paid.')
        redirect_to main_app.shop_orders_path
      end
    end
  end
end
