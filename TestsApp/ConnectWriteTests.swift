// ConnectWriteTests.swift — TestsApp
// The M8 Connect writes (decision 0032 slice 2): refuse in dashboard mode
// before any network traffic, carry an idempotency key, hit the exact
// endpoint and encode their parameters, decode the stripe-mock response
// shapes, and record the attempt in the audit log. Stubbed transport; no
// real network is touched.

import StripeModels
import XCTest

@testable import GeistData
@testable import StripeClient

@MainActor
final class ConnectWriteTests: XCTestCase {

  private var audit: InMemoryAuditStore!

  override func setUp() async throws {
    WriteStubURLProtocol.reset()
    audit = InMemoryAuditStore()
  }

  private static let stubSession: URLSession = {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [WriteStubURLProtocol.self]
    return URLSession(configuration: config)
  }()

  private func makeService(
    mode: StripeClient.Mode,
    dashboardLocked: @escaping @MainActor @Sendable () async -> Bool = { false }
  ) -> ConnectWriteService {
    let client = StripeClient(
      apiKey: "sk_test_stub123", mode: mode,
      baseURL: URL(string: "http://127.0.0.1:1")!, session: Self.stubSession)
    return ConnectWriteService(
      client: client, accountID: "acct_test_123", accountName: "Shot Store", audit: audit,
      dashboardLocked: dashboardLocked)
  }

  /// Asserts the request carries a non-empty Stripe-Idempotency-Key header.
  private func assertIdempotencyKey(
    _ request: URLRequest, file: StaticString = #filePath, line: UInt = #line
  ) {
    let key = request.value(forHTTPHeaderField: "Idempotency-Key")
    XCTAssertNotNil(key, "write must carry an idempotency key", file: file, line: line)
    XCTAssertFalse(key!.isEmpty, "idempotency key must not be empty", file: file, line: line)
  }

  // MARK: - Account links

  func testCreateAccountLinkEncodesAccountAndType() async throws {
    let service = makeService(mode: .management)
    WriteStub.installConnect(
      status: 200,
      json: [
        "id": "link_test_123", "object": "account_link", "created": 1_700_000_000,
        "expires_at": 1_700_100_000, "url": "https://example.com/onboard",
      ])
    let link = try await service.createAccountLink(
      account: "acct_test_123", type: .accountOnboarding, summary: "Create account link")
    // AccountLink carries no id in the spec - its url is the identity.
    XCTAssertTrue(link.url.hasPrefix("https://example.com/"))
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/account_links"))
    let body = try XCTUnwrap(WriteStub.firstBodyString())
    XCTAssertTrue(body.contains("account=acct_test_123"))
    XCTAssertTrue(body.contains("type=account_onboarding"))
    assertIdempotencyKey(request)
    let entries = await audit.entries(limit: 5)
    XCTAssertEqual(entries[0].outcome, "succeeded")
  }

  // MARK: - Login links

  func testCreateLoginLinkHitsAccountScopedPath() async throws {
    let service = makeService(mode: .management)
    WriteStub.installConnect(
      status: 200,
      json: [
        "object": "login_link", "created": 1_700_000_000,
        "url": "https://example.com/express/acct_test_123/login",
      ])
    _ = try await service.createLoginLink(account: "acct_test_123", summary: "Create login link")
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/accounts/acct_test_123/login_links"))
    assertIdempotencyKey(request)
  }

  // MARK: - Account sessions

