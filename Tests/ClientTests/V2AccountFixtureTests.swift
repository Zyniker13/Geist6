// V2AccountFixtureTests.swift — Tests/ClientTests
// Recorded-response fixture tests for the v2 accounts rows (decision
// 0032): stripe-mock 0.206.0 serves only /v1, so /v2/core/* is proven
// with hand-written fixtures using obviously fake values (decision 0029
// policy). Each test drives the generated client through the stub
// URLProtocol and asserts both the request shape (path, method, JSON
// body, v2 headers) and the decoded model.

import StripeModels
import XCTest

@testable import StripeClient

@MainActor
final class V2AccountFixtureTests: XCTestCase {

  func makeClient() -> StripeClient {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [RecordingURLProtocol.self]
    RecordingURLProtocol.recordedRequests = []
    RecordingURLProtocol.recordedResponses = []
    return StripeClient(
      apiKey: "sk_test_fake", mode: .management, baseURL: URL(string: "http://127.0.0.1:1")!,
      configuration: config)
  }

  private func lastBody() -> Data? {
    RecordingURLProtocol.recordedRequests.last?.httpBody
  }

  private func lastPath() -> String? {
    RecordingURLProtocol.recordedRequests.last?.url?.path
  }

  // MARK: - v2 account list

  /// GET /v2/core/accounts decodes a recorded page. The v2 page shape
  /// differs from v1: `next_page_url`/`previous_page_url` instead of
  /// `has_more`/`url`.
  func testListV2AccountsDecodesRecordedPage() async throws {
    let client = makeClient()
    StubBuilder.install(
      status: 200,
      json: [
        "data": [
          [
            "id": "acct_test_v2_1",
            "object": "v2.core.account",
            "applied_configurations": ["merchant"],
            "created": "2026-11-01T00:00:00Z",
            "livemode": false,
            "display_name": "Fixture seller",
            "contact_email": "alice@example.com",
            "closed": false,
            "defaults": [
              "currency": "usd",
              "locales": ["en"],
              "responsibilities": [
                "requirements_collector": "stripe",
                "losses_collector": "stripe",
              ],
            ],
            "requirements": [
              "entries": [
                [
                  "awaiting_action_from": "user",
                  "description": "Confirm bank account",
                  "errors": [
                    [
                      "code": "invalid_address_city_state_postal_code",
                      "description": "City/state/ZIP do not match",
                    ]
                  ],
                  "impact": [
                    "restricts_capabilities": [
                      [
                        "capability": "ach_debit_payments",
                        "configuration": "merchant",
                        "deadline": ["status": "currently_due"],
                      ]
                    ]
                  ],
                  "minimum_deadline": ["status": "currently_due"],
                  "requested_reasons": [["code": "routine_onboarding"]],
                ]
              ]
            ],
          ]
        ],
        "next_page_url": nil,
        "previous_page_url": nil,
      ])
    let page = try await client.listV2CoreAccounts(V2CoreAccountListParams())
    XCTAssertEqual(page.data.count, 1)
    let account = try XCTUnwrap(page.data.first)
    XCTAssertEqual(account.id, "acct_test_v2_1")
    XCTAssertEqual(account.appliedConfigurations.first?.rawValue, "merchant")
    XCTAssertEqual(account.defaults?.currency, "usd")
    XCTAssertEqual(account.requirements?.entries?.first?.description, "Confirm bank account")
    XCTAssertEqual(
      account.requirements?.entries?.first?.impact.restrictsCapabilities?.first?.capability
        .rawValue,
      "ach_debit_payments")
    XCTAssertEqual(page.nextPageUrl.valueOrNil, nil)
    XCTAssertEqual(lastPath(), "/v2/core/accounts")
  }

  // MARK: - v2 account create/update/close

