require 'test_helper'
require_relative 'payrexx_test_support'

module Unit
  module Operations
    module PayrexxPayment
      # Cleaning up an expired order must close its Payrexx gateway, and must
      # not delete the order if it has been paid in the meantime.
      class OrderCleanupTest < ApplicationTest
        include PayrexxTestSupport

        setup do
          setup_payrexx_order(cleanup_timestamp: 46.minutes.ago)

          assert_predicate fetch(:order), :expired?
        end

        def test_deletes_gateway_and_order
          stub_get_gateway(42, status: 'waiting')
          delete = stub_delete_gateway(42)

          ::Operations::Shop::Order::CleanupSingleOrder.run!(order: fetch(:order))

          assert_requested delete
          assert_not ::Order.exists?(fetch(:order).id)
        end

        def test_keeps_paid_order
          stub_get_gateway(42)

          ::Operations::Shop::Order::CleanupSingleOrder.run!(order: fetch(:order))

          assert_predicate fetch(:order).reload, :paid?
          assert_equal 8, fetch(:product).reload.inventory
        end

        def test_keeps_order_if_payrexx_is_unreachable
          stub_get_gateway_error(42)

          ::Operations::Shop::Order::CleanupSingleOrder.run!(order: fetch(:order))

          assert ::Order.exists?(fetch(:order).id)
          assert_not fetch(:order).reload.paid?
        end

        def test_cleanup_expired_handles_payrexx_orders
          stub_get_gateway(42, status: 'waiting')
          stub_delete_gateway(42)

          ::Operations::Admin::Order::CleanupExpired.run!

          assert_not ::Order.exists?(fetch(:order).id)
        end

        def test_order_without_gateway_is_deleted_without_api_calls
          fetch(:order).update!(payment_gateway_name: nil, payment_gateway_payment_id: nil)

          ::Operations::Shop::Order::CleanupSingleOrder.run!(order: fetch(:order))

          assert_not ::Order.exists?(fetch(:order).id)
        end
      end
    end
  end
end
