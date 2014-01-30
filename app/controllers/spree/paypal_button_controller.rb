module Spree
  class PaypalButtonController < StoreController
    skip_before_action :verify_authenticity_token

    def confirm
      order = Spree::Order.find_by!(number: ipn_params[:custom])
      if order.complete?
        flash.notice = Spree.t(:order_processed_successfully)
        flash[:commerce_tracking] = "nothing special"
        redirect_to order_path(order, :token => order.token)
      else
        redirect_to checkout_state_path(order.state)
      end
    end

    def notify
      logger.info "Raw Request: #{request.raw_post.inspect}"

      if provider.ipn_valid?(request.raw_post)  # return true or false
        logger.info "IPN Params: #{ipn_params.inspect}"

        # Get Order from Custom passed param
        @order = Spree::Order.find_by!(number: ipn_params[:custom])
        logger.info "Order is #{@order.inspect}"

        if payment_is_valid?
          create_tax_adjustment if ipn_params[:tax] != "0.00"

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
        params.permit(:payment_status, :payment_gross, :receiver_email, :payer_email, :mc_currency, :tax, :payer_id, :txn_id, :custom)
      end

      def payment_is_valid?
        # @todo: check that txnId has not been previously processed
        is_completed? && is_correct_amount? && is_correct_business? && is_correct_currency?
        logger.info "Is completed? #{is_completed?}"
        logger.info "is_correct_amount? #{is_correct_amount?}"
        logger.info "is_correct_business? #{is_correct_business?}"
        logger.info "is_correct_currency? #{is_correct_currency?}"
      end

      def is_completed?
        ipn_params[:payment_status] == "Completed"
      end

      def is_correct_amount?
        ( BigDecimal.new( ipn_params[:payment_gross] ) - BigDecimal( ipn_params[:tax] ) ) == @order.total
      end

      def is_correct_business?
        ipn_params[:receiver_email] == 'nick-facilitator@greyscalegorilla.com'
      end

      def is_correct_currency?
        ipn_params[:mc_currency] == "USD"
      end

      def create_tax_adjustment
        pp_request = merchant.build_get_transaction_details({
          :TransactionID => ipn_params[:txn_id] })

        begin
          @pp_response = merchant.get_transaction_details(pp_request)
          if @pp_response.success?
            logger.info "Payment TXN Details: #{@pp_response.PaymentTransactionDetails.inspect}"
            payer_address = @pp_response.PaymentTransactionDetails.PayerInfo.Address
            payer_name    = @pp_response.PaymentTransactionDetails.PayerInfo.PayerName

            bill_address  = @order.build_bill_address({
              city:      payer_address.try(:CityName), 
              state:     Spree::State.find_by!(abbr: "IL"),
              zipcode:   payer_address.try(:PostalCode), 
              country:   Spree::Country.find_by!(iso: "US"),
              firstname: payer_name.try(:FirstName),
              lastname:  payer_name.try(:LastName),
              address1:  payer_address.try(:Street1)
            })

            create_tax_charge! if bill_address.valid?
            logger.info "Order Adjustments: #{@order.all_adjustments.inspect}"
          else
            logger.info "TXN Errors: #{@pp_response.Errors.inspect}"
          end
        rescue SocketError
        end
      end

  end
end