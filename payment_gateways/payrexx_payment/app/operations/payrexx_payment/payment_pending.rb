module PayrexxPayment
  # A payment for the order has been started but isn't confirmed (or aborted) yet
  class PaymentPending < ExecutionFailed; end
end
