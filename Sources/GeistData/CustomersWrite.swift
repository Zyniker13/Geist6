// CustomersWrite.swift — Sources/GeistData
// Customer writes: create, update, delete, discount removal, balance
// transactions, tax IDs, funding instructions, and cash balance funding.
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
//
// Balance transactions, funding instructions, and cash balance funding are
// money-affecting; the same gates apply to them as to every other write.

import Foundation
import StripeClient
import StripeModels

public enum CustomersWriteError: LocalizedError, Equatable {
  /// The service was asked to write while the client is in dashboard mode.
  case dashboardMode

  public var errorDescription: String? {
    switch self {
    case .dashboardMode:
      return "Dashboard mode is read-only. Unlock the account to make changes."
    }
  }
}

public struct CustomersWriteService: Sendable {
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
      throw CustomersWriteError.dashboardMode
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

  // MARK: - Customers

  /// Creates a customer. `metadata == nil` leaves metadata untouched; a
  /// non-nil value replaces it wholesale.
  public func createCustomer(
    email: String?, name: String?, description: String?, metadata: [String: String]?,
    summary: String
  ) async throws -> Customer {
    var params = CustomerCreateParams()
    params.email = email
    params.name = name
    params.description = description
    if let metadata {
      params.metadata = .value(metadata)
    }
    return try await run(
      Customer.self, method: "POST", path: "/v1/customers", params: params,
      key: Self.key(), summary: summary)
  }

  /// Updates a customer's contact details and metadata. `nil` fields are
  /// left untouched; a non-nil `metadata` replaces it wholesale.
  public func updateCustomer(
    id: String, email: String?, name: String?, description: String?,
    metadata: [String: String]?, summary: String
  ) async throws -> Customer {
    var params = CustomerUpdateParams()
    params.email = email
    params.name = name
    params.description = description
    if let metadata {
      params.metadata = .value(metadata)
    }
    return try await run(
      Customer.self, method: "POST", path: "/v1/customers/\(id)", params: params,
      key: Self.key(), summary: summary)
  }

  /// Deletes a customer.
  public func deleteCustomer(id: String, summary: String) async throws -> DeletedCustomer {
    return try await run(
      DeletedCustomer.self, method: "DELETE", path: "/v1/customers/\(id)",
      params: CustomerDeleteParams(), key: Self.key(), summary: summary)
  }

  /// Removes the customer's active discount.
  public func deleteDiscount(customer: String, summary: String) async throws -> DeletedDiscount {
    return try await run(
      DeletedDiscount.self, method: "DELETE",
      path: "/v1/customers/\(customer)/discount",
      params: CustomerDeleteDiscountParams(), key: Self.key(), summary: summary)
  }

  // MARK: - Balance transactions

  /// Creates a balance transaction on a customer. A positive `amount` is a
  /// credit; a negative `amount` is a debit.
  public func createBalanceTransaction(
    customer: String, amount: Int, currency: String, description: String?,
    metadata: [String: String]?, summary: String
  ) async throws -> CustomerBalanceTransaction {
    var params = CustomerBalanceTransactionCreateParams(amount: amount, currency: currency)
    params.description = description
    if let metadata {
      params.metadata = .value(metadata)
    }
    return try await run(
      CustomerBalanceTransaction.self, method: "POST",
      path: "/v1/customers/\(customer)/balance_transactions", params: params,
      key: Self.key(), summary: summary)
  }

  /// Updates a balance transaction's description and metadata.
  public func updateBalanceTransaction(
    customer: String, transaction: String, description: String?,
    metadata: [String: String]?, summary: String
  ) async throws -> CustomerBalanceTransaction {
    var params = CustomerBalanceTransactionUpdateParams()
    params.description = description
    if let metadata {
      params.metadata = .value(metadata)
    }
    return try await run(
      CustomerBalanceTransaction.self, method: "POST",
      path: "/v1/customers/\(customer)/balance_transactions/\(transaction)",
      params: params, key: Self.key(), summary: summary)
  }

  // MARK: - Tax IDs

  /// Adds a tax ID to a customer. `type` is a Stripe tax ID type such as
  /// `eu_vat`, `us_ein`, or `gb_vat`.
  public func createTaxID(
    customer: String, type: String, value: String, summary: String
  ) async throws -> TaxId {
    var params = TaxIdCreateParams(type: CustomerCreateParamsTaxIdDataItemType(rawValue: type), value: value)
    return try await run(
      TaxId.self, method: "POST", path: "/v1/customers/\(customer)/tax_ids",
      params: params, key: Self.key(), summary: summary)
  }

  /// Removes a tax ID from a customer.
  public func deleteTaxID(customer: String, id: String, summary: String) async throws -> DeletedTaxId {
    return try await run(
      DeletedTaxId.self, method: "DELETE",
      path: "/v1/customers/\(customer)/tax_ids/\(id)",
      params: TaxIdDeleteParams(), key: Self.key(), summary: summary)
  }

  // MARK: - Cash balance and funding

  /// Creates funding instructions for a customer's cash balance.
  public func createFundingInstructions(
    customer: String, currency: String, summary: String
  ) async throws -> FundingInstructions {
    let bankTransfer = CustomerCreateFundingInstructionsParamsBankTransfer(
      type: CheckoutCustomerBalanceBankTransferPaymentMethodOptionsType.euBankTransfer)
    var params = CustomerCreateFundingInstructionsParams(
      bankTransfer: bankTransfer, currency: currency,
      fundingType: CheckoutCustomerBalancePaymentMethodOptionsFundingType.bankTransfer)
    return try await run(
      FundingInstructions.self, method: "POST",
      path: "/v1/customers/\(customer)/funding_instructions", params: params,
      key: Self.key(), summary: summary)
  }

  /// Adds funds to a customer's cash balance (test-mode helper endpoint).
  public func fundCashBalance(
    customer: String, amount: Int, currency: String, summary: String
  ) async throws -> CustomerCashBalanceTransaction {
    var params = CustomerFundCashBalanceParams(amount: amount, currency: currency)
    return try await run(
      CustomerCashBalanceTransaction.self, method: "POST",
      path: "/v1/test_helpers/customers/\(customer)/fund_cash_balance", params: params,
      key: Self.key(), summary: summary)
  }
}
