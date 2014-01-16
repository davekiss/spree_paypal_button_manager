Spree::CheckoutController.class_eval do

  def paypal_button
      require 'paypal-sdk-buttonmanager'
    provider = PayPal::SDK::ButtonManager::API.new
    pp_request = provider.build_bm_create_button({
      :ButtonType => "BUYNOW",
      :ButtonCode => "ENCRYPTED",
      :ButtonImageUrl => "https://www.paypalobjects.com/webstatic/mktg/merchant/images/express-checkout-hero.png",

      :ButtonVar  => [
        "return=" + confirm_paypal_url(:payment_method_id => 1, :utm_nooverride => 1),
        "cancel_return=" + cancel_paypal_url,
        "item_name=Greyscalegorilla Purchase",
        "amount=#{current_order.total}",
        "subtotal=#{current_order.total}"
      ]
    })

    begin
      pp_response = provider.bm_create_button(pp_request)
      if pp_response.success?
        return pp_response.Website
      else
        flash[:error] = "PayPal failed. #{pp_response.errors.map(&:long_message).join(" ")}"
        redirect_to checkout_state_path(:payment)
      end
    rescue SocketError
      flash[:error] = "Could not connect to PayPal."
    end
  end


  helper_method :paypal_button
end