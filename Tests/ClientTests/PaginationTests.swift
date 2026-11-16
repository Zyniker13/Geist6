// PaginationTests.swift — Tests/ClientTests
// Tests forward/back pagination and collectAll using URLProtocol stubs.
// stripe-mock returns has_more=False always, so pagination is tested
// via stubbed fixtures that exercise the pagination logic directly.

import XCTest
@testable import StripeClient
import StripeModels

@MainActor
final class PaginationTests: XCTestCase {

  func makeClient() -> StripeClient {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [RecordingURLProtocol.self]
    RecordingURLProtocol.recordedRequests = []
    RecordingURLProtocol.recordedResponses = []
    return StripeClient(
      apiKey: "sk_test_fake", mode: .management, baseURL: URL(string: "http://127.0.0.1:1")!,
      configuration: config)
  }

  /// Minimal Charge fixture covering every key the generated decoder
  /// requires (required non-nullable fields must be present). Marked
  /// nonisolated so URLProtocol handler closures (which run on a
  /// URLSession queue, not the main actor) can call it without tripping
  /// Swift 6 dynamic actor-isolation enforcement.
  private nonisolated static func stubCharge(id: String, amount: Int) -> [String: Any] {
    [
      "id": id,
      "object": "charge",
      "amount": amount,
      "amount_captured": amount,
      "amount_refunded": 0,
      "billing_details": [String: Any](),
      "captured": true,
      "created": 1_700_000_000,
      "currency": "usd",
      "disputed": false,
      "livemode": false,
      "metadata": [String: String](),
      "paid": true,
      "refunded": false,
      "status": "succeeded",
    ]
  }

  // MARK: - collectAll

  func testCollectAll() async {
    let client = makeClient()
    let counter = ThreadSafeCounter()
    RecordingURLProtocol.handler = { _ in
      let page = counter.increment()
      let charges = (0..<3).map { i in
        Self.stubCharge(id: "ch_page\(page)_\(i)", amount: 100 * (i + 1))
      }
      return RecordingResponse.httpResponse(
        HTTPURLResponse(
          url: URL(string: "http://127.0.0.1:1/stub")!,
          statusCode: 200, httpVersion: nil, headerFields: nil)!,
        try! JSONSerialization.data(withJSONObject: [
          "data": charges, "has_more": page < 2,
          "url": "/v1/charges"
        ]))
    }
    let initialPage: ListResponse<Charge>
    do {
      initialPage = try StripeClient.decoder.decode(
        ListResponse<Charge>.self,
        from: try await client.perform(
          method: "GET", path: "/v1/charges", params: ["limit": "3"]).body)
    } catch {
      XCTFail("collectAll failed: \(error)")
      return
    }
    let params = ChargeListParams(limit: 3)
    let allCharges: [Charge]
    do {
      allCharges = try await StripeClient.collectAll(
        initialPage,
        params: params,
        fetch: { params in
          try StripeClient.decoder.decode(
            ListResponse<Charge>.self,
            from: try await client.perform(
              method: "GET", path: "/v1/charges", params: params).body)
        })
    } catch {
      XCTFail("collectAll failed: \(error)")
      return
    }
    XCTAssertEqual(allCharges.count, 6) // 2 pages × 3
    XCTAssertEqual(counter.current, 2)
  }

  func testCollectAllSinglePage() async {
    let client = makeClient()
    RecordingURLProtocol.handler = { _ in
      RecordingResponse.httpResponse(
        HTTPURLResponse(
          url: URL(string: "http://127.0.0.1:1/stub")!,
          statusCode: 200, httpVersion: nil, headerFields: nil)!,
        try! JSONSerialization.data(withJSONObject: [
          "data": [Self.stubCharge(id: "ch_1", amount: 100)],
          "has_more": false, "url": "/v1/charges"
        ]))
    }
    let initialPage: ListResponse<Charge>
    do {
      initialPage = try StripeClient.decoder.decode(
        ListResponse<Charge>.self,
        from: try await client.perform(
          method: "GET", path: "/v1/charges", params: ["limit": "3"]).body)
    } catch {
      XCTFail("collectAll failed: \(error)")
      return
    }
    let params = ChargeListParams(limit: 3)
    let allCharges: [Charge]
    do {
      allCharges = try await StripeClient.collectAll(
        initialPage,
        params: params,
        fetch: { params in
          try StripeClient.decoder.decode(
            ListResponse<Charge>.self,
            from: try await client.perform(
              method: "GET", path: "/v1/charges", params: params).body)
        })
    } catch {
      XCTFail("collectAll failed: \(error)")
      return
    }
    XCTAssertEqual(allCharges.count, 1)
  }

  func testCollectAllMaxPages() async {
    let client = makeClient()
    let counter = ThreadSafeCounter()
    RecordingURLProtocol.handler = { _ in
      let page = counter.increment()
      let charges = (0..<3).map { i in
        Self.stubCharge(id: "ch_page\(page)_\(i)", amount: 100 * (i + 1))
      }
      return RecordingResponse.httpResponse(
        HTTPURLResponse(
          url: URL(string: "http://127.0.0.1:1/stub")!,
          statusCode: 200, httpVersion: nil, headerFields: nil)!,
        try! JSONSerialization.data(withJSONObject: [
          "data": charges, "has_more": true,
          "url": "/v1/charges"
        ]))
    }
    let initialPage: ListResponse<Charge>
    do {
      initialPage = try StripeClient.decoder.decode(
        ListResponse<Charge>.self,
        from: try await client.perform(
          method: "GET", path: "/v1/charges", params: ["limit": "3"]).body)
    } catch {
      XCTFail("collectAll failed: \(error)")
      return
    }
    let params = ChargeListParams(limit: 3)
    let allCharges: [Charge]
    do {
      allCharges = try await StripeClient.collectAll(
        initialPage,
        params: params,
        maxPages: 3,
        fetch: { params in
          try StripeClient.decoder.decode(
            ListResponse<Charge>.self,
            from: try await client.perform(
              method: "GET", path: "/v1/charges", params: params).body)
        })
    } catch {
      XCTFail("collectAll failed: \(error)")
      return
    }
    XCTAssertEqual(allCharges.count, 9) // 3 pages × 3
    XCTAssertEqual(counter.current, 3)
  }
}
