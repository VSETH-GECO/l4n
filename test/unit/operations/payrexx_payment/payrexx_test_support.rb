# Shared setup and Payrexx API stubs (via WebMock) for the Payrexx payment gateway tests
module PayrexxTestSupport
  GATEWAY_BASE_URL = 'https://api.payrexx.com/v1.19/Gateway/'.freeze

  # Product price 19.99, quantity 2 => order total of 39.98
  ORDER_TOTAL_CENTS = 3998

  def setup_payrexx_order(cleanup_timestamp: Time.zone.now, gateway_id: '42')
    store :user, create_user

    create_product_category

    store :product, create_product(inventory: 10)
    store :variant, create_product_variant(fetch(:product), price: Money.new(1999))

    store :order, create_order(fetch(:user), 'payment_pending')
    create_order_item(fetch(:order), fetch(:variant), quantity: 2)

    fetch(:order).update!(
      cleanup_timestamp:          cleanup_timestamp,
      payment_gateway_name:       gateway_id && ::PayrexxPayment::GATEWAY_NAME,
      payment_gateway_payment_id: gateway_id
    )

    # Reload, such that the order_items association isn't cached as empty
    fetch(:order).reload
  end

  def stub_get_gateway(id, status: 'confirmed', amount: ORDER_TOTAL_CENTS, currency: 'CHF', reference_id: fetch(:order).uuid)
    gateway = { id: id.to_i, status: status, referenceId: reference_id, amount: amount, currency: currency }

    stub_request(:get, "#{GATEWAY_BASE_URL}#{id}/")
      .with(query: { instance: 'vseth' }, headers: { 'X-API-KEY' => payrexx_api_key })
      .to_return(json_response({ status: 'success', data: [gateway] }))
  end

  def stub_get_gateway_not_found(id)
    stub_request(:get, "#{GATEWAY_BASE_URL}#{id}/")
      .with(query: { instance: 'vseth' })
      .to_return(json_response({ status: 'error', message: "No Gateway found with id #{id}" }, code: 404))
  end

  def stub_get_gateway_error(id)
    stub_request(:get, "#{GATEWAY_BASE_URL}#{id}/")
      .with(query: { instance: 'vseth' })
      .to_return(json_response({ status: 'error', message: 'Internal error' }, code: 500))
  end

  def stub_delete_gateway(id, code: 200)
    stub_request(:delete, "#{GATEWAY_BASE_URL}#{id}/")
      .with(query: { instance: 'vseth' }, headers: { 'X-API-KEY' => payrexx_api_key })
      .to_return(json_response({ status: code == 200 ? 'success' : 'error', data: [{ id: id.to_i }] }, code: code))
  end

  def stub_create_gateway(id:, link: "https://vseth.payrexx.com/?payment=#{id}")
    stub_request(:post, GATEWAY_BASE_URL)
      .with(query: { instance: 'vseth' }, headers: { 'X-API-KEY' => payrexx_api_key })
      .to_return(json_response({ status: 'success', data: [{ id: id.to_i, status: 'waiting', link: link }] }))
  end

  def assert_not_paid
    assert_raises(::PayrexxPayment::ExecutionFailed) do
      ::PayrexxPayment::ExecutePayment.run!(order_id: fetch(:order).uuid)
    end

    assert_not fetch(:order).reload.paid?
    assert_equal 10, fetch(:product).reload.inventory
  end

  private

  def payrexx_api_key
    Figaro.env.payrexx_api_key!
  end

  def json_response(body, code: 200)
    { status: code, body: body.to_json, headers: { 'Content-Type' => 'application/json' } }
  end
end
