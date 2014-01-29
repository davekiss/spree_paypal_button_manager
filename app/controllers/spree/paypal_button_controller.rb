module Spree
  class PaypalButtonController < StoreController
    skip_before_action :verify_authenticity_token, only: [:notify]

    def confirm
      order = current_order
      if order.complete?
        flash.notice = Spree.t(:order_processed_successfully)
        flash[:commerce_tracking] = "nothing special"
        redirect_to order_path(order)
      else
        redirect_to checkout_state_path(order.state)
      end
    end

    def notify
      logger.info "Heroku logging enabled"
      logger.info "Request post: #{request.raw_post.inspect}"
      if provider.ipn_valid?(request.raw_post)  # return true or false
        logger.info "IPN is valid"
        logger.info "IPN Params: #{ipn_params.inspect}"

        @order = Spree::Order.find_by!(number: ipn_params[:custom])
        logger.info "Order is #{@order.inspect}"
        if payment_is_valid?
          logger.info "Payment is valid"

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
        logger.info "Raw request for invalid IPN: #{request.raw_post.inspect}"
        logger.info "Order: #{@order.inspect}"
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

      def ipn_params
        # https://gist.github.com/davekiss/9aabb1ae3bda1ce6d9da
        params.permit(:payment_status, :payment_gross, :receiver_email, :payer_email, :mc_currency, :tax, :payer_id, :txn_id, :custom)
      end

      def payment_is_valid?
        # @todo: check that txnId has not been previously processed
        is_completed? && is_correct_amount? && is_correct_business? && is_correct_currency?
        logger.info "Is completed? #{is_completed?}"
        logger.info "Is is_correct_amount? #{is_correct_amount?}"
        logger.info "Is is_correct_business? #{is_correct_business?}"
        logger.info "Is is_correct_currency? #{is_correct_currency?}"
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

  end
end