  func testCreateAccountSessionEncodesAccountAndComponents() async throws {
    let service = makeService(mode: .management)
    // The response's components mirror the full generated struct: every
    // component key present with enabled/claims. Keep every required field.
    let components: [String: Any] = [
      "account_management": [
        "enabled": false,
        "features": [
          "disable_stripe_user_authentication": false, "external_account_collection": false,
        ],
      ],
      "account_onboarding": [
        "enabled": true,
        "features": [
          "disable_stripe_user_authentication": false, "external_account_collection": true,
        ],
      ],
      "balance_report": ["enabled": false, "features": [:]],
      "balances": [
        "enabled": false,
        "features": [
          "disable_stripe_user_authentication": false, "edit_payout_schedule": false,
          "external_account_collection": false, "instant_payouts": false, "standard_payouts": false,
        ],
      ],
      "disputes_list": [
        "enabled": false,
        "features": [
          "capture_payments": false, "destination_on_behalf_of_charge_management": false,
          "dispute_management": false, "refund_management": false,
          "smart_disputes_management": false,
        ],
      ],
      "documents": [
        "enabled": false,
        "features": [
          "disable_stripe_user_authentication": false, "external_account_collection": false,
        ],
      ],
      "financial_account": [
        "enabled": false,
        "features": [
          "disable_stripe_user_authentication": false, "external_account_collection": false,
          "send_money": false, "transfer_balance": false,
        ],
      ],
      "financial_account_transactions": [
        "enabled": false, "features": ["card_spend_dispute_management": false],
      ],
      "instant_payouts_promotion": [
        "enabled": false,
        "features": [
          "disable_stripe_user_authentication": false, "external_account_collection": false,
          "instant_payouts": false,
        ],
      ],
      "issuing_card": [
        "enabled": false,
        "features": [
          "card_management": false, "card_spend_dispute_management": false,
          "cardholder_management": false, "spend_control_management": false,
        ],
      ],
      "issuing_cards_list": [
        "enabled": false,
        "features": [
          "card_management": false, "card_spend_dispute_management": false,
          "cardholder_management": false, "disable_stripe_user_authentication": false,
          "spend_control_management": false,
        ],
      ],
      "notification_banner": [
        "enabled": false,
        "features": [
          "disable_stripe_user_authentication": false, "external_account_collection": false,
        ],
      ],
      "payment_details": [
        "enabled": false,
        "features": [
          "capture_payments": false, "destination_on_behalf_of_charge_management": false,
          "dispute_management": false, "refund_management": false,
          "smart_disputes_management": false,
        ],
      ],
      "payment_disputes": [
        "enabled": false,
        "features": [
          "destination_on_behalf_of_charge_management": false, "dispute_management": false,
          "refund_management": false, "smart_disputes_management": false,
        ],
      ],
      "payment_method_settings": [
        "enabled": false,
        "features": [
          "disable_stripe_user_authentication": false, "payment_method_settings_management": false,
        ],
      ],
      "payments": [
        "enabled": false,
        "features": [
          "capture_payments": false, "destination_on_behalf_of_charge_management": false,
          "dispute_management": false, "refund_management": false,
          "smart_disputes_management": false,
        ],
      ],
      "payout_details": ["enabled": false, "features": [:]],
      "payout_reconciliation_report": ["enabled": false, "features": [:]],
      "payouts": [
        "enabled": false,
        "features": [
          "disable_stripe_user_authentication": false, "edit_payout_schedule": false,
          "external_account_collection": false, "instant_payouts": false, "standard_payouts": false,
        ],
      ],
      "payouts_list": ["enabled": false, "features": [:]],
      "tax_registrations": ["enabled": false, "features": [:]],
      "tax_settings": ["enabled": false, "features": [:]],
      "reporting_chart": ["enabled": false, "features": [:]],
      "terminal_hardware_orders": ["enabled": false, "features": [:]],
      "terminal_hardware_shop": ["enabled": false, "features": [:]],
    ]
    WriteStub.installConnect(
      status: 200,
      json: [
        "object": "account_session", "account": "acct_test_123",
        "client_secret": "accs_secret_test_123", "components": components, "livemode": false,
        "expires_at": 1_700_100_000,
      ])
    let session = try await service.createAccountSession(
      account: "acct_test_123",
      components: AccountSessionCreateParamsComponents(
        accountOnboarding: AccountSessionCreateParamsComponentsAccountOnboarding(
          enabled: true, features: nil)),
      summary: "Create account session")
    XCTAssertEqual(session.account, "acct_test_123")
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/account_sessions"))
    let body = try XCTUnwrap(WriteStub.firstBodyString())
    XCTAssertTrue(body.contains("account=acct_test_123"))
    XCTAssertTrue(body.contains("components%5Baccount_onboarding%5D%5Benabled%5D=true"), body)
    assertIdempotencyKey(request)
  }

  // MARK: - Capabilities

  func testUpdateCapabilityRequestsAndUnrequests() async throws {
    let service = makeService(mode: .management)
    WriteStub.installConnect(
      status: 200,
      json: [
        "object": "capability", "id": "card_payments", "account": "acct_test_123",
        "requested": true, "requested_at": 1_700_000_000,
        "requirements": [
          "alternatives": [], "currently_due": [], "errors": [], "eventually_due": [],
          "past_due": [], "pending_verification": [],
        ], "status": "active",
      ])
    let cap = try await service.updateCapability(
      account: "acct_test_123", capability: "card_payments", requested: true,
      summary: "Request card_payments")
    XCTAssertEqual(cap.id, "card_payments")
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertTrue(
      request.url!.path.hasSuffix("/v1/accounts/acct_test_123/capabilities/card_payments"))
    let body = try XCTUnwrap(WriteStub.firstBodyString())
    XCTAssertEqual(body, "requested=true")
    assertIdempotencyKey(request)
  }

