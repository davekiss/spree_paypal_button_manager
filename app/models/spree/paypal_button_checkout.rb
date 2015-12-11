module Spree
  class PaypalButtonCheckout < ActiveRecord::Base
    def actions
      %w{credit}
    end
  end
end