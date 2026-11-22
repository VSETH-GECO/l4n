require 'test_helper'
require_relative 'payrexx_test_support'

module Unit
  module Operations
    module PayrexxPayment
      class CreatePaymentTest < ApplicationTest
        include PayrexxTestSupport

        def test_creates_gateway
          freeze_time do
            # The order was created 30 minutes ago. It expires after 45 minutes,
            # and the payment has to be done 2 minutes before that, so 13 minutes are left.
            setup_payrexx_order(cleanup_timestamp: 30.minutes.ago, gateway_id: nil)
            create = stub_create_gateway(id: 43)

            op = ::PayrexxPayment::CreatePayment.run!(order_id: fetch(:order).uuid)

            assert_requested create.with(body: hash_including(
              'amount'      => ORDER_TOTAL_CENTS.to_s,
              'currency'    => 'CHF',
              'referenceId' => fetch(:order).uuid,
              'validity'    => '13'
            ))

            assert_equal 'https://vseth.payrexx.com/?payment=43', op.gateway_url
            assert_not op.already_paid

            order = fetch(:order).reload

            assert_equal ::PayrexxPayment::GATEWAY_NAME, order.payment_gateway_name
            assert_equal '43', order.payment_gateway_payment_id
          end
        end

        def test_fails_if_less_than_a_minute_is_left
          freeze_time do
            setup_payrexx_order(cleanup_timestamp: (42.minutes + 30.seconds).ago, gateway_id: nil)

            assert_raises(::Operations::PaymentGateway::InvalidOrder) do
              ::PayrexxPayment::CreatePayment.run!(order_id: fetch(:order).uuid)
            end

            assert_not_requested :post, GATEWAY_BASE_URL
          end
        end

        def test_deletes_previous_gateway
          setup_payrexx_order
          stub_get_gateway(42, status: 'waiting')
          delete = stub_delete_gateway(42)
          stub_create_gateway(id: 43)

          ::PayrexxPayment::CreatePayment.run!(order_id: fetch(:order).uuid)

          assert_requested delete
          assert_equal '43', fetch(:order).reload.payment_gateway_payment_id
        end

        def test_previous_payment_still_in_progress
          setup_payrexx_order
          stub_get_gateway(42, status: 'waiting')
          stub_transactions({ id: 7, status: 'confirmed' })

          assert_raises(::PayrexxPayment::PaymentPending) do
            ::PayrexxPayment::CreatePayment.run!(order_id: fetch(:order).uuid)
          end

          assert_not_requested :post, GATEWAY_BASE_URL
          assert_equal '42', fetch(:order).reload.payment_gateway_payment_id
        end

        def test_previous_gateway_already_paid
          setup_payrexx_order
          stub_get_gateway(42)

          op = ::PayrexxPayment::CreatePayment.run!(order_id: fetch(:order).uuid)

          assert op.already_paid
          assert_nil op.gateway_url
          assert_predicate fetch(:order).reload, :paid?
          assert_not_requested :post, GATEWAY_BASE_URL
        end

        def test_api_error_fails_cleanly
          setup_payrexx_order(gateway_id: nil)
          stub_request(:post, GATEWAY_BASE_URL).with(query: { instance: 'vseth' })
                                               .to_return(json_response({ status: 'error', message: 'Internal error' }, code: 500))

          assert_create_fails
        end

        def test_empty_response_fails_cleanly
          setup_payrexx_order(gateway_id: nil)
          stub_request(:post, GATEWAY_BASE_URL).with(query: { instance: 'vseth' })
                                               .to_return(json_response({ status: 'success', data: [] }))

          assert_create_fails
        end

        def test_unreachable_payrexx_fails_cleanly
          setup_payrexx_order(gateway_id: nil)
          stub_request(:post, GATEWAY_BASE_URL).with(query: { instance: 'vseth' }).to_timeout

          assert_create_fails
        end

        private

        def assert_create_fails
          assert_raises(::PayrexxPayment::ExecutionFailed) do
            ::PayrexxPayment::CreatePayment.run!(order_id: fetch(:order).uuid)
          end

          assert_nil fetch(:order).reload.payment_gateway_payment_id
        end
      end
    end
  end
end
