// PaymentsWrite.swift — Sources/GeistData
// Money-affecting payment writes (refunds, captures, intent lifecycle).
//
// Three gates stand between a user action and Stripe:
//   1. The UI only builds a writer for accounts that are not dashboard-locked
//      (belt).
//   2. This service refuses to run when the client is in dashboard mode,
//      before anything else happens (suspenders), and records the refusal in
//      the audit log.
//   3. The client itself refuses every non-GET request in dashboard mode
//      before anything reaches the network (floor).
//
// Every request carries an idempotency key — the same key that appears in
// the audit entry, so a retry after an unclear failure repeats exactly one
// request, not two.

import Foundation
import StripeClient
import StripeModels

public enum PaymentsWriteError: LocalizedError, Equatable {
  /// The service was asked to write while the client is in dashboard mode.
  case dashboardMode

  public var errorDescription: String? {
    switch self {
    case .dashboardMode:
      return "Dashboard mode is read-only. Unlock the account to make changes."
    }
  }
}

public struct PaymentsWriteService: Sendable {
  /// Reads the account's CURRENT dashboard-lock state. Called before every
  /// write so locking an account mid-session closes it immediately, even if
  /// this writer was built while the account was unlocked.
  public typealias DashboardLockProvider = @MainActor @Sendable () async -> Bool

  public let client: StripeClient
  public let accountID: String
  public let accountName: String
  public let audit: any AuditStore
  private let dashboardLocked: DashboardLockProvider

  public init(
    client: StripeClient, accountID: String, accountName: String, audit: any AuditStore,
    dashboardLocked: @escaping DashboardLockProvider = { false }
  ) {
    self.client = client
    self.accountID = accountID
    self.accountName = accountName
    self.audit = audit
    self.dashboardLocked = dashboardLocked
  }

  /// Runs one write: refuses in dashboard mode, performs the request with
  /// an idempotency key, records the outcome, and decodes the response.
  private func run<Response: Decodable>(
    _ type: Response.Type,
    method: String,
    path: String,
    params: (some Encodable)?,
    key: String,
    summary: String
  ) async throws -> Response {
    // Gate 2: refuse before anything else — both when the client was built
    // in dashboard mode and when the account is locked right now.
    var locked = client.mode == .dashboard
    if !locked { locked = await dashboardLocked() }
    guard !locked else {
      await audit.record(
        AuditEntry(
          accountID: accountID,
          accountName: accountName,
          summary: summary,
          method: method,
          path: path,
          idempotencyKey: key,
          outcome: "refused: dashboard mode"
        ))
      throw PaymentsWriteError.dashboardMode
    }
    do {
      let outcome = try await client.perform(
        method: method, path: path, params: params, idempotencyKey: key)
      let decoded: Response
      do {
        decoded = try StripeClient.decoder.decode(Response.self, from: outcome.body)
      } catch {
        throw StripeClientError.decodingFailed(underlying: error, path: path)
      }
      await audit.record(
        AuditEntry(
          accountID: accountID,
          accountName: accountName,
          summary: summary,
          method: method,
          path: path,
          idempotencyKey: key,
          requestID: outcome.requestId,
          outcome: "succeeded"
        ))
      return decoded
    } catch {
      let message: String
      if let apiError = error as? StripeAPIError {
        message = apiError.description
      } else if let local = error as? LocalizedError, let desc = local.errorDescription {
        message = desc
      } else {
        message = String(describing: error)
      }
      await audit.record(
        AuditEntry(
          accountID: accountID,
          accountName: accountName,
          summary: summary,
          method: method,
          path: path,
          idempotencyKey: key,
          outcome: "failed: \(message)"
        ))
      throw error
    }
  }

  private static func key() -> String { UUID().uuidString }

  // MARK: - Refunds

  /// Creates a refund on a charge. `amount == nil` refunds the full
  /// remaining amount; `reason` is one of duplicate, fraudulent,
  /// requested_by_customer, or nil.
  public func createRefund(
    charge: String, amount: Int?, reason: String?, summary: String
  ) async throws -> Refund {
    var params = RefundCreateParams()
    params.charge = charge
    params.amount = amount
    if let reason {
      params.reason = TerminalReaderReaderResourceRefundPaymentActionReason(rawValue: reason)
    }
    return try await run(
      Refund.self, method: "POST", path: "/v1/refunds", params: params,
      key: Self.key(), summary: summary)
  }

  /// Replaces a refund's metadata.
  public func updateRefund(
    id: String, metadata: [String: String]?, summary: String
  ) async throws -> Refund {
    var params = RefundUpdateParams()
    if let metadata { params.metadata = .value(metadata) }
    return try await run(
      Refund.self, method: "POST", path: "/v1/refunds/\(id)", params: params,
      key: Self.key(), summary: summary)
  }

