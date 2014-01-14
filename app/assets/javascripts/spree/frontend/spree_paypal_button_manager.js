//= require spree/frontend

SpreePaypalButton = {
  hidePaymentSaveAndContinueButton: function(paymentMethod) {
    if (SpreePaypalButton.paymentMethodID && paymentMethod.val() == SpreePaypalButton.paymentMethodID) {
      $('.continue').hide();
    } else {
      $('.continue').show();
    }
  }
}

$(document).ready(function() {
  checkedPaymentMethod = $('div[data-hook="checkout_payment_step"] input[type="radio"]:checked');
  SpreePaypalButton.hidePaymentSaveAndContinueButton(checkedPaymentMethod);
  paymentMethods = $('div[data-hook="checkout_payment_step"] input[type="radio"]').click(function (e) {
    SpreePaypalButton.hidePaymentSaveAndContinueButton($(e.target));
  });
})
