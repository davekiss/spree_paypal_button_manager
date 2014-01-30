require 'paypal-sdk-merchant'
require 'paypal-sdk-buttonmanager'
module Spree
  class Gateway::PayPalButton < Gateway
    preference :login, :string
    preference :password, :string
    preference :signature, :string
    preference :server, :string, default: 'sandbox'

    def supports?(source)
      true
    end

    def provider_class
      ::PayPal::SDK::ButtonManager::API
    end

    def merchant_class
      ::PayPal::SDK::Merchant::API
    end

    def provider
      configure
      provider_class.new
    end

    def merchant
      configure
      merchant_class.new
    end

    def configure
      ::PayPal::SDK.configure(
        :mode      => preferred_server.present? ? preferred_server : "sandbox",
        :username  => preferred_login,
        :password  => preferred_password,
        :signature => preferred_signature)
    end

    def auto_capture?
      true
    end

    def method_type
      'paypal_button'
    end

    def purchase(amount, paypal_button, gateway_options={})
      # This is rather hackish, required for payment/processing handle_response code.
      Class.new do
        def success?; true; end
        def authorization; nil; end
      end.new
    end

    # Probably doesn't work
    def refund(payment, amount)
      refund_type = payment.amount == amount.to_f ? "Full" : "Partial"
      refund_transaction = provider.build_refund_transaction({
        :TransactionID => payment.source.transaction_id,
        :RefundType => refund_type,
        :Amount => {
          :currencyID => payment.currency,
          :value => amount },
        :RefundSource => "any" })
      refund_transaction_response = provider.refund_transaction(refund_transaction)
      if refund_transaction_response.success?
        payment.source.update_attributes({
          :refunded_at => Time.now,
          :refund_transaction_id => refund_transaction_response.RefundTransactionID,
          :state => "refunded",
          :refund_type => refund_type
        })
      end
      refund_transaction_response
    end
  end
end

#   payment.state = 'completed'
#   current_order.state = 'complete'