  /// Cancels a pending refund.
  public func cancelRefund(id: String, summary: String) async throws -> Refund {
    return try await run(
      Refund.self, method: "POST", path: "/v1/refunds/\(id)/cancel",
      params: RefundCancelParams(), key: Self.key(), summary: summary)
  }

  /// Expires a pending refund (test-mode helper endpoint).
  public func expireRefund(id: String, summary: String) async throws -> Refund {
    return try await run(
      Refund.self, method: "POST", path: "/v1/refunds/\(id)/expire",
      params: RefundExpireParams(), key: Self.key(), summary: summary)
  }

  // MARK: - Charges

  /// Captures an uncaptured charge. `amount == nil` captures the full
  /// authorized amount.
  public func captureCharge(
    id: String, amount: Int?, receiptEmail: String?, summary: String
  ) async throws -> Charge {
    var params = ChargeCaptureParams()
    params.amount = amount
    params.receiptEmail = receiptEmail
    return try await run(
      Charge.self, method: "POST", path: "/v1/charges/\(id)/capture", params: params,
      key: Self.key(), summary: summary)
  }

  /// Updates a charge's description, receipt email, and metadata.
  public func updateCharge(
    id: String, description: String?, receiptEmail: String?, metadata: [String: String]?,
    summary: String
  ) async throws -> Charge {
    var params = ChargeUpdateParams()
    params.description = description
    params.receiptEmail = receiptEmail
    if let metadata {
      params.metadata = .value(metadata)
    }
    return try await run(
      Charge.self, method: "POST", path: "/v1/charges/\(id)", params: params,
      key: Self.key(), summary: summary)
  }

  // MARK: - Payment intents

  /// Updates a payment intent's description and metadata.
  public func updatePaymentIntent(
    id: String, description: String?, metadata: [String: String]?, summary: String
  ) async throws -> PaymentIntent {
    var params = PaymentIntentUpdateParams()
    params.description = description
    if let metadata {
      params.metadata = .value(metadata)
    }
    return try await run(
      PaymentIntent.self, method: "POST", path: "/v1/payment_intents/\(id)",
      params: params, key: Self.key(), summary: summary)
  }

  /// Captures a manually-captured payment intent.
  public func capturePaymentIntent(
    id: String, amountToCapture: Int?, summary: String
  ) async throws -> PaymentIntent {
    var params = PaymentIntentCaptureParams()
    params.amountToCapture = amountToCapture
    return try await run(
      PaymentIntent.self, method: "POST", path: "/v1/payment_intents/\(id)/capture",
      params: params, key: Self.key(), summary: summary)
  }

  /// Cancels a payment intent. `reason` is one of abandoned, duplicate,
  /// fraudulent, requested_by_customer, or nil.
  public func cancelPaymentIntent(
    id: String, reason: String?, summary: String
  ) async throws -> PaymentIntent {
    var params = PaymentIntentCancelParams()
    if let reason {
      params.cancellationReason = PaymentIntentCancelParamsCancellationReason(rawValue: reason)
    }
    return try await run(
      PaymentIntent.self, method: "POST", path: "/v1/payment_intents/\(id)/cancel",
      params: params, key: Self.key(), summary: summary)
  }

  /// Confirms a payment intent.
  public func confirmPaymentIntent(
    id: String, summary: String
  ) async throws -> PaymentIntent {
    return try await run(
      PaymentIntent.self, method: "POST", path: "/v1/payment_intents/\(id)/confirm",
      params: PaymentIntentConfirmParams(), key: Self.key(), summary: summary)
  }

  /// Creates a payment intent with the sheet's base fields. `captureMethod`
  /// nil means Stripe's default (automatic).
  public func createPaymentIntent(
    amount: Int, currency: String, customer: String?, description: String?,
    captureMethod: PaymentIntentCaptureMethod?, summary: String
  ) async throws -> PaymentIntent {
    var params = PaymentIntentCreateParams(amount: amount, currency: currency)
    params.customer = customer
    params.description = description
    params.captureMethod = captureMethod
    return try await run(
      PaymentIntent.self, method: "POST", path: "/v1/payment_intents", params: params,
      key: Self.key(), summary: summary)
  }

  /// Manually reconciles a `customer_balance` payment intent: applies the
  /// customer's balance to it. `amount == nil` applies the remaining balance.
  public func applyCustomerBalancePaymentIntent(
    id: String, amount: Int?, currency: String?, summary: String
  ) async throws -> PaymentIntent {
    var params = PaymentIntentApplyCustomerBalanceParams()
    params.amount = amount
    params.currency = currency
    return try await run(
      PaymentIntent.self, method: "POST",
      path: "/v1/payment_intents/\(id)/apply_customer_balance", params: params,
      key: Self.key(), summary: summary)
  }