  // MARK: - Persons

  func testCreatePersonEncodesEmailAndName() async throws {
    let service = makeService(mode: .management)
    WriteStub.installConnect(
      status: 200,
      json: [
        "id": "person_test_123", "object": "person", "account": "acct_test_123",
        "created": 1_700_000_000, "email": "bob@example.com", "first_name": "Bob",
        "last_name": "Example", "livemode": false,
        "requirements": [
          "alternatives": [], "currently_due": [], "errors": [], "eventually_due": [],
          "past_due": [], "pending_verification": [],
        ],
      ])
    let person = try await service.createPerson(
      account: "acct_test_123",
      params: PersonCreateParams(email: "bob@example.com", firstName: "Bob", lastName: "Example"),
      summary: "Create person")
    XCTAssertEqual(person.id, "person_test_123")
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/accounts/acct_test_123/persons"))
    let body = try XCTUnwrap(WriteStub.firstBodyString())
    // '@' percent-encodes as %40 in a form body.
    XCTAssertTrue(body.contains("email=bob%40example.com"), body)
    XCTAssertTrue(body.contains("first_name=Bob"), body)
    assertIdempotencyKey(request)
  }

  func testUpdatePersonEncodesOnlySetFields() async throws {
    let service = makeService(mode: .management)
    WriteStub.installConnect(
      status: 200,
      json: [
        "id": "person_test_123", "object": "person", "account": "acct_test_123",
        "created": 1_700_000_000, "email": "bob@example.com", "livemode": false,
        "requirements": [
          "alternatives": [], "currently_due": [], "errors": [], "eventually_due": [],
          "past_due": [], "pending_verification": [],
        ],
      ])
    _ = try await service.updatePerson(
      account: "acct_test_123", person: "person_test_123",
      params: PersonUpdateParams(email: "robert@example.com"),
      summary: "Update person")
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/accounts/acct_test_123/persons/person_test_123"))
    let body = try XCTUnwrap(WriteStub.firstBodyString())
    XCTAssertEqual(body.removingPercentEncoding, "email=robert@example.com")
  }

  func testDeletePersonSendsDelete() async throws {
    let service = makeService(mode: .management)
    WriteStub.installConnect(
      status: 200, json: ["id": "person_test_123", "object": "person", "deleted": true])
    let deleted = try await service.deletePerson(
      account: "acct_test_123", person: "person_test_123", summary: "Delete person")
    XCTAssertEqual(deleted.deleted, true)
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertEqual(request.httpMethod, "DELETE")
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/accounts/acct_test_123/persons/person_test_123"))
    assertIdempotencyKey(request)
  }

  // MARK: - External accounts

  func testDeleteExternalAccountSendsDelete() async throws {
    let service = makeService(mode: .management)
    WriteStub.installConnect(
      status: 200, json: ["id": "ba_test_123", "object": "bank_account", "deleted": true])
    let deleted = try await service.deleteExternalAccount(
      account: "acct_test_123", id: "ba_test_123", summary: "Remove bank account")
    guard case .deletedBankAccount(let bank) = deleted else {
      return XCTFail("expected a deleted bank account")
    }
    XCTAssertEqual(bank.deleted, true)
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertEqual(request.httpMethod, "DELETE")
    XCTAssertTrue(
      request.url!.path.hasSuffix("/v1/accounts/acct_test_123/external_accounts/ba_test_123"))
    assertIdempotencyKey(request)
  }

  // MARK: - Application fee refunds

  func testCreateFeeRefundEncodesAmountOnlyWhenSet() async throws {
    let service = makeService(mode: .management)
    WriteStub.installConnect(
      status: 200,
      json: [
        "id": "fr_test_123", "object": "fee_refund", "amount": 500, "balance_transaction": nil,
        "created": 1_700_000_000, "currency": "usd", "fee": "fee_test_123", "livemode": false,
        "metadata": [:],
      ])
    let refund = try await service.createFeeRefund(
      fee: "fee_test_123", amount: 500, summary: "Refund fee")
    XCTAssertEqual(refund.id, "fr_test_123")
    XCTAssertEqual(refund.amount, 500)
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/application_fees/fee_test_123/refunds"))
    let body = try XCTUnwrap(WriteStub.firstBodyString())
    XCTAssertEqual(body, "amount=500")
    assertIdempotencyKey(request)
  }

