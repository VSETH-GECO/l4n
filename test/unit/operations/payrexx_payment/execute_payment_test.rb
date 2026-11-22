require 'test_helper'

module Unit
  module Operations
    module PayrexxPayment
      class ExecutePaymentTest < ApplicationTest
        # Returns a canned gateway response instead of calling the Payrexx API
        class StubbedExecutePayment < ::PayrexxPayment::ExecutePayment
          class_attribute :gateway_response

          private

          def fetch_gateway(_gateway_id)
            gateway_response
          end
        end

        setup do
          store :user, create_user

          create_product_category

          store :product, create_product(inventory: 10)
          store :variant, create_product_variant(fetch(:product), price: Money.new(1999))

          store :order, create_order(fetch(:user), 'payment_pending')
          create_order_item(fetch(:order), fetch(:variant), quantity: 2)
          fetch(:order).update!(payment_gateway_payment_id: '42')
        end

        def test_confirmed_payment_marks_order_as_paid
          stub_gateway

          assert StubbedExecutePayment.run!(order_id: fetch(:order).uuid)

          order = fetch(:order).reload

          assert_predicate order, :paid?
          assert_equal 'Payrexx Payment', order.payment_gateway_name
          assert_equal '42', order.payment_gateway_payment_id
          assert_equal 8, fetch(:product).reload.inventory
        end

        def test_running_twice_only_processes_the_order_once
          stub_gateway

          StubbedExecutePayment.run!(order_id: fetch(:order).uuid)
          StubbedExecutePayment.run!(order_id: fetch(:order).uuid)

          assert_predicate fetch(:order).reload, :paid?
          assert_equal 8, fetch(:product).reload.inventory
        end

        def test_authorized_payment_is_not_accepted
          stub_gateway(status: 'authorized')

          assert_not_paid
        end

        def test_waiting_payment_is_not_accepted
          stub_gateway(status: 'waiting')

          assert_not_paid
        end

        def test_amount_mismatch_is_not_accepted
          stub_gateway(amount: 3997)

          assert_not_paid
        end

        def test_currency_mismatch_is_not_accepted
          stub_gateway(currency: 'EUR')

          assert_not_paid
        end

        def test_reference_mismatch_is_not_accepted
          stub_gateway(referenceId: SecureRandom.uuid)

          assert_not_paid
        end

        def test_missing_order_fails_cleanly
          stub_gateway

          assert_raises(::PayrexxPayment::ExecutionFailed) do
            StubbedExecutePayment.run!(order_id: SecureRandom.uuid)
          end
        end

        def test_order_without_gateway_id_fails_cleanly
          stub_gateway
          fetch(:order).update!(payment_gateway_payment_id: nil)

          assert_not_paid
        end

        private

        def stub_gateway(**overrides)
          StubbedExecutePayment.gateway_response = {
            'id'          => 42,
            'status'      => 'confirmed',
            'referenceId' => fetch(:order).uuid,
            'amount'      => 3998,
            'currency'    => 'CHF'
          }.merge(overrides.stringify_keys)
        end

        def assert_not_paid
          assert_raises(::PayrexxPayment::ExecutionFailed) do
            StubbedExecutePayment.run!(order_id: fetch(:order).uuid)
          end

          assert_not fetch(:order).reload.paid?
          assert_equal 10, fetch(:product).reload.inventory
        end
      end
    end
  end
end
