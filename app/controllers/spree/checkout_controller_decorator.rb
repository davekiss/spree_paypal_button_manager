Spree::CheckoutController.class_eval do

  def paypal_button
    create_button
  end

  private
    def create_button
      pp_request = provider.build_bm_create_button({
        :ButtonType     => "BUYNOW",
        :ButtonCode     => "ENCRYPTED",
        :ButtonSubType  => "PRODUCTS",
        :ButtonCountry  => "US",
        :ButtonImageURL => button_image_url,
        :ButtonVar  => [
          "return=" + confirm_paypal_url(:payment_method_id => payment_method.id, :utm_nooverride => 1),
          "rm=1",
          "cancel_return=" + cancel_paypal_url,
          "notify_url=" + notify_paypal_url,
          #"notify_url=http://requestb.in/1axq1gl1",
          "item_name=Greyscalegorilla Purchase",
          "amount=#{current_order.total}",
          "subtotal=#{current_order.total}",
          "nonote=1",
          "bn=Vimeography_SP",
          "charset=utf-8",
          "no_shipping=2",
          "address_override=0",
          "custom=#{current_order.number}"
        ]
      })

      begin
        pp_response = provider.bm_create_button(pp_request)
        if pp_response.success?
          return pp_response.Website
        else
          flash[:error] = "PayPal failed. #{pp_response.errors.map(&:long_message).join(" ")}"
        end
      rescue SocketError
        flash[:error] = "Could not connect to PayPal."
      end
    end

    def button_image_url
      Rails.env.development? ? 'http://i.imgur.com/UTEy7IZ.png' : view_context.image_url('spree/frontend/pay-with-paypal.png')
    end

    def payment_method
      Spree::PaymentMethod.find_by!(type: "Spree::Gateway::PayPalButton")
    end

    def provider
      payment_method.provider
    end

  helper_method :paypal_button
end