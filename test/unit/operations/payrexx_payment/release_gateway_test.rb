require 'test_helper'
require_relative 'payrexx_test_support'

module Unit
  module Operations
    module PayrexxPayment
      class ReleaseGatewayTest < ApplicationTest
        include PayrexxTestSupport

        setup do
          setup_payrexx_order
        end

        def test_unpaid_gateway_is_deleted
          stub_get_gateway(42, status: 'waiting')
          delete = stub_delete_gateway(42)

          assert_not ::PayrexxPayment::ReleaseGateway.run!(order: fetch(:order)).paid?

          assert_requested delete
          assert_not fetch(:order).reload.paid?
        end

        def test_paid_gateway_marks_order_as_paid_instead
          stub_get_gateway(42)

          assert_predicate ::PayrexxPayment::ReleaseGateway.run!(order: fetch(:order)), :paid?

          assert_not_requested :delete, "#{GATEWAY_BASE_URL}42/"
          assert_predicate fetch(:order).reload, :paid?
          assert_equal 8, fetch(:product).reload.inventory
        end

        def test_unknown_gateway_is_ignored
          stub_get_gateway_not_found(42)

          assert_not ::PayrexxPayment::ReleaseGateway.run!(order: fetch(:order)).paid?

          assert_not_requested :delete, "#{GATEWAY_BASE_URL}42/"
        end

        def test_failed_deletion_raises
          stub_get_gateway(42, status: 'waiting')
          stub_delete_gateway(42, code: 500)

          assert_raises(::PayrexxPayment::ExecutionFailed) do
            ::PayrexxPayment::ReleaseGateway.run!(order: fetch(:order))
          end
        end

        def test_order_of_another_gateway_is_ignored
          # Any request to Payrexx would fail the test, as WebMock blocks it
          fetch(:order).update!(payment_gateway_name: 'Paypal Payment')

          assert_not ::PayrexxPayment::ReleaseGateway.run!(order: fetch(:order)).paid?
        end

        def test_order_without_gateway_is_ignored
          fetch(:order).update!(payment_gateway_name: nil, payment_gateway_payment_id: nil)

          assert_not ::PayrexxPayment::ReleaseGateway.run!(order: fetch(:order)).paid?
        end
      end
    end
  end
end
