module Spree
  class PaypalButtonController < StoreController

    def confirm
      binding.pry
      order = current_order
      order.payments.create!({
        :source => Spree::PaypalExpressCheckout.create({
          :token => params[:token],
          :payer_id => params[:PayerID]
        }),
        :amount => order.total,
        :payment_method => payment_method
      })
      order.next
      if order.complete?
        flash.notice = Spree.t(:order_processed_successfully)
        flash[:commerce_tracking] = "nothing special"
        redirect_to order_path(order, :token => order.token)
      else
        redirect_to checkout_state_path(order.state)
      end
    end

    def notify
      @api = PayPal::SDK::Merchant.new
      if @api.ipn_valid?(request.raw_post)  # return true or false
        # params contains the data
        # check that paymentStatus=Completed
        # check that txnId has not been previously processed
        # check that receiverEmail is your Primary PayPal email
        # check that paymentAmount/paymentCurrency are correct
        # process payment
      else
        # log for inspection
      end
      render :nothing => true
    end

    def cancel
      flash[:notice] = "Don't want to use PayPal? No problem."
      redirect_to checkout_state_path(current_order.state)
    end

    private

      def payment_method
        Spree::PaymentMethod.find_by!(type: "Spree::Gateway::PayPalButton")
      end

      def provider
        payment_method.provider
      end

  end
end