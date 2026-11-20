// CustomersWriteTests.swift — TestsApp
// The M5 customer writes: refuse in dashboard mode before any network
// traffic, carry an idempotency key, encode their parameters, decode the
// stripe-mock response shapes, and record the attempt in the audit log.
// Stubbed transport; no real network is touched.

import XCTest

@testable import GeistData
@testable import StripeClient
import StripeModels

@MainActor
final class CustomersWriteTests: XCTestCase {

  private var audit: InMemoryAuditStore!

  // Fixture rule: empty collections inside [String: Any] literals must be
  // NSDictionary() / NSArray() — see PaymentsWriteTests for the full story.
  // Non-empty Swift literals are fine.

  override func setUp() async throws {
    WriteStubURLProtocol.reset()
    audit = InMemoryAuditStore()
  }

  private static let stubSession: URLSession = {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [WriteStubURLProtocol.self]
    return URLSession(configuration: config)
  }()

  private func makeService(mode: StripeClient.Mode) -> CustomersWriteService {
    let client = StripeClient(
      apiKey: "sk_test_fake", mode: mode,
      baseURL: URL(string: "http://127.0.0.1:1")!, session: Self.stubSession)
    return CustomersWriteService(
      client: client, accountID: "acct_test_123", accountName: "Shot Store", audit: audit,
      dashboardLocked: { false })
  }

  // MARK: - Create and update

  func testCreateCustomerEncodesContactFields() async throws {
    let service = makeService(mode: .management)
    WriteStub.install(status: 200, json: customerWriteFixture)
    let customer = try await service.createCustomer(
      email: "alice@example.com", name: "Alice", description: "d", metadata: ["note": "gift"],
      summary: "Create customer")
    XCTAssertEqual(customer.id, "cus_123")
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/customers"))
    XCTAssertEqual(
      try XCTUnwrap(WriteStub.firstBodyString()),
      "description=d&email=alice%40example.com&metadata%5Bnote%5D=gift&name=Alice")
  }

  func testUpdateCustomerEncodesOnlySetFields() async throws {
    let service = makeService(mode: .management)
    WriteStub.install(status: 200, json: customerWriteFixture)
    let customer = try await service.updateCustomer(
      id: "cus_123", email: nil, name: "Bob", description: nil, metadata: ["note": "gift"],
      summary: "Update customer")
    XCTAssertEqual(customer.name?.valueOrNil, "Bob")
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/customers/cus_123"))
    XCTAssertEqual(
      try XCTUnwrap(WriteStub.firstBodyString()),
      "metadata%5Bnote%5D=gift&name=Bob")
  }

  // MARK: - Deletion

  func testDeleteCustomerDecodesDeletedObject() async throws {
    let service = makeService(mode: .management)
    WriteStub.install(status: 200, json: customerDeleteFixture)
    let deleted = try await service.deleteCustomer(id: "cus_123", summary: "Delete customer")
    XCTAssertTrue(deleted.deleted)
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertEqual(request.httpMethod, "DELETE")
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/customers/cus_123"))
    XCTAssertNil(
      WriteStub.firstBodyString(), "delete takes no parameters and sends an empty body")
  }

  func testDeleteDiscountDecodesDeletedObject() async throws {
    let service = makeService(mode: .management)
    WriteStub.install(status: 200, json: discountDeleteFixture)
    let deleted = try await service.deleteDiscount(customer: "cus_123", summary: "Remove discount")
    XCTAssertTrue(deleted.deleted)
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/customers/cus_123/discount"))
  }

  // MARK: - Balance transactions

  func testCreateBalanceTransactionEncodesAmountAndMetadata() async throws {
    let service = makeService(mode: .management)
    WriteStub.install(status: 200, json: balanceTxnCreateFixture)
    let txn = try await service.createBalanceTransaction(
      customer: "cus_123", amount: 100, currency: "usd", description: "d",
      metadata: ["note": "gift"], summary: "Adjust balance")
    XCTAssertEqual(txn.id, "cbtxn_Rjdx6DoG52DHoLx")
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/customers/cus_123/balance_transactions"))
    XCTAssertEqual(
      try XCTUnwrap(WriteStub.firstBodyString()),
      "amount=100&currency=usd&description=d&metadata%5Bnote%5D=gift")
  }

  func testUpdateBalanceTransactionEncodesDescriptionAndMetadata() async throws {
    let service = makeService(mode: .management)
    WriteStub.install(status: 200, json: balanceTxnUpdateFixture)
    let txn = try await service.updateBalanceTransaction(
      customer: "cus_123", transaction: "bt_123", description: "d", metadata: ["note": "gift"],
      summary: "Update balance transaction")
    XCTAssertEqual(txn.description.valueOrNil, "x")
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertTrue(
      request.url!.path.hasSuffix("/v1/customers/cus_123/balance_transactions/bt_123"))
    XCTAssertEqual(
      try XCTUnwrap(WriteStub.firstBodyString()),
      "description=d&metadata%5Bnote%5D=gift")
  }