  /// Increments a manual-capture authorization to a new, higher total
  /// amount (the parameter is the new total, not the increase).
  public func incrementAuthorizationPaymentIntent(
    id: String, amount: Int, summary: String
  ) async throws -> PaymentIntent {
    var params = PaymentIntentIncrementAuthorizationParams(amount: amount)
    return try await run(
      PaymentIntent.self, method: "POST",
      path: "/v1/payment_intents/\(id)/increment_authorization", params: params,
      key: Self.key(), summary: summary)
  }

  /// Verifies microdeposits on a bank-debit intent: either the two deposit
  /// amounts in cents or the descriptor code from the statement.
  public func verifyMicrodepositsPaymentIntent(
    id: String, amounts: [Int]?, descriptorCode: String?, summary: String
  ) async throws -> PaymentIntent {
    var params = PaymentIntentVerifyMicrodepositsParams()
    params.amounts = amounts
    params.descriptorCode = descriptorCode
    return try await run(
      PaymentIntent.self, method: "POST",
      path: "/v1/payment_intents/\(id)/verify_microdeposits", params: params,
      key: Self.key(), summary: summary)
  }

  // MARK: - Setup intents

  /// Creates a setup intent. `usage` nil sends Stripe's default.
  public func createSetupIntent(
    customer: String?, description: String?, usage: String?, summary: String
  ) async throws -> SetupIntent {
    var params = SetupIntentCreateParams()
    params.customer = customer
    params.description = description
    if let usage { params.usage = ConfirmationTokenSetupFutureUsage(rawValue: usage) }
    return try await run(
      SetupIntent.self, method: "POST", path: "/v1/setup_intents", params: params,
      key: Self.key(), summary: summary)
  }

  /// Updates a setup intent's description.
  public func updateSetupIntent(
    id: String, description: String?, summary: String
  ) async throws -> SetupIntent {
    var params = SetupIntentUpdateParams()
    params.description = description
    return try await run(
      SetupIntent.self, method: "POST", path: "/v1/setup_intents/\(id)", params: params,
      key: Self.key(), summary: summary)
  }

  /// Cancels a setup intent. `reason` is one of abandoned, duplicate,
  /// requested_by_customer, or nil.
  public func cancelSetupIntent(
    id: String, reason: String?, summary: String
  ) async throws -> SetupIntent {
    var params = SetupIntentCancelParams()
    if let reason {
      params.cancellationReason = SetupIntentCancellationReason(rawValue: reason)
    }
    return try await run(
      SetupIntent.self, method: "POST", path: "/v1/setup_intents/\(id)/cancel", params: params,
      key: Self.key(), summary: summary)
  }

  /// Confirms a setup intent, optionally attaching a payment method ID.
  public func confirmSetupIntent(
    id: String, paymentMethod: String?, summary: String
  ) async throws -> SetupIntent {
    var params = SetupIntentConfirmParams()
    params.paymentMethod = paymentMethod
    return try await run(
      SetupIntent.self, method: "POST", path: "/v1/setup_intents/\(id)/confirm", params: params,
      key: Self.key(), summary: summary)
  }

  /// Verifies microdeposits on a bank-debit setup intent: either the two
  /// deposit amounts in cents or the descriptor code from the statement.
  public func verifyMicrodepositsSetupIntent(
    id: String, amounts: [Int]?, descriptorCode: String?, summary: String
  ) async throws -> SetupIntent {
    var params = SetupIntentVerifyMicrodepositsParams()
    params.amounts = amounts
    params.descriptorCode = descriptorCode
    return try await run(
      SetupIntent.self, method: "POST", path: "/v1/setup_intents/\(id)/verify_microdeposits",
      params: params, key: Self.key(), summary: summary)
  }

  // MARK: - Payment methods

  /// Creates a payment method. Tier-1 supports card details and type-only
  /// methods; deeper per-type fields stay for the API explorer (M10).
  public func createPaymentMethod(
    type: String, cardNumber: String?, expMonth: Int?, expYear: Int?, cvc: String?,
    summary: String
  ) async throws -> PaymentMethod {
    var params = PaymentMethodCreateParams()
    params.type = CustomerListPaymentMethodsParamsType(rawValue: type)
    if let cardNumber, let expMonth, let expYear {
      params.card = .paymentMethodCreateParamsCardVariant1(
        PaymentMethodCreateParamsCardVariant1(
          cvc: cvc, expMonth: expMonth, expYear: expYear, number: cardNumber))
    }
    return try await run(
      PaymentMethod.self, method: "POST", path: "/v1/payment_methods", params: params,
      key: Self.key(), summary: summary)
  }

