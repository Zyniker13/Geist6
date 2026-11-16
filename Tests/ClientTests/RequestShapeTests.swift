// RequestShapeTests.swift — Tests/ClientTests
// Tests for request headers, form encoding, idempotency, error parsing,
// and retry logic using the URLProtocol stub.

import XCTest
@testable import StripeClient
import StripeModels

@MainActor
final class RequestShapeTests: XCTestCase {

  func makeClient() -> StripeClient {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [RecordingURLProtocol.self]
    RecordingURLProtocol.recordedRequests = []
    RecordingURLProtocol.recordedResponses = []
    return StripeClient(
      apiKey: "sk_test_fake", mode: .management, baseURL: URL(string: "http://127.0.0.1:1")!,
      configuration: config)
  }

  // MARK: - Authorization header

  func testAuthorizationHeader() async {
    let client = makeClient()
    StubBuilder.install(status: 200, json: [:])
    do {
      _ = try await client.perform(
        method: "GET", path: "/v1/charges", params: nil as EmptyParams?)
    } catch { XCTFail("Should not throw") }
    XCTAssertEqual(RecordingURLProtocol.recordedRequests.first?.value(forHTTPHeaderField: "Authorization"), "Bearer sk_test_fake")
  }

  func testStripeAccountHeader() async {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [RecordingURLProtocol.self]
    RecordingURLProtocol.recordedRequests = []
    RecordingURLProtocol.recordedResponses = []
    let client = StripeClient(
      apiKey: "sk_test_fake", mode: .management, stripeAccount: "acct_connected1",
      baseURL: URL(string: "http://127.0.0.1:1")!, configuration: config)
    StubBuilder.install(status: 200, json: [:])
    do {
      _ = try await client.perform(
        method: "GET", path: "/v1/charges", params: nil as EmptyParams?)
    } catch { XCTFail("Should not throw") }
    XCTAssertEqual(RecordingURLProtocol.recordedRequests.first?.value(forHTTPHeaderField: "Stripe-Account"), "acct_connected1")
  }

  // MARK: - Form encoding (POST with params)

  func testPostFormEncoding() async {
    let client = makeClient()
    let params = CustomerCreateParams(email: "alice@example.com", name: "Alice")
    StubBuilder.install(status: 200, json: ["id": "cus_1"])
    do {
      _ = try await client.perform(
        method: "POST", path: "/v1/customers", params: params)
    } catch { XCTFail("Should not throw") }
    let body = RecordingURLProtocol.recordedRequests.first?.httpBody
    let bodyStr = String(data: body!, encoding: .utf8)!
    XCTAssertTrue(bodyStr.contains("email=alice%40example.com"))
    XCTAssertTrue(bodyStr.contains("name=Alice"))
  }

  // MARK: - Idempotency key on POST

  func testIdempotencyKeyOnPost() async {
    let client = makeClient()
    let params = CustomerCreateParams(email: "a@b.com")
    StubBuilder.install(status: 200, json: ["id": "cus_1"])
    do {
      _ = try await client.perform(
        method: "POST", path: "/v1/customers", params: params)
    } catch { XCTFail("Should not throw") }
    let key = RecordingURLProtocol.recordedRequests.first?.value(forHTTPHeaderField: "Idempotency-Key")
    XCTAssertNotNil(key)
    XCTAssertFalse(key!.isEmpty)
  }

  func testCustomIdempotencyKey() async {
    let client = makeClient()
    let params = CustomerCreateParams(email: "a@b.com")
    StubBuilder.install(status: 200, json: ["id": "cus_1"])
    do {
      _ = try await client.perform(
        method: "POST", path: "/v1/customers", params: params,
        idempotencyKey: "my-key-123")
    } catch { XCTFail("Should not throw") }
    let key = RecordingURLProtocol.recordedRequests.first?.value(forHTTPHeaderField: "Idempotency-Key")
    XCTAssertEqual(key, "my-key-123")
  }

  // MARK: - No idempotency key on GET

  func testNoIdempotencyKeyOnGet() async {
    let client = makeClient()
    StubBuilder.install(status: 200, json: ["data": [], "has_more": false])
    do {
      _ = try await client.perform(
        method: "GET", path: "/v1/charges", params: nil as EmptyParams?)
    } catch { XCTFail("Should not throw") }
    let key = RecordingURLProtocol.recordedRequests.first?.value(forHTTPHeaderField: "Idempotency-Key")
    XCTAssertNil(key)
  }

  // MARK: - No idempotency key on DELETE

  func testNoIdempotencyKeyOnDelete() async {
    let client = makeClient()
    StubBuilder.install(status: 200, json: ["id": "cus_1", "deleted": true])
    do {
      _ = try await client.perform(
        method: "DELETE", path: "/v1/customers/cus_1", params: nil as EmptyParams?)
    } catch { XCTFail("Should not throw") }
    let key = RecordingURLProtocol.recordedRequests.first?.value(forHTTPHeaderField: "Idempotency-Key")
    XCTAssertNil(key)
  }

  // MARK: - Error parsing

