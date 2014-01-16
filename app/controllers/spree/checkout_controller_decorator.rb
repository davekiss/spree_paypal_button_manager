Spree::CheckoutController.class_eval do

  def paypal_button

    body = "mc_gross=151.11&protection_eligibility=Ineligible&payer_id=XNJKH2AHQVA6E&tax=13.11&payment_date=15%3A03%3A30+Jan+16%2C+2014+PST&payment_status=Completed&charset=windows-1252&first_name=Edward&mc_fee=4.68&notify_version=3.7&custom=R370140155&payer_status=verified&business=nick-facilitator%40greyscalegorilla.com&quantity=1&verify_sign=AFcWxV21C7fd0v3bYYYRCpSSRl31AWJTqWotBk7xsVLikQjispwHKqIw&payer_email=customer%40greyscalegorilla.com&txn_id=66810255SX5173730&payment_type=instant&last_name=Shitman&receiver_email=nick-facilitator%40greyscalegorilla.com&payment_fee=4.68&receiver_id=3X3A4MUBZH6ZS&txn_type=web_accept&item_name=Greyscalegorilla+Purchase&mc_currency=USD&item_number=&residence_country=US&test_ipn=1&handling_amount=0.00&transaction_subject=R370140155&payment_gross=151.11&shipping=0.00&ipn_track_id=7ae77f30c834d"

    @api = ::PayPal::SDK::Merchant.new
    if @api.ipn_valid?(body)  # return true or false
      # params contains the data
      # check that paymentStatus=Completed
      # check that txnId has not been previously processed
      # check that receiverEmail is your Primary PayPal email
      # check that paymentAmount/paymentCurrency are correct
      # process payment
      binding.pry
    else
      # log for inspection
    end

    create_button
  end

  private
    def create_button
      pp_request = provider.build_bm_create_button({
        :ButtonType => "BUYNOW",
        :ButtonCode => "ENCRYPTED",
        :ButtonSubType => "PRODUCTS",
        :ButtonSource => "Vimeography_SP",
        :ButtonCountry => "US",
        :ButtonImageURL => "https://www.paypalobjects.com/webstatic/mktg/merchant/images/express-checkout-hero.png",
        :ButtonVar  => [
          "return=" + confirm_paypal_url(:payment_method_id => payment_method.id, :utm_nooverride => 1),
          "cancel_return=" + cancel_paypal_url,
          "notify_url=" + notify_paypal_url,
          #"notify_url=http://requestb.in/1axq1gl1",
          "item_name=Greyscalegorilla Purchase",
          "amount=#{current_order.total}",
          "subtotal=#{current_order.total}",
          "nonote=1",
          "bn=Vimeography_SP",
          "charset=utf-8",
          "no_shipping=1",
          "custom=#{current_order.number}"
        ]
      })

      begin
        pp_response = provider.bm_create_button(pp_request)
        if pp_response.success?
          return pp_response.Email
        else
          flash[:error] = "PayPal failed. #{pp_response.errors.map(&:long_message).join(" ")}"
        end
      rescue SocketError
        flash[:error] = "Could not connect to PayPal."
      end
    end

    def payment_method
      Spree::PaymentMethod.find_by!(type: "Spree::Gateway::PayPalButton")
    end

    def provider
      payment_method.provider
    end

  helper_method :paypal_button
end