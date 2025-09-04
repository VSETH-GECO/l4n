module PayrexxPayment
  class PaymentController < ApplicationController
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
      if run PayrexxPayment::CreatePayment
        # Redirect to the Payrexx gateway URL
        redirect_to op.gateway_url, allow_other_host: true
      else
        flash[:danger] = _('PayrexxPaymentGateway|Something went wrong, please try again')
        redirect_to main_app.shop_cart_path
      end
    end

    def success
      if run PayrexxPayment::ExecutePayment, order_id: params[:order_id]
        flash[:success] = _('Order|Successfully paid for the order')
        redirect_to main_app.shop_order_path(id: params[:order_id])
      else
        flash[:danger] = _('PayrexxPaymentGateway|Payment could not be verified')
        redirect_to main_app.shop_cart_path
      end
    rescue PayrexxPayment::ExecutionFailed => e
      flash[:danger] = e.message
      redirect_to main_app.shop_cart_path
    end

    def failure
      flash[:danger] = _('PayrexxPaymentGateway|Payment was cancelled or failed')
      redirect_to main_app.shop_cart_path
    end
  end
end
