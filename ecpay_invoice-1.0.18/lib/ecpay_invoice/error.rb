module ECpayErrorDefinition
  # Generic ECpay exception class.
  class ECpayError < StandardError; end
  class ECpayMissingOption < ECpayError; end
  class ECpayInvalidMode < ECpayError; end
  class ECpayInvalidParam < ECpayError; end
    class ECpayInvoiceRuleViolate < ECpayError; end
end