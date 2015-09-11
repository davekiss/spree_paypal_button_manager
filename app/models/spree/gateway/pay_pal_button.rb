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

    def credit(credit_cents, response_code, event)
      payment = event[:originator].payment
      reimbursement = event[:originator].reimbursement

      refund_type = (payment.amount * 100).to_i == credit_cents ? "Full" : "Partial"

      transaction = {
        :TransactionID     => payment.source.transaction_id,
        :PayerID           => payment.source.payer_id,
        :InvoiceID         => payment.order.number,
        :RefundType        => refund_type,
        :RefundSource      => "any",
        :Memo              => event[:originator].reason.name,
        :RefundItemDetails => refund_items(reimbursement),
        :MsgSubID => ('a'..'z').to_a.shuffle[0,8].join
      }

      # Only set refund amount if partial transaction
      if refund_type == "Partial"
        transaction[:Amount] = {
          :currencyID => payment.currency,
          :value      => '%.2f' % reimbursement.total
        }
      end

      refund_transaction = merchant.build_refund_transaction(transaction)
      refund_transaction_response = merchant.refund_transaction(refund_transaction)

      # [2] pry(#<Spree::Gateway::PayPalButton>)> refund_transaction_response
      # => #<PayPal::SDK::Merchant::DataTypes::RefundTransactionResponseType:0x007fb7813ca560
      #  @Ack="Success",
      #  @Build="000000",
      #  @CorrelationID="806cdcc8ae9fc",
      #  @FeeRefundAmount=#<PayPal::SDK::Merchant::DataTypes::BasicAmountType:0x007fb7813c9340 @currencyID="USD", @value="1.87">,
      #  @GrossRefundAmount=#<PayPal::SDK::Merchant::DataTypes::BasicAmountType:0x007fb7813c8e68 @currencyID="USD", @value="64.50">,
      #  @MsgSubID="vndfspmt",
      #  @NetRefundAmount=#<PayPal::SDK::Merchant::DataTypes::BasicAmountType:0x007fb7813c96b0 @currencyID="USD", @value="62.63">,
      #  @RefundInfo=#<PayPal::SDK::Merchant::DataTypes::RefundInfoType:0x007fb7813c8670 @PendingReason="none", @RefundStatus="Instant">,
      #  @RefundTransactionID="64099041HJ4472300",
      #  @Timestamp=Fri, 11 Sep 2015 18:42:46 +0000,
      #  @TotalRefundedAmount=#<PayPal::SDK::Merchant::DataTypes::BasicAmountType:0x007fb7813c8ad0 @currencyID="USD", @value="64.50">,
      #  @Version="106.0">

      if refund_transaction_response.success?
        payment.source.update_attributes({
          :refunded_at => Time.now,
          :refund_transaction_id => refund_transaction_response.RefundTransactionID,
          :state => "refunded",
          :refund_type => refund_type
        })
      end

      # https://github.com/activemerchant/active_merchant/blob/86e84518d591bc9435b86e6505c509be822960c0/lib/active_merchant/billing/response.rb
      return ActiveMerchant::Billing::Response.new(
        refund_transaction_response.success?,
        refund_transaction_response.errors.map(&:long_message).join(" ")
      )
    end

    private

      def refund_items(reimbursement)
        items = []
        reimbursement.return_items.each do |return_item|
          line_item = return_item.inventory_unit.line_item
          variant   = return_item.inventory_unit.variant

          items << {
            :Name => variant.name,
            :SKU  => variant.sku,
            :Price => {
              :currencyID => line_item.currency,
              :value      => '%.2f' % return_item.pre_tax_amount
            },
            :ItemCount => line_item.quantity,
            :Discount  => refund_item_discounts(line_item),
            :Taxable   => reimbursement.order.tax_zone.present?
          }
        end
        items
      end

      def refund_item_discounts(line_item)
        discounts = []
        line_item.adjustments.eligible.each do |adj|
          discounts << {
            :Name    => adj.label,
            :Amount  => {
              :currencyID => adj.currency,
              :value      => '%.2f' % adj.amount.to_f.abs
            }
          }
        end
        discounts
      end

  end
end