//= require spree/backend

SpreePaypalButton = {
  hideSettings: function(paymentMethod) {
    if (SpreePaypalButton.paymentMethodID && paymentMethod.val() == SpreePaypalButton.paymentMethodID) {
      $('.payment-method-settings').children().hide();
      $('#payment_amount').prop('disabled', 'disabled');
      $('button[type="submit"]').prop('disabled', 'disabled');
      $('#paypal-warning').show();
    } else if (SpreePaypalButton.paymentMethodID) {
      $('.payment-method-settings').children().show();
      $('button[type=submit]').prop('disabled', '');
      $('#payment_amount').prop('disabled', '')
      $('#paypal-warning').hide();
    }
  }
}

$(document).ready(function() {
  checkedPaymentMethod = $('[data-hook="payment_method_field"] input[type="radio"]:checked');
  SpreePaypalButton.hideSettings(checkedPaymentMethod);
  paymentMethods = $('[data-hook="payment_method_field"] input[type="radio"]').click(function (e) {
    SpreePaypalButton.hideSettings($(e.target));
  });
})