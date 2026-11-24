// ConnectWrite.swift — Sources/GeistData
// Connect platform writes (M8 slice 2, decision 0032): account links,
// login links, account sessions, capability updates, person create/update/
// delete, external-account delete, and application-fee refunds.
//
// The same three gates as every other write service stand between a user
// action and Stripe:
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

public enum ConnectWriteError: LocalizedError, Equatable {
  /// The service was asked to write while the client is in dashboard mode.
  case dashboardMode

  public var errorDescription: String? {
    switch self {
    case .dashboardMode:
      return "Dashboard mode is read-only. Unlock the account to make changes."
    }
  }
}

public struct ConnectWriteService: Sendable {
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
      throw ConnectWriteError.dashboardMode
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

  // MARK: - Account links

  /// Creates an onboarding or update link for a connected account.
  /// `collect` limits the fields the link collects; nil means all.
  public func createAccountLink(
    account: String,
    type: V2CoreAccountLinkUseCaseType,
    collect: V2CoreAccountLinkUseCaseAccountOnboardingCollectionOptionsFields? = nil,
    refreshURL: String? = nil,
    returnURL: String? = nil,
    summary: String
  ) async throws -> AccountLink {
    let params = AccountLinkCreateParams(
      account: account,
      collect: collect,
      refreshUrl: refreshURL,
      returnUrl: returnURL,
      type: type
    )
    return try await run(
      AccountLink.self,
      method: "POST",
      path: "/v1/account_links",
      params: params,
      key: Self.key(),
      summary: summary
    )
  }

  // MARK: - Login links

  /// Creates a login link for a connected account's Express dashboard.
  public func createLoginLink(account: String, summary: String) async throws -> LoginLink {
    let params = LoginLinkCreateParams(account: account)
    return try await run(
      LoginLink.self,
      method: "POST",
      path: "/v1/accounts/\(StripeClient.encodePathSegment(account))/login_links",
      params: params,
      key: Self.key(),
      summary: summary
    )
  }

  // MARK: - Account sessions

  /// Creates an embedded-component account session for a connected account.
  public func createAccountSession(
    account: String,
    components: AccountSessionCreateParamsComponents,
    summary: String
  ) async throws -> AccountSession {
    let params = AccountSessionCreateParams(account: account, components: components)
    return try await run(
      AccountSession.self,
      method: "POST",
      path: "/v1/account_sessions",
      params: params,
      key: Self.key(),
      summary: summary
    )
  }

  // MARK: - Capabilities

  /// Requests or unrequests a capability on a connected account.
  public func updateCapability(
    account: String, capability: String, requested: Bool, summary: String
  ) async throws -> Capability {
    let params = CapabilityUpdateParams(requested: requested)
    return try await run(
      Capability.self,
      method: "POST",
      path:
        "/v1/accounts/\(StripeClient.encodePathSegment(account))/capabilities/\(StripeClient.encodePathSegment(capability))",
      params: params,
      key: Self.key(),
      summary: summary
    )
  }

  // MARK: - Persons

  /// Creates a person on a connected account.
  public func createPerson(
    account: String, params: PersonCreateParams, summary: String
  ) async throws -> Person {
    try await run(
      Person.self,
      method: "POST",
      path: "/v1/accounts/\(StripeClient.encodePathSegment(account))/persons",
      params: params,
      key: Self.key(),
      summary: summary
    )
  }

  /// Updates a person on a connected account.
  public func updatePerson(
    account: String, person: String, params: PersonUpdateParams, summary: String
  ) async throws -> Person {
    try await run(
      Person.self,
      method: "POST",
      path:
        "/v1/accounts/\(StripeClient.encodePathSegment(account))/persons/\(StripeClient.encodePathSegment(person))",
      params: params,
      key: Self.key(),
      summary: summary
    )
  }

  /// Deletes a person from a connected account.
  public func deletePerson(
    account: String, person: String, summary: String
  ) async throws -> DeletedPerson {
    let params = PersonDeleteParams()
    return try await run(
      DeletedPerson.self,
      method: "DELETE",
      path:
        "/v1/accounts/\(StripeClient.encodePathSegment(account))/persons/\(StripeClient.encodePathSegment(person))",
      params: params,
      key: Self.key(),
      summary: summary
    )
  }

  // MARK: - External accounts

  /// Removes an external account (bank account or card) from a connected
  /// account. Deletion is the only external-account write that cannot be
  /// done through the account update endpoint.
  public func deleteExternalAccount(
    account: String, id: String, summary: String
  ) async throws -> DeletedExternalAccount {
    let params = ExternalAccountDeleteParams()
    return try await run(
      DeletedExternalAccount.self,
      method: "DELETE",
      path:
        "/v1/accounts/\(StripeClient.encodePathSegment(account))/external_accounts/\(StripeClient.encodePathSegment(id))",
      params: params,
      key: Self.key(),
      summary: summary
    )
  }

  // MARK: - Application fee refunds

  /// Refunds an application fee, in full when `amount` is nil.
  public func createFeeRefund(
    fee: String, amount: Int?, metadata: [String: String]? = nil, summary: String
  ) async throws -> FeeRefund {
    let params = FeeRefundCreateParams(amount: amount, metadata: metadata)
    return try await run(
      FeeRefund.self,
      method: "POST",
      path: "/v1/application_fees/\(StripeClient.encodePathSegment(fee))/refunds",
      params: params,
      key: Self.key(),
      summary: summary
    )
  }

  /// Updates a fee refund's metadata.
  public func updateFeeRefund(
    fee: String, id: String, metadata: Clearable<[String: String]>?, summary: String
  ) async throws -> FeeRefund {
    let params = FeeRefundUpdateParams(metadata: metadata)
    return try await run(
      FeeRefund.self,
      method: "POST",
      path:
        "/v1/application_fees/\(StripeClient.encodePathSegment(fee))/refunds/\(StripeClient.encodePathSegment(id))",
      params: params,
      key: Self.key(),
      summary: summary
    )
  }
}
