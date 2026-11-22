require 'test_helper'
require_relative 'payrexx_test_support'

module Unit
  module Operations
    module PayrexxPayment
      # When an order with an open Payrexx gateway is paid (or marked for a delayed
      # payment) through another gateway, the Payrexx gateway must be closed, such
      # that the user can't pay the order twice.
      class SettledElsewhereTest < ApplicationTest
        include PayrexxTestSupport

        setup do
          setup_payrexx_order
        end

        def test_paying_through_another_gateway_deletes_the_payrexx_gateway
          stub_get_gateway(42, status: 'waiting')
          delete = stub_delete_gateway(42)

          pay_through_paypal

          assert_requested delete

          order = fetch(:order).reload

          assert_predicate order, :paid?
          assert_equal 'Paypal Payment', order.payment_gateway_name
          assert_equal 8, fetch(:product).reload.inventory
        end

        def test_paid_payrexx_gateway_does_not_stop_the_other_payment
          stub_get_gateway(42)

          pay_through_paypal

          assert_not_requested :delete, "#{GATEWAY_BASE_URL}42/"

          order = fetch(:order).reload

          assert_predicate order, :paid?
          assert_equal 'Paypal Payment', order.payment_gateway_name
          # Only processed once
          assert_equal 8, fetch(:product).reload.inventory
        end

        def test_unreachable_payrexx_does_not_stop_the_other_payment
          stub_get_gateway_error(42)

          pay_through_paypal

          assert_predicate fetch(:order).reload, :paid?
        end

        def test_payment_through_payrexx_does_not_release_its_own_gateway
          stub_get_gateway(42)

          ::PayrexxPayment::ExecutePayment.run!(order_id: fetch(:order).uuid)

          assert_not_requested :delete, "#{GATEWAY_BASE_URL}42/"
          assert_predicate fetch(:order).reload, :paid?
        end

        def test_delayed_payment_deletes_the_payrexx_gateway
          ::Cart.create!(user: fetch(:user))
          stub_get_gateway(42, status: 'waiting')
          delete = stub_delete_gateway(42)

          ::Operations::PaymentGateway::MarkForDelayedPayment.run!(order_id: fetch(:order).uuid, gateway_name: 'Bank Transfer')

          assert_requested delete
          assert_predicate fetch(:order).reload, :delayed_payment_pending?
        end

        def test_returning_from_payrexx_after_paying_elsewhere_fails
          stub_get_gateway(42, status: 'waiting')
          stub_delete_gateway(42)
          pay_through_paypal

          assert_raises(::PayrexxPayment::ExecutionFailed) do
            ::PayrexxPayment::ExecutePayment.run!(order_id: fetch(:order).uuid)
          end

          assert_equal 'Paypal Payment', fetch(:order).reload.payment_gateway_name
          assert_equal 8, fetch(:product).reload.inventory
        end

        private

        def pay_through_paypal
          ::Operations::PaymentGateway::SubmitPaymentResult.run!(
            order_id:     fetch(:order).uuid,
            gateway_name: 'Paypal Payment',
            payment_id:   'PAYID-1'
          )
        end
      end
    end
  end
end