  // MARK: - Tax IDs

  func testCreateTaxIDEncodesTypeAndValue() async throws {
    let service = makeService(mode: .management)
    WriteStub.install(status: 200, json: taxIdCreateFixture)
    let taxID = try await service.createTaxID(
      customer: "cus_123", type: "eu_vat", value: "DE123456789", summary: "Add tax ID")
    XCTAssertEqual(taxID.type.rawValue, "eu_vat")
    XCTAssertEqual(taxID.value, "DE123456789")
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/customers/cus_123/tax_ids"))
    XCTAssertEqual(
      try XCTUnwrap(WriteStub.firstBodyString()), "type=eu_vat&value=DE123456789")
  }

  func testDeleteTaxIDSendsEmptyBody() async throws {
    let service = makeService(mode: .management)
    WriteStub.install(status: 200, json: taxIdDeleteFixture)
    let deleted = try await service.deleteTaxID(
      customer: "cus_123", id: "txi_123", summary: "Remove tax ID")
    XCTAssertTrue(deleted.deleted)
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/customers/cus_123/tax_ids/txi_123"))
    XCTAssertNil(
      WriteStub.firstBodyString(), "delete takes no parameters and sends an empty body")
  }

  // MARK: - Cash balance and funding

  func testCreateFundingInstructionsEncodesBankTransfer() async throws {
    let service = makeService(mode: .management)
    WriteStub.install(status: 200, json: fundingInstructionsFixture)
    let funding = try await service.createFundingInstructions(
      customer: "cus_123", currency: "usd", summary: "Create funding instructions")
    XCTAssertEqual(funding.fundingType.rawValue, "bank_transfer")
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertTrue(
      request.url!.path.hasSuffix("/v1/customers/cus_123/funding_instructions"))
    XCTAssertEqual(
      try XCTUnwrap(WriteStub.firstBodyString()),
      "bank_transfer%5Btype%5D=eu_bank_transfer&currency=usd&funding_type=bank_transfer")
  }

  func testFundCashBalanceHitsTestHelpersEndpoint() async throws {
    let service = makeService(mode: .management)
    WriteStub.install(status: 200, json: cashBalanceFundFixture)
    let txn = try await service.fundCashBalance(
      customer: "cus_123", amount: 100, currency: "usd", summary: "Fund cash balance")
    XCTAssertEqual(txn.id, "ccsbtxn_Rje2kwSDFurifvP")
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertTrue(
      request.url!.path.hasSuffix("/v1/test_helpers/customers/cus_123/fund_cash_balance"))
    XCTAssertEqual(
      try XCTUnwrap(WriteStub.firstBodyString()), "amount=100&currency=usd")
  }

  // MARK: - Dashboard lock

  func testDashboardModeRefusesCreateCustomerBeforeNetwork() async throws {
    let service = makeService(mode: .dashboard)
    do {
      _ = try await service.createCustomer(
        email: nil, name: nil, description: nil, metadata: nil, summary: "Create customer")
      XCTFail("dashboard-mode write should throw")
    } catch let error as CustomersWriteError {
      XCTAssertEqual(error, .dashboardMode)
    } catch {
      XCTFail("Expected CustomersWriteError.dashboardMode, got \(error)")
    }
    XCTAssertTrue(
      WriteStubURLProtocol.recordedRequests.isEmpty,
      "a dashboard-mode customer create reached the network")
    let entries = await audit.entries(limit: 10)
    XCTAssertEqual(entries.count, 1)
    XCTAssertEqual(entries[0].outcome, "refused: dashboard mode")
    XCTAssertEqual(entries[0].path, "/v1/customers")
  }

  func testDashboardModeRefusesDeleteCustomerBeforeNetwork() async throws {
    let service = makeService(mode: .dashboard)
    do {
      _ = try await service.deleteCustomer(id: "cus_123", summary: "Delete customer")
      XCTFail("dashboard-mode write should throw")
    } catch let error as CustomersWriteError {
      XCTAssertEqual(error, .dashboardMode)
    } catch {
      XCTFail("Expected CustomersWriteError.dashboardMode, got \(error)")
    }
    XCTAssertTrue(
      WriteStubURLProtocol.recordedRequests.isEmpty,
      "a dashboard-mode customer delete reached the network")
    let entries = await audit.entries(limit: 10)
    XCTAssertEqual(entries.count, 1)
    XCTAssertEqual(entries[0].outcome, "refused: dashboard mode")
    XCTAssertEqual(entries[0].method, "DELETE")
    XCTAssertEqual(entries[0].path, "/v1/customers/cus_123")
  }

  // MARK: - Failure recording

