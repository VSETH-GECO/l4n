require 'test_helper'
require_relative '../unit/operations/payrexx_payment/payrexx_test_support'

# Returning to the success URL while Payrexx is still confirming the payment
# must show a page that checks again, instead of failing the payment.
class PayrexxSuccessTest < ActionDispatch::IntegrationTest
  include ::TestDataFactory
  include PayrexxTestSupport

  setup do
    # Like ApplicationTest, enable all features (e.g. signup, needed to create users)
    ::Operations::Admin::FeatureFlag::Reinitialize.run
    ::FeatureFlag.find_each { |flag| flag.update(enabled: true) }

    setup_payrexx_order
  end

  def test_pending_payment_shows_page_that_checks_again
    stub_get_gateway(42, status: 'waiting')
    stub_transactions({ id: 7, status: 'waiting' })

    get "/paymentgateway/payrexx/success?order_id=#{fetch(:order).uuid}"

    assert_response :success
    assert_select 'meta[http-equiv=refresh][content=?]', "3;url=/paymentgateway/payrexx/success?attempt=1&order_id=#{fetch(:order).uuid}"
    assert_not fetch(:order).reload.paid?
  end

  def test_gives_up_waiting_after_a_while
    stub_get_gateway(42, status: 'waiting')
    stub_transactions({ id: 7, status: 'waiting' })

    get "/paymentgateway/payrexx/success?order_id=#{fetch(:order).uuid}&attempt=#{PayrexxPayment::PaymentController::MAX_PENDING_ATTEMPTS}"

    assert_redirected_to '/shop/orders'
    assert_predicate flash[:warning], :present?
  end

  def test_payment_confirmed_after_waiting
    stub_get_gateway(42)

    get "/paymentgateway/payrexx/success?order_id=#{fetch(:order).uuid}&attempt=3"

    assert_redirected_to "/shop/orders/#{fetch(:order).uuid}"
    assert_predicate fetch(:order).reload, :paid?
  end

  def test_failed_payment_returns_to_cart
    stub_get_gateway(42, status: 'waiting')

    get "/paymentgateway/payrexx/success?order_id=#{fetch(:order).uuid}"

    assert_redirected_to '/shop/cart'
    assert_not fetch(:order).reload.paid?
  end

  private

  def store(key, value)
    (@test_data ||= {})[key] = value
  end

  def fetch(key)
    @test_data.fetch(key)
  end
end