  func testCreateFeeRefundWithoutAmountSendsEmptyBody() async throws {
    let service = makeService(mode: .management)
    WriteStub.installConnect(
      status: 200,
      json: [
        "id": "fr_test_123", "object": "fee_refund", "amount": 100, "balance_transaction": nil,
        "created": 1_700_000_000, "currency": "usd", "fee": "fee_test_123", "livemode": false,
        "metadata": [:],
      ])
    _ = try await service.createFeeRefund(
      fee: "fee_test_123", amount: nil, summary: "Refund fee in full")
    // A params object with every field nil encodes to an empty body.
    let body = WriteStub.firstBodyString() ?? ""
    XCTAssertTrue(body.isEmpty, "full-fee refund sends no parameters: " + body)
  }

  func testUpdateFeeRefundEncodesMetadata() async throws {
    let service = makeService(mode: .management)
    WriteStub.installConnect(
      status: 200,
      json: [
        "id": "fr_test_123", "object": "fee_refund", "amount": 100, "balance_transaction": nil,
        "created": 1_700_000_000, "currency": "usd", "fee": "fee_test_123", "livemode": false,
        "metadata": ["reason": "goodwill"],
      ])
    _ = try await service.updateFeeRefund(
      fee: "fee_test_123", id: "fr_test_123",
      metadata: .value(["reason": "goodwill"]),
      summary: "Update fee refund")
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertTrue(
      request.url!.path.hasSuffix("/v1/application_fees/fee_test_123/refunds/fr_test_123"))
    let body = try XCTUnwrap(WriteStub.firstBodyString())
    // Brackets are percent-encoded in the form body.
    XCTAssertTrue(body.contains("metadata%5Breason%5D=goodwill"), body)
  }

  // MARK: - Dashboard gates

  func testDashboardModeRefusesAccountLink() async throws {
    let service = makeService(mode: .dashboard)
    do {
      _ = try await service.createAccountLink(
        account: "acct_test_123", type: .accountOnboarding, summary: "Create account link")
      XCTFail("dashboard mode must refuse the write")
    } catch let error as ConnectWriteError {
      XCTAssertEqual(error, .dashboardMode)
    }
    XCTAssertTrue(WriteStubURLProtocol.recordedRequests.isEmpty, "no request may reach the network")
    let entries = await audit.entries(limit: 10)
    XCTAssertEqual(entries.count, 1)
    XCTAssertEqual(entries[0].outcome, "refused: dashboard mode")
    XCTAssertTrue(entries[0].path.hasSuffix("/v1/account_links"))
  }

  func testDashboardLockedAccountRefusesFeeRefund() async throws {
    let service = makeService(mode: .management, dashboardLocked: { true })
    do {
      _ = try await service.createFeeRefund(fee: "fee_test_123", amount: nil, summary: "Refund fee")
      XCTFail("a locked account must refuse the write")
    } catch let error as ConnectWriteError {
      XCTAssertEqual(error, .dashboardMode)
    }
    XCTAssertTrue(WriteStubURLProtocol.recordedRequests.isEmpty)
    let entries = await audit.entries(limit: 10)
    XCTAssertEqual(entries[0].outcome, "refused: dashboard mode")
  }

  // MARK: - Failure audit

  func testFailedWriteRecordsOutcomeAndRethrows() async throws {
    let service = makeService(mode: .management)
    WriteStub.installConnect(
      status: 402,
      json: [
        "error": [
          "type": "invalid_request_error", "message": "Fee already fully refunded",
          "code": "charge_already_refunded",
        ]
      ])
    do {
      _ = try await service.createFeeRefund(fee: "fee_test_123", amount: nil, summary: "Refund fee")
      XCTFail("a 402 must throw")
    } catch {
      // Expected: the service rethrows after auditing.
    }
    let entries = await audit.entries(limit: 10)
    XCTAssertEqual(entries.count, 1)
    XCTAssertTrue(entries[0].outcome.hasPrefix("failed: "), entries[0].outcome)
    XCTAssertTrue(entries[0].outcome.contains("Fee already fully refunded"))
  }
}
