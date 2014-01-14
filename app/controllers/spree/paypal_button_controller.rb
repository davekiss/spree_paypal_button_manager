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

    def cancel
      flash[:notice] = "Don't want to use PayPal? No problems."
      redirect_to checkout_state_path(current_order.state)
    end

    private

      def payment_method
        Spree::PaymentMethod.find_by!(name: "PayPal Express")
      end

      def provider
        payment_method.provider
      end

  end
end