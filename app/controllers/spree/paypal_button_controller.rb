module Spree
  class PaypalButtonController < StoreController
    skip_before_action :verify_authenticity_token

    def confirm
      order = Spree::Order.find_by!(number: ipn_params[:custom])
      if order.completed?
        session[:order_id] = nil
        flash.notice = Spree.t(:order_processed_successfully)
        flash[:commerce_tracking] = "nothing special"
        redirect_to order_path(order, :token => order.token)
      else
        redirect_to checkout_state_path(order.state)
      end
    end

    def notify
      logger.info "Raw Request: #{request.raw_post.inspect}"
      if provider.ipn_valid?(request.raw_post)
        logger.info "IPN Params: #{ipn_params.inspect}"
        # Get Order from Custom passed param
        @order = Spree::Order.find_by!(number: ipn_params[:custom])

        if payment_is_valid?
          add_bill_address_from_ipn
          @order.create_tax_charge! if eligible_for_tax_charge?

          @order.email = ipn_params[:payer_email]
          @order.payments.create!({
            source: Spree::PaypalButtonCheckout.create({
              transaction_id: ipn_params[:txn_id],
              payer_id: ipn_params[:payer_id]
            }),
            amount: @order.total,
            payment_method: payment_method
          })
          @order.next
        end
      else
        # log for inspection
        logger.info "Invalid IPN for Order: #{@order.inspect}"
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

      def merchant
        payment_method.merchant
      end

      def provider
        payment_method.provider
      end

      def ipn_params
        # https://gist.github.com/davekiss/9aabb1ae3bda1ce6d9da
        params.permit(
          :payment_status,
          :payment_gross,
          :receiver_email,
          :payer_email,
          :mc_currency,
          :tax,
          :payer_id,
          :txn_id,
          :custom,
          :address_city,
          :address_state,
          :address_zip,
          :address_country_code,
          :address_street,
          :first_name,
          :last_name,
          :payer_business_name
        )
      end

      def payment_is_valid?
        # @todo: check that txnId has not been previously processed
        logger.info "Is completed? #{is_completed?}"
        logger.info "is_correct_amount? #{is_correct_amount?}"
        logger.info "is_correct_business? #{is_correct_business?}"
        logger.info "is_correct_currency? #{is_correct_currency?}"
        is_completed? && is_correct_amount? && is_correct_business? && is_correct_currency?
      end

      def is_completed?
        ipn_params[:payment_status] == "Completed"
      end

      def is_correct_amount?
        ( BigDecimal.new( ipn_params[:payment_gross] ) - BigDecimal( ipn_params[:tax] ) ) == @order.total
      end

      def is_correct_business?
        if Rails.env.production?
          ipn_params[:receiver_email] == 'nick@greyscalegorilla.com'
        else
          ipn_params[:receiver_email] == 'nick-facilitator@greyscalegorilla.com'
        end
      end

      def is_correct_currency?
        ipn_params[:mc_currency] == "USD"
      end

      def add_bill_address_from_ipn
        address = {
          firstname:  ipn_params[:first_name],
          lastname:   ipn_params[:last_name],
          address1:   ipn_params[:address_street],
          city:       ipn_params[:address_city],
          zipcode:    ipn_params[:address_zip],
          country:    Spree::Country.find_by!(iso: ipn_params[:address_country_code] )
        }

        if address[:country].iso == 'US'
          address[:state] = Spree::State.find_by!(abbr: ipn_params[:address_state] )
        else
          address[:state_name] = ipn_params[:address_state].present? ? ipn_params[:address_state] : '-'
        end

        address[:company] = ipn_params[:payer_business_name] if ipn_params[:payer_business_name].present?

        @order.build_bill_address(address) unless has_blank? address
      end

      def has_blank? address
        address.values.any?{|v| v.nil? || v == ''}
      end

      def eligible_for_tax_charge?
        ipn_params[:tax] != "0.00" && ipn_params[:address_state] == "IL" && @order.bill_address.present?
      end

  end
end