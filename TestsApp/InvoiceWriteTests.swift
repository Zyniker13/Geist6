// InvoiceWriteTests.swift — TestsApp
// The M6 invoice writes: refuse in dashboard mode before any network
// traffic, carry an idempotency key, encode their parameters, decode the
// stripe-mock response shapes, and record the attempt in the audit log.
// Stubbed transport; no real network is touched.

import XCTest

@testable import GeistData
@testable import StripeClient
import StripeModels

@MainActor
final class InvoiceWriteTests: XCTestCase {

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
    dashboardLocked: @escaping @MainActor @Sendable () async -> Bool
  ) -> BillingWriteService {
    let client = StripeClient(
      apiKey: "sk_test_fake", mode: mode,
      baseURL: URL(string: "http://127.0.0.1:1")!, session: Self.stubSession)
    return BillingWriteService(
      client: client, accountID: "acct_test_123", accountName: "Shot Store", audit: audit,
      dashboardLocked: dashboardLocked)
  }

  // MARK: - Draft edits

  func testCreateInvoiceEncodesCustomerAndMetadata() async throws {
    let service = makeService(mode: .management, dashboardLocked: { false })
    WriteStub.install(status: 200, json: invoiceWriteFixture)
    let invoice = try await service.createInvoice(
      draft: .init(
        customer: "cus_123", description: "Draft work", footer: nil,
        metadata: ["note": "gift"]),
      summary: "Create invoice")
    XCTAssertEqual(invoice.id, "in_123")
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/invoices"))
    XCTAssertEqual(
      try XCTUnwrap(WriteStub.firstBodyString()),
      "customer=cus_123&description=Draft+work&metadata%5Bnote%5D=gift")
  }

  func testUpdateInvoiceEncodesOnlySetFields() async throws {
    let service = makeService(mode: .management, dashboardLocked: { false })
    WriteStub.install(status: 200, json: invoiceWriteFixture)
    let invoice = try await service.updateInvoice(
      id: "in_123",
      update: .init(description: "Renamed", footer: "Thanks", metadata: nil),
      summary: "Update invoice")
    XCTAssertEqual(invoice.id, "in_123")
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/invoices/in_123"))
    XCTAssertEqual(
      try XCTUnwrap(WriteStub.firstBodyString()),
      "description=Renamed&footer=Thanks")
  }

  func testAddInvoiceLineEncodesNestedLine() async throws {
    let service = makeService(mode: .management, dashboardLocked: { false })
    WriteStub.install(status: 200, json: invoiceWriteFixture)
    let invoice = try await service.addInvoiceLine(
      invoice: "in_123",
      line: .init(description: "New line", amount: 1500, quantity: 2),
      summary: "Add invoice line")
    XCTAssertEqual(invoice.id, "in_123")
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/invoices/in_123/add_lines"))
    XCTAssertEqual(
      try XCTUnwrap(WriteStub.firstBodyString()),
      "lines%5B0%5D%5Bamount%5D=1500&lines%5B0%5D%5Bdescription%5D=New+line"
        + "&lines%5B0%5D%5Bquantity%5D=2")
  }

  func testUpdateInvoiceLineEncodesIdWithinNestedLine() async throws {
    let service = makeService(mode: .management, dashboardLocked: { false })
    WriteStub.install(status: 200, json: invoiceWriteFixture)
    let invoice = try await service.updateInvoiceLine(
      invoice: "in_123", lineID: "il_123", description: "Updated", quantity: 3,
      summary: "Update invoice line")
    XCTAssertEqual(invoice.id, "in_123")
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/invoices/in_123/update_lines"))
    XCTAssertEqual(
      try XCTUnwrap(WriteStub.firstBodyString()),
      "lines%5B0%5D%5Bdescription%5D=Updated&lines%5B0%5D%5Bid%5D=il_123"
        + "&lines%5B0%5D%5Bquantity%5D=3")
  }

  func testRemoveInvoiceLineEncodesBehaviorAndId() async throws {
    let service = makeService(mode: .management, dashboardLocked: { false })
    WriteStub.install(status: 200, json: invoiceWriteFixture)
    let invoice = try await service.removeInvoiceLine(
      invoice: "in_123", lineID: "il_123", summary: "Remove invoice line")
    XCTAssertEqual(invoice.id, "in_123")
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/invoices/in_123/remove_lines"))
    XCTAssertEqual(
      try XCTUnwrap(WriteStub.firstBodyString()),
      "lines%5B0%5D%5Bbehavior%5D=delete&lines%5B0%5D%5Bid%5D=il_123")
  }

  // MARK: - Lifecycle

  func testFinalizeInvoiceSendsEmptyBodyAndDecodesInvoice() async throws {
    let service = makeService(mode: .management, dashboardLocked: { false })
    WriteStub.install(status: 200, json: invoiceFinalizedFixture)
    let invoice = try await service.finalizeInvoice(id: "in_123", summary: "Finalize invoice")
    XCTAssertEqual(invoice.id, "in_123")
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/invoices/in_123/finalize"))
    XCTAssertNil(
      WriteStub.firstBodyString(),
      "finalize takes no parameters")
  }

  func testSendInvoiceSendsEmptyBody() async throws {
    let service = makeService(mode: .management, dashboardLocked: { false })
    WriteStub.install(status: 200, json: invoiceFinalizedFixture)
    let invoice = try await service.sendInvoice(id: "in_123", summary: "Send invoice")
    XCTAssertEqual(invoice.id, "in_123")
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/invoices/in_123/send"))
    XCTAssertNil(
      WriteStub.firstBodyString(),
      "send takes no parameters")
  }

  func testPayInvoiceSendsEmptyBody() async throws {
    let service = makeService(mode: .management, dashboardLocked: { false })
    WriteStub.install(status: 200, json: invoiceFinalizedFixture)
    let invoice = try await service.payInvoice(id: "in_123", summary: "Pay invoice")
    XCTAssertEqual(invoice.id, "in_123")
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/invoices/in_123/pay"))
    XCTAssertNil(
      WriteStub.firstBodyString(),
      "pay takes no parameters")
  }

  func testVoidInvoiceSendsEmptyBody() async throws {
    let service = makeService(mode: .management, dashboardLocked: { false })
    WriteStub.install(status: 200, json: invoiceFinalizedFixture)
    let invoice = try await service.voidInvoice(id: "in_123", summary: "Void invoice")
    XCTAssertEqual(invoice.id, "in_123")
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/invoices/in_123/void"))
    XCTAssertNil(
      WriteStub.firstBodyString(),
      "void takes no parameters")
  }

  func testMarkUncollectibleSendsEmptyBody() async throws {
    let service = makeService(mode: .management, dashboardLocked: { false })
    WriteStub.install(status: 200, json: invoiceFinalizedFixture)
    let invoice = try await service.markInvoiceUncollectible(
      id: "in_123", summary: "Mark invoice uncollectible")
    XCTAssertEqual(invoice.id, "in_123")
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/invoices/in_123/mark_uncollectible"))
    XCTAssertNil(
      WriteStub.firstBodyString(),
      "mark uncollectible takes no parameters")
  }

  func testDeleteInvoiceSendsEmptyBodyAndDecodesDeletedObject() async throws {
    let service = makeService(mode: .management, dashboardLocked: { false })
    WriteStub.install(status: 200, json: invoiceDeleteFixture)
    let deleted = try await service.deleteInvoice(id: "in_123", summary: "Delete invoice")
    XCTAssertEqual(deleted.id, "in_123")
    XCTAssertTrue(deleted.deleted)
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertEqual(request.httpMethod, "DELETE")
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/invoices/in_123"))
    XCTAssertNil(
      WriteStub.firstBodyString(),
      "delete takes no parameters")
  }

  // MARK: - Dashboard-mode gates

  func testDashboardModeRefusesCreateInvoice() async throws {
    let service = makeService(mode: .dashboard, dashboardLocked: { false })
    do {
      _ = try await service.createInvoice(
        draft: .init(customer: "cus_123", description: nil, footer: nil, metadata: nil),
        summary: "Create invoice")
      XCTFail("dashboard mode must refuse the write")
    } catch let error as BillingWriteError {
      XCTAssertEqual(error, .dashboardMode)
    }
    let entries = await audit.entries(limit: 10)
    XCTAssertEqual(entries.count, 1)
    XCTAssertEqual(entries[0].outcome, "refused: dashboard mode")
    XCTAssertTrue(entries[0].path.hasSuffix("/v1/invoices"))
  }

  func testDashboardLockedAccountRefusesVoidInvoice() async throws {
    let service = makeService(mode: .management, dashboardLocked: { true })
    do {
      _ = try await service.voidInvoice(id: "in_123", summary: "Void invoice")
      XCTFail("a locked account must refuse the write")
    } catch let error as BillingWriteError {
      XCTAssertEqual(error, .dashboardMode)
    }
    let entries = await audit.entries(limit: 10)
    XCTAssertEqual(entries.count, 1)
    XCTAssertEqual(entries[0].outcome, "refused: dashboard mode")
    XCTAssertTrue(entries[0].path.hasSuffix("/v1/invoices/in_123/void"))
  }

  // MARK: - Idempotency and audit

  func testEveryInvoiceWriteVerbCarriesIdempotencyKey() async throws {
    let service = makeService(mode: .management, dashboardLocked: { false })

    func keyOf(_ request: URLRequest) -> String? {
      request.value(forHTTPHeaderField: "Idempotency-Key")
    }

    WriteStub.install(status: 200, json: invoiceWriteFixture)
    _ = try await service.createInvoice(
      draft: .init(customer: "cus_123", description: nil, footer: nil, metadata: nil),
      summary: "s")
    WriteStub.install(status: 200, json: invoiceWriteFixture)
    _ = try await service.updateInvoice(
      id: "in_123", update: .init(description: "Renamed", footer: nil, metadata: nil),
      summary: "s")
    WriteStub.install(status: 200, json: invoiceWriteFixture)
    _ = try await service.addInvoiceLine(
      invoice: "in_123", line: .init(description: "New line", amount: 1500, quantity: nil),
      summary: "s")
    WriteStub.install(status: 200, json: invoiceWriteFixture)
    _ = try await service.updateInvoiceLine(
      invoice: "in_123", lineID: "il_123", description: nil, quantity: 3, summary: "s")
    WriteStub.install(status: 200, json: invoiceWriteFixture)
    _ = try await service.removeInvoiceLine(invoice: "in_123", lineID: "il_123", summary: "s")
    WriteStub.install(status: 200, json: invoiceFinalizedFixture)
    _ = try await service.finalizeInvoice(id: "in_123", summary: "s")
    WriteStub.install(status: 200, json: invoiceFinalizedFixture)
    _ = try await service.sendInvoice(id: "in_123", summary: "s")
    WriteStub.install(status: 200, json: invoiceFinalizedFixture)
    _ = try await service.payInvoice(id: "in_123", summary: "s")
    WriteStub.install(status: 200, json: invoiceFinalizedFixture)
    _ = try await service.voidInvoice(id: "in_123", summary: "s")
    WriteStub.install(status: 200, json: invoiceFinalizedFixture)
    _ = try await service.markInvoiceUncollectible(id: "in_123", summary: "s")
    WriteStub.install(status: 200, json: invoiceDeleteFixture)
    _ = try await service.deleteInvoice(id: "in_123", summary: "s")

    let requests = WriteStubURLProtocol.recordedRequests
    XCTAssertEqual(requests.count, 11, "one request per verb")
    for (index, request) in requests.enumerated() {
      let key = try XCTUnwrap(keyOf(request), "request \(index) carries no idempotency key")
      XCTAssertFalse(key.isEmpty, "request \(index) carries an empty idempotency key")
    }
    let entries = await audit.entries(limit: 20)
    XCTAssertEqual(entries.count, 11)
    let auditedKeys = Set(entries.map(\.idempotencyKey))
    let sentKeys = Set(requests.compactMap(keyOf))
    XCTAssertEqual(auditedKeys, sentKeys, "audit keys must match the sent keys exactly")
  }

  func testAuditEntryCarriesAccountAndSummary() async throws {
    let service = makeService(mode: .management, dashboardLocked: { false })
    WriteStub.install(
      status: 200, json: invoiceWriteFixture,
      headers: ["Request-Id": "req_test_123"])
    _ = try await service.createInvoice(
      draft: .init(customer: "cus_123", description: nil, footer: nil, metadata: nil),
      summary: "Create invoice")
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    let headerKey = try XCTUnwrap(request.value(forHTTPHeaderField: "Idempotency-Key"))
    let entries = await audit.entries(limit: 10)
    XCTAssertEqual(entries[0].idempotencyKey, headerKey, "audit key must match the sent key")
    XCTAssertEqual(entries[0].requestID, "req_test_123")
    XCTAssertEqual(entries[0].outcome, "succeeded")
    XCTAssertEqual(entries[0].accountID, "acct_test_123")
    XCTAssertEqual(entries[0].accountName, "Shot Store")
    XCTAssertEqual(entries[0].summary, "Create invoice")
  }
}
