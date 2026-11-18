import StripeModels

/// Extracts the customer reference from the lossless customer enums the
/// generated models use (`charge.customer`, `setupIntent.customer`, ...).
/// Each carries either a bare ID string or an expanded customer object.
func paymentCustomerID(_ customer: ChargeCustomer) -> String {
  switch customer {
  case .string(let id): return id
  case .customer(let customer): return customer.id
  case .deletedCustomer(let deleted): return deleted.id
  case .other: return "—"
  }
}

func paymentCustomerID(_ customer: SetupIntentCustomer) -> String {
  switch customer {
  case .string(let id): return id
  case .customer(let customer): return customer.id
  case .deletedCustomer(let deleted): return deleted.id
  case .other: return "—"
  }
}

func paymentCustomerID(_ customer: PaymentIntentCustomer) -> String {
  switch customer {
  case .string(let id): return id
  case .customer(let customer): return customer.id
  case .deletedCustomer(let deleted): return deleted.id
  case .other: return "—"
  }
}
