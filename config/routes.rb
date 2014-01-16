Spree::Core::Engine.add_routes do
  post '/paypal', :to => "paypal_button#button", :as => :paypal_button
  get '/paypal/confirm', :to => "paypal_button#confirm", :as => :confirm_paypal
  get '/paypal/cancel', :to => "paypal_button#cancel", :as => :cancel_paypal
  get '/paypal/notify', :to => "paypal_button#notify", :as => :notify_paypal

  namespace :admin do
    # Using :only here so it doesn't redraw those routes
    resources :orders, :only => [] do
      resources :payments, :only => [] do
        member do
          get 'paypal_refund'
          post 'paypal_refund'
        end
      end
    end
  end
end