  /// POST /v2/core/accounts sends a JSON body (v2 bodies are JSON, not
  /// form-encoded) with an Idempotency-Key header, and decodes the
  /// recorded account.
  func testCreateV2AccountSendsJSONBodyWithIdempotencyKey() async throws {
    let client = makeClient()
    var params = V2CoreAccountCreateParams()
    params.contactEmail = "alice@example.com"
    params.displayName = "Fixture seller"
    StubBuilder.install(
      status: 200,
      json: [
        "id": "acct_test_v2_new",
        "object": "v2.core.account",
        "applied_configurations": [],
        "created": "2026-11-01T00:00:00Z",
        "livemode": false,
      ])
    let created = try await client.createAccount(
      params, expand: nil, idempotencyKey: "idem_v2_create_1")
    XCTAssertEqual(created.id, "acct_test_v2_new")
    let request = try XCTUnwrap(RecordingURLProtocol.recordedRequests.last)
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertEqual(request.url?.path, "/v2/core/accounts")
    XCTAssertEqual(request.value(forHTTPHeaderField: "Idempotency-Key"), "idem_v2_create_1")
    let body = try XCTUnwrap(lastBody())
    let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: body) as? [String: Any])
    XCTAssertEqual(json["contact_email"] as? String, "alice@example.com")
    XCTAssertEqual(json["display_name"] as? String, "Fixture seller")
    XCTAssertEqual(
      request.value(forHTTPHeaderField: "Content-Type"), "application/json")
  }

  /// POST /v2/core/accounts/{id} updates by JSON body; POST /v2/core/
  /// accounts/{id}/close closes with an empty JSON object.
  func testUpdateAndCloseV2AccountHitRightPaths() async throws {
    let client = makeClient()
    var update = V2CoreAccountUpdateParams()
    update.displayName = "Renamed seller"
    StubBuilder.install(
      status: 200,
      json: [
        "id": "acct_test_v2_1",
        "object": "v2.core.account",
        "applied_configurations": [],
        "created": "2026-11-01T00:00:00Z",
        "livemode": false,
        "display_name": "Renamed seller",
      ])
    let updated = try await client.updateAccount(
      id: "acct_test_v2_1", update, expand: nil, idempotencyKey: "idem_v2_update_1")
    XCTAssertEqual(updated.displayName, "Renamed seller")
    XCTAssertEqual(lastPath(), "/v2/core/accounts/acct_test_v2_1")
    XCTAssertEqual(
      RecordingURLProtocol.recordedRequests.last?.value(forHTTPHeaderField: "Idempotency-Key"),
      "idem_v2_update_1")

    StubBuilder.install(
      status: 200,
      json: [
        "id": "acct_test_v2_1",
        "object": "v2.core.account",
        "applied_configurations": [],
        "created": "2026-11-01T00:00:00Z",
        "livemode": false,
        "closed": true,
      ])
    let closed = try await client.closeAccount(
      id: "acct_test_v2_1", AccountCloseParams(), expand: nil,
      idempotencyKey: "idem_v2_close_1")
    XCTAssertEqual(closed.closed, true)
    XCTAssertEqual(lastPath(), "/v2/core/accounts/acct_test_v2_1/close")
    XCTAssertEqual(
      RecordingURLProtocol.recordedRequests.last?.value(forHTTPHeaderField: "Idempotency-Key"),
      "idem_v2_close_1")
  }

  // MARK: - v2 account links

  /// POST /v2/core/account_links decodes a recorded link whose url and
  /// expiry mirror the documented response shape.
  func testCreateV2AccountLinkDecodesRecordedLink() async throws {
    let client = makeClient()
    var params = V2CoreAccountLinkCreateParams(
      account: "acct_test_v2_1",
      useCase: V2CoreAccountLinkCreateParamsUseCase(
        accountOnboarding: V2CoreAccountLinkCreateParamsUseCaseAccountOnboarding(
          collectionOptions: V2CoreAccountLinkCreateParamsUseCaseAccountOnboardingCollectionOptions(
            fields: .currentlyDue, futureRequirements: .include),
          refreshUrl: "https://example.com/refresh",
          returnUrl: "https://example.com/return"),
        type: .accountOnboarding))
    StubBuilder.install(
      status: 200,
      json: [
        "account": "acct_test_v2_1",
        "created": "2026-11-01T00:00:00Z",
        "expires_at": "2026-11-01T01:00:00Z",
        "livemode": false,
        "object": "v2.core.account_link",
        "url": "https://example.com/onboard/acct_test_v2_1",
        "use_case": ["type": "account_onboarding"],
      ])
    let link = try await client.createAccountLink(
      params, expand: nil, idempotencyKey: "idem_v2_link_1")
    XCTAssertEqual(link.url, "https://example.com/onboard/acct_test_v2_1")
    XCTAssertEqual(link.useCase.type, .accountOnboarding)
    XCTAssertEqual(link.expiresAt, "2026-11-01T01:00:00Z")
    XCTAssertEqual(lastPath(), "/v2/core/account_links")
    let body = try XCTUnwrap(lastBody())
    let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: body) as? [String: Any])
    XCTAssertEqual(json["account"] as? String, "acct_test_v2_1")
  }

  // MARK: - v2 persons and tokens

  /// POST /v2/core/accounts/{id}/persons decodes a recorded person.
  func testCreateV2AccountPersonDecodesRecordedPerson() async throws {
    let client = makeClient()
    var params = AccountPersonCreateParams()
    StubBuilder.install(
      status: 200,
      json: [
        "id": "ap_test_v2_1",
        "object": "v2.core.account_person",
        "account": "acct_test_v2_1",
        "created": "2026-11-01T00:00:00Z",
        "updated": "2026-11-01T00:00:00Z",
        "livemode": false,
        "given_name": "Alice",
        "relationship": ["representative": true],
      ])
    let person = try await client.createAccountPerson(
      accountId: "acct_test_v2_1", params, expand: nil, idempotencyKey: "idem_v2_person_1")
    XCTAssertEqual(person.id, "ap_test_v2_1")
    XCTAssertEqual(person.givenName, "Alice")
    XCTAssertEqual(person.relationship?.representative, true)
    XCTAssertEqual(lastPath(), "/v2/core/accounts/acct_test_v2_1/persons")
  }

  /// POST /v2/core/account_tokens decodes a recorded token (used=false,
  /// expiry mirror-shaped like the link's).
  func testCreateV2AccountTokenDecodesRecordedToken() async throws {
    let client = makeClient()
    StubBuilder.install(
      status: 200,
      json: [
        "id": "tok_test_v2_1",
        "object": "v2.core.account_token",
        "created": "2026-11-01T00:00:00Z",
        "expires_at": "2026-11-01T01:00:00Z",
        "livemode": false,
        "used": false,
      ])
    let token = try await client.createAccountToken(
      AccountTokenCreateParams(), expand: nil, idempotencyKey: "idem_v2_token_1")
    XCTAssertEqual(token.id, "tok_test_v2_1")
    XCTAssertEqual(token.used, false)
    XCTAssertEqual(token.expiresAt, "2026-11-01T01:00:00Z")
    XCTAssertEqual(lastPath(), "/v2/core/account_tokens")
  }

  /// POST /v2/core/accounts/{id}/person_tokens decodes a recorded person
  /// token scoped to its account path segment.
  func testCreateV2AccountPersonTokenDecodesRecordedToken() async throws {
    let client = makeClient()
    StubBuilder.install(
      status: 200,
      json: [
        "id": "ptok_test_v2_1",
        "object": "v2.core.account_person_token",
        "created": "2026-11-01T00:00:00Z",
        "expires_at": "2026-11-01T01:00:00Z",
        "livemode": false,
        "used": false,
      ])
    let token = try await client.createAccountPersonToken(
      accountId: "acct_test_v2_1", AccountPersonTokenCreateParams(), expand: nil,
      idempotencyKey: "idem_v2_ptok_1")
    XCTAssertEqual(token.id, "ptok_test_v2_1")
    XCTAssertEqual(lastPath(), "/v2/core/accounts/acct_test_v2_1/person_tokens")
  }
}