  func testParseInvalidRequestError() async {
    let client = makeClient()
    let body = try! JSONSerialization.data(withJSONObject: [
      "error": ["type": "invalid_request_error", "message": "Missing required param: email"]
    ])
    StubBuilder.install(status: 400, body: body)
    do {
      _ = try await client.perform(
        method: "POST", path: "/v1/customers", params: nil as EmptyParams?)
      XCTFail("Should throw")
    } catch let error as StripeAPIError {
      XCTAssertEqual(error.httpStatus, 400)
      XCTAssertEqual(error.type, .invalidRequestError)
      XCTAssertNotNil(error.message)
    } catch {
      XCTFail("Expected StripeAPIError, got \(error)")
    }
  }

  func testParseCardError() async {
    let client = makeClient()
    let body = try! JSONSerialization.data(withJSONObject: [
      "error": ["type": "card_error", "message": "Your card was declined", "code": "card_declined"]
    ])
    StubBuilder.install(status: 402, body: body)
    do {
      _ = try await client.perform(
        method: "POST", path: "/v1/charges", params: nil as EmptyParams?)
      XCTFail("Should throw")
    } catch let error as StripeAPIError {
      XCTAssertEqual(error.httpStatus, 402)
      XCTAssertEqual(error.type, .cardError)
      XCTAssertEqual(error.code, "card_declined")
    } catch {
      XCTFail("Expected StripeAPIError, got \(error)")
    }
  }

  func testParseApiError() async {
    let client = makeClient()
    let body = try! JSONSerialization.data(withJSONObject: [
      "error": ["type": "api_error", "message": "Stripe is down"]
    ])
    StubBuilder.install(status: 500, body: body)
    do {
      _ = try await client.perform(
        method: "GET", path: "/v1/charges", params: nil as EmptyParams?)
      XCTFail("Should throw")
    } catch let error as StripeAPIError {
      XCTAssertEqual(error.httpStatus, 500)
      XCTAssertEqual(error.type, .apiError)
    } catch {
      XCTFail("Expected StripeAPIError, got \(error)")
    }
  }

  // MARK: - Retry on 500

  func testRetryOn500() async {
    let client = makeClient()
    var count = 0
    RecordingURLProtocol.handler = { _ in
      count += 1
      if count <= 2 {
        return RecordingResponse.httpResponse(
          HTTPURLResponse(
            url: URL(string: "http://127.0.0.1:1/stub")!,
            statusCode: 500, httpVersion: nil, headerFields: nil)!,
          try! JSONSerialization.data(withJSONObject: [
            "error": ["type": "api_error", "message": "Server error"]]))
      }
      return RecordingResponse.httpResponse(
        HTTPURLResponse(
          url: URL(string: "http://127.0.0.1:1/stub")!,
          statusCode: 200, httpVersion: nil, headerFields: nil)!,
        try! JSONSerialization.data(withJSONObject: ["data": []]))
    }
    do {
      let result = try await client.perform(
        method: "GET", path: "/v1/charges", params: nil as EmptyParams?)
      XCTAssertNotNil(result.body)
    } catch { XCTFail("Should not throw after retries") }
    XCTAssertEqual(count, 3, "Should retry twice then succeed")
  }

  func testNoRetryOn400() async {
    let client = makeClient()
    var count = 0
    RecordingURLProtocol.handler = { _ in
      count += 1
      return RecordingResponse.httpResponse(
        HTTPURLResponse(
          url: URL(string: "http://127.0.0.1:1/stub")!,
          statusCode: 400, httpVersion: nil, headerFields: nil)!,
        try! JSONSerialization.data(withJSONObject: [
          "error": ["type": "invalid_request_error", "message": "Bad"]]))
    }
    do {
      _ = try await client.perform(
        method: "POST", path: "/v1/customers", params: nil as EmptyParams?)
      XCTFail("Should throw")
    } catch {
      XCTAssertEqual(count, 1, "Should not retry on 400")
    }
  }

  // MARK: - Query params on GET

  func testQueryParamsOnGet() async {
    let client = makeClient()
    StubBuilder.install(status: 200, json: ["data": [], "has_more": false])
    do {
      _ = try await client.perform(
        method: "GET", path: "/v1/charges", params: ["limit": "10", "starting_after": "ch_123"])
    } catch { XCTFail("Should not throw") }
    let url = RecordingURLProtocol.recordedRequests.first?.url?.absoluteString
    XCTAssertTrue(url!.contains("limit=10"))
    XCTAssertTrue(url!.contains("starting_after=ch_123"))
  }

  // MARK: - Stripe-Version header

  func testStripeVersionHeader() async {
    let client = makeClient()
    StubBuilder.install(status: 200, json: [:])
    do {
      _ = try await client.perform(
        method: "GET", path: "/v1/charges", params: nil as EmptyParams?)
    } catch { XCTFail("Should not throw") }
    let version = RecordingURLProtocol.recordedRequests.first?.value(forHTTPHeaderField: "Stripe-Version")
    XCTAssertEqual(version, StripeClient.defaultApiVersion)
  }
}