  func testAPIFailureIsRecordedInAuditAndRethrown() async throws {
    let service = makeService(mode: .management)
    WriteStub.install(status: 400, json: [
      "error": [
        "type": "invalid_request_error",
        "message": "Customer cus_123 has no pending invoice.",
      ]
    ])
    do {
      _ = try await service.createCustomer(
        email: nil, name: nil, description: nil, metadata: nil, summary: "Create customer")
      XCTFail("a 400 write should throw")
    } catch let error as StripeAPIError {
      XCTAssertEqual(error.status, 400)
      XCTAssertEqual(error.detail.message, "Customer cus_123 has no pending invoice.")
    } catch {
      XCTFail("Expected StripeAPIError, got \(error)")
    }
    let entries = await audit.entries(limit: 10)
    XCTAssertEqual(entries.count, 1)
    XCTAssertTrue(entries[0].outcome.hasPrefix("failed:"))
    XCTAssertTrue(
      entries[0].outcome.contains("has no pending invoice"),
      "audit entry should carry the API message, got \(entries[0].outcome)")
  }

  // MARK: - Every write carries a key

  /// Every write verb the service exposes sends a non-empty idempotency
  /// key. Loops over all verbs against per-verb fixtures and checks each
  /// recorded request.
  func testEveryWriteVerbCarriesIdempotencyKey() async throws {
    let service = makeService(mode: .management)

    func keyOf(_ request: URLRequest) -> String? {
      request.value(forHTTPHeaderField: "Idempotency-Key")
    }

    WriteStub.install(status: 200, json: customerWriteFixture)
    _ = try await service.createCustomer(
      email: "alice@example.com", name: nil, description: nil, metadata: nil, summary: "s")
    WriteStub.install(status: 200, json: customerWriteFixture)
    _ = try await service.updateCustomer(
      id: "cus_123", email: nil, name: "Bob", description: nil, metadata: nil, summary: "s")
    WriteStub.install(status: 200, json: customerDeleteFixture)
    _ = try await service.deleteCustomer(id: "cus_123", summary: "s")
    WriteStub.install(status: 200, json: discountDeleteFixture)
    _ = try await service.deleteDiscount(customer: "cus_123", summary: "s")
    WriteStub.install(status: 200, json: balanceTxnCreateFixture)
    _ = try await service.createBalanceTransaction(
      customer: "cus_123", amount: 100, currency: "usd", description: nil, metadata: nil,
      summary: "s")
    WriteStub.install(status: 200, json: balanceTxnUpdateFixture)
    _ = try await service.updateBalanceTransaction(
      customer: "cus_123", transaction: "bt_123", description: nil, metadata: nil, summary: "s")
    WriteStub.install(status: 200, json: taxIdCreateFixture)
    _ = try await service.createTaxID(
      customer: "cus_123", type: "eu_vat", value: "DE123456789", summary: "s")
    WriteStub.install(status: 200, json: taxIdDeleteFixture)
    _ = try await service.deleteTaxID(customer: "cus_123", id: "txi_123", summary: "s")
    WriteStub.install(status: 200, json: fundingInstructionsFixture)
    _ = try await service.createFundingInstructions(
      customer: "cus_123", currency: "usd", summary: "s")
    WriteStub.install(status: 200, json: cashBalanceFundFixture)
    _ = try await service.fundCashBalance(
      customer: "cus_123", amount: 100, currency: "usd", summary: "s")

    let requests = WriteStubURLProtocol.recordedRequests
    XCTAssertEqual(requests.count, 10, "one request per verb")
    for (index, request) in requests.enumerated() {
      let key = try XCTUnwrap(keyOf(request), "request \(index) carries no idempotency key")
      XCTAssertFalse(key.isEmpty, "request \(index) carries an empty idempotency key")
    }
    let entries = await audit.entries(limit: 16)
    XCTAssertEqual(entries.count, 10)
    let auditedKeys = Set(entries.map(\.idempotencyKey))
    let sentKeys = Set(requests.compactMap(keyOf))
    XCTAssertEqual(auditedKeys, sentKeys, "audit keys must match the sent keys exactly")
  }

  // MARK: - Audit linkage

  func testAuditEntryCarriesAccountAndSummary() async throws {
    let service = makeService(mode: .management)
    WriteStub.install(
      status: 200, json: customerWriteFixture, headers: ["Request-Id": "req_test_123"])
    _ = try await service.createCustomer(
      email: nil, name: nil, description: nil, metadata: nil, summary: "Create customer")
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    let headerKey = try XCTUnwrap(request.value(forHTTPHeaderField: "Idempotency-Key"))
    let entries = await audit.entries(limit: 10)
    XCTAssertEqual(entries[0].idempotencyKey, headerKey, "audit key must match the sent key")
    XCTAssertEqual(entries[0].requestID, "req_test_123")
    XCTAssertEqual(entries[0].outcome, "succeeded")
    XCTAssertEqual(entries[0].accountID, "acct_test_123")
    XCTAssertEqual(entries[0].accountName, "Shot Store")
    XCTAssertEqual(entries[0].summary, "Create customer")
  }
}
