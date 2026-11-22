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

        def test_waiting_transaction_is_cancelled_before_deleting_the_gateway
          stub_get_gateway(42, status: 'waiting')
          stub_transactions({ id: 7, status: 'waiting' }, { id: 8, status: 'cancelled' })
          cancel = stub_cancel_transaction(7)
          delete = stub_delete_gateway(42)

          assert_not release.paid?

          assert_requested cancel
          assert_not_requested :patch, "#{TRANSACTION_BASE_URL}8/cancel"
          assert_requested delete
        end

        def test_transaction_paid_while_cancelling_marks_order_as_paid
          # The transaction is confirmed just before we try to cancel it
          stub_get_gateway(42, status: %w[waiting confirmed])
          stub_transactions({ id: 7, status: 'waiting' })
          stub_cancel_transaction(7, waiting: false)

          assert_predicate release, :paid?

          assert_not_requested :delete, "#{GATEWAY_BASE_URL}42/"
          assert_predicate fetch(:order).reload, :paid?
          assert_equal 8, fetch(:product).reload.inventory
        end

        def test_transaction_failed_while_cancelling_deletes_the_gateway
          stub_get_gateway(42, status: 'waiting')
          stub_request(:get, TRANSACTION_BASE_URL).with(query: hash_including(filterReference: fetch(:order).uuid))
                                                  .to_return(transactions_response('waiting'), transactions_response('declined'))
          stub_cancel_transaction(7, waiting: false)
          delete = stub_delete_gateway(42)

          assert_not release.paid?

          assert_requested delete
        end

        def test_transaction_that_cannot_be_cancelled_keeps_the_gateway
          stub_get_gateway(42, status: 'waiting')
          stub_transactions({ id: 7, status: 'waiting' })
          stub_cancel_transaction(7, waiting: false)

          assert_raises(::PayrexxPayment::PaymentPending) { release }

          assert_not_requested :delete, "#{GATEWAY_BASE_URL}42/"
          assert_not fetch(:order).reload.paid?
        end

        def test_confirmed_transaction_keeps_the_gateway_until_it_is_confirmed_too
          stub_get_gateway(42, status: 'waiting')
          stub_transactions({ id: 7, status: 'confirmed' })

          assert_raises(::PayrexxPayment::PaymentPending) { release }

          assert_not_requested :patch, "#{TRANSACTION_BASE_URL}7/cancel"
          assert_not_requested :delete, "#{GATEWAY_BASE_URL}42/"
        end

        def test_transactions_of_other_references_are_ignored
          # `filterReference` also matches the purpose of other transactions
          stub_get_gateway(42, status: 'waiting')
          stub_transactions({ id: 7, status: 'waiting', reference_id: 'other' }, { id: 8, status: 'confirmed', reference_id: 'other' })
          delete = stub_delete_gateway(42)

          assert_not release.paid?

          assert_not_requested :patch, "#{TRANSACTION_BASE_URL}7/cancel"
          assert_requested delete
        end

        private

        def release
          ::PayrexxPayment::ReleaseGateway.run!(order: fetch(:order))
        end

        def transactions_response(status)
          { status: 200, body: { status: 'success', data: [{ id: 7, status: status, referenceId: fetch(:order).uuid }] }.to_json, headers: { 'Content-Type' => 'application/json' } }
        end
      end
    end
  end
end