  /// Updates a payment method's billing name and email. An empty field
  /// means "no change"; clearing a field is explorer territory (M10).
  public func updatePaymentMethod(
    id: String, billingName: String?, billingEmail: String?, summary: String
  ) async throws -> PaymentMethod {
    var params = PaymentMethodUpdateParams()
    var details = PaymentMethodUpdateParamsBillingDetails()
    if let billingName { details.name = .value(billingName) }
    if let billingEmail { details.email = .value(billingEmail) }
    params.billingDetails = details
    return try await run(
      PaymentMethod.self, method: "POST", path: "/v1/payment_methods/\(id)", params: params,
      key: Self.key(), summary: summary)
  }

  /// Attaches a payment method to a customer.
  public func attachPaymentMethod(
    id: String, customer: String, summary: String
  ) async throws -> PaymentMethod {
    var params = PaymentMethodAttachParams()
    params.customer = customer
    return try await run(
      PaymentMethod.self, method: "POST", path: "/v1/payment_methods/\(id)/attach",
      params: params, key: Self.key(), summary: summary)
  }

  /// Detaches a payment method from its customer.
  public func detachPaymentMethod(id: String, summary: String) async throws -> PaymentMethod {
    return try await run(
      PaymentMethod.self, method: "POST", path: "/v1/payment_methods/\(id)/detach",
      params: PaymentMethodDetachParams(), key: Self.key(), summary: summary)
  }

  /// Creates a payment link with a single line item (price + quantity).
  /// Multi-item and price-data links are explorer territory (M10).
  public func createPaymentLink(
    price: String, quantity: Int, summary: String
  ) async throws -> PaymentLink {
    let params = PaymentLinkCreateParams(
      lineItems: [
        PaymentLinkCreateParamsLineItemsItem(price: price, quantity: quantity)
      ])
    return try await run(
      PaymentLink.self, method: "POST", path: "/v1/payment_links", params: params,
      key: Self.key(), summary: summary)
  }

  /// Updates a payment link's active state and metadata.
  public func updatePaymentLink(
    id: String, active: Bool?, metadata: [String: String]?, summary: String
  ) async throws -> PaymentLink {
    var params = PaymentLinkUpdateParams()
    params.active = active
    params.metadata = metadata
    return try await run(
      PaymentLink.self, method: "POST", path: "/v1/payment_links/\(id)",
      params: params, key: Self.key(), summary: summary)
  }

  /// Creates a charge against a payment method.
  public func createCharge(
    amount: Int, currency: String, source: String, description: String?, summary: String
  ) async throws -> Charge {
    var params = ChargeCreateParams()
    params.amount = amount
    params.currency = currency
    params.source = source
    if let description { params.description = description }
    return try await run(
      Charge.self, method: "POST", path: "/v1/charges", params: params,
      key: Self.key(), summary: summary)
  }

  // MARK: - Checkout sessions

  /// Expires an open checkout session: it can no longer be completed.
  public func expireCheckoutSession(id: String, summary: String) async throws -> CheckoutSession {
    return try await run(
      CheckoutSession.self, method: "POST", path: "/v1/checkout/sessions/\(id)/expire",
      params: SessionExpireParams(), key: Self.key(), summary: summary)
  }
}

/// Formats a Stripe metadata dictionary as the one-pair-per-line
/// "key=value" text an edit sheet's metadata field shows, keys sorted so a
/// round trip through `parseMetadataLines` is stable.
public func formatMetadataLines(_ metadata: [String: String]) -> String {
  metadata
    .sorted { $0.key < $1.key }
    .map { "\($0.key)=\($0.value)" }
    .joined(separator: "\n")
}

/// Parses the one-pair-per-line "key=value" text of an edit sheet's metadata
/// field into a Stripe metadata dictionary. Blank lines are skipped and both
/// sides of the `=` are trimmed; a later line for the same key wins. Any
/// line without a `=` (or with an empty key) fails the whole parse, so the
/// sheet can flag the text before submit. The metadata sent replaces the
/// object's metadata wholesale, so empty text parses to an empty dictionary
/// (clearing every key). Returns nil only when the text is malformed.
public func parseMetadataLines(_ text: String) -> [String: String]? {
  var result: [String: String] = [:]
  for rawLine in text.split(separator: "\n") {
    let line = rawLine.trimmingCharacters(in: .whitespaces)
    guard !line.isEmpty else { continue }
    guard let equals = line.firstIndex(of: "=") else { return nil }
    let key = line[line.startIndex..<equals].trimmingCharacters(in: .whitespaces)
    guard !key.isEmpty else { return nil }
    let value = line[line.index(after: equals)...].trimmingCharacters(in: .whitespaces)
    result[key] = value
  }
  return result
}
