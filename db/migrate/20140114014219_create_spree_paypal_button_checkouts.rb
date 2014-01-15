class CreateSpreePaypalButtonCheckouts < ActiveRecord::Migration
  def change
    create_table :spree_paypal_button_checkouts do |t|
      t.string :token
      t.string :payer_id
      t.string :transaction_id
      t.string :state
      t.string :refund_transaction_id
      t.datetime :refunded_at
      t.string :refund_type
      t.datetime :created_at
    end
  end
end
