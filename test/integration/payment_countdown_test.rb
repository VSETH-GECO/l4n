require 'test_helper'
require_relative '../unit/operations/payrexx_payment/payrexx_test_support'

# The payment pages show a countdown of the time left to pay. The server sends
# the seconds left, such that the countdown doesn't depend on the user's clock.
class PaymentCountdownTest < ActionDispatch::IntegrationTest
  include ::TestDataFactory
  include PayrexxTestSupport

  setup do
    ::Operations::Admin::FeatureFlag::Reinitialize.run
    ::FeatureFlag.find_each { |flag| flag.update(enabled: true) }
  end

  def test_payment_page_sends_seconds_left
    freeze_time do
      # Expires after 45 minutes, payment must be done 2 minutes before: 13 minutes left
      setup_payrexx_order(cleanup_timestamp: 30.minutes.ago, gateway_id: nil)

      get "/paymentgateway/payrexx/?order_id=#{fetch(:order).uuid}"

      assert_response :success
      assert_select '.countdown[data-seconds-left=?]', 13.minutes.to_i.to_s
    end
  end

  private

  def store(key, value)
    (@test_data ||= {})[key] = value
  end

  def fetch(key)
    @test_data.fetch(key)
  end
end
