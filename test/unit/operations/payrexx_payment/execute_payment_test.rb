require 'test_helper'
require_relative 'payrexx_test_support'

module Unit
  module Operations
    module PayrexxPayment
      class ExecutePaymentTest < ApplicationTest
        include PayrexxTestSupport

        setup do
          setup_payrexx_order
        end

        def test_confirmed_payment_marks_order_as_paid
          stub_get_gateway(42)

          assert ::PayrexxPayment::ExecutePayment.run!(order_id: fetch(:order).uuid)

          order = fetch(:order).reload

          assert_predicate order, :paid?
          assert_equal ::PayrexxPayment::GATEWAY_NAME, order.payment_gateway_name
          assert_equal '42', order.payment_gateway_payment_id
          assert_equal 8, fetch(:product).reload.inventory
        end

        def test_running_twice_only_processes_the_order_once
          stub = stub_get_gateway(42)

          ::PayrexxPayment::ExecutePayment.run!(order_id: fetch(:order).uuid)
          ::PayrexxPayment::ExecutePayment.run!(order_id: fetch(:order).uuid)

          assert_predicate fetch(:order).reload, :paid?
          assert_equal 8, fetch(:product).reload.inventory

          # The second run sees the order is paid and doesn't even ask Payrexx
          assert_requested stub, times: 1
        end

        def test_authorized_payment_is_not_accepted
          stub_get_gateway(42, status: 'authorized')

          assert_not_paid
        end

        def test_waiting_payment_is_not_accepted
          stub_get_gateway(42, status: 'waiting')

          assert_not_paid
        end

        def test_waiting_transaction_means_payment_is_pending
          stub_get_gateway(42, status: 'waiting')
          stub_transactions({ id: 7, status: 'waiting' })

          assert_not_paid(error: ::PayrexxPayment::PaymentPending)
        end

        def test_confirmed_transaction_on_waiting_gateway_means_payment_is_pending
          stub_get_gateway(42, status: 'waiting')
          stub_transactions({ id: 7, status: 'confirmed' })

          assert_not_paid(error: ::PayrexxPayment::PaymentPending)
        end

        def test_cancelled_transaction_is_not_pending
          stub_get_gateway(42, status: 'waiting')
          stub_transactions({ id: 7, status: 'cancelled' })

          assert_not_paid
        end

        def test_amount_mismatch_is_not_accepted
          stub_get_gateway(42, amount: ORDER_TOTAL_CENTS - 1)

          assert_not_paid
        end

        def test_currency_mismatch_is_not_accepted
          stub_get_gateway(42, currency: 'EUR')

          assert_not_paid
        end

        def test_reference_mismatch_is_not_accepted
          stub_get_gateway(42, reference_id: SecureRandom.uuid)

          assert_not_paid
        end

        def test_unknown_gateway_is_not_accepted
          stub_get_gateway_not_found(42)

          assert_not_paid
        end

        def test_api_error_is_not_accepted
          stub_get_gateway_error(42)

          assert_not_paid
        end

        def test_failure_to_process_the_order_is_not_swallowed
          # Marking the order as paid would make the inventory negative
          fetch(:product).update!(inventory: 1)
          stub_get_gateway(42)

          assert_raises(::PayrexxPayment::ExecutionFailed) do
            ::PayrexxPayment::ExecutePayment.run!(order_id: fetch(:order).uuid)
          end

          assert_not fetch(:order).reload.paid?
          assert_equal 1, fetch(:product).reload.inventory
        end

        def test_missing_order_fails_cleanly
          assert_raises(::PayrexxPayment::ExecutionFailed) do
            ::PayrexxPayment::ExecutePayment.run!(order_id: SecureRandom.uuid)
          end
        end

        def test_order_without_gateway_id_fails_cleanly
          fetch(:order).update!(payment_gateway_payment_id: nil)

          assert_not_paid
        end
      end
    end
  end
end
