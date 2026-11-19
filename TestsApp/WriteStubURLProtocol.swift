// WriteStubURLProtocol.swift — Tests/GeistDataTests
// Minimal request-recording URLProtocol for write-service tests. Intercepts
// everything aimed at the stub base URL (port 1), records the request
// (with its drained body and headers), and delegates to a test-provided
// handler for the response.

import Foundation
import XCTest

/// What a stub handler answers with.
enum RecordingResponse {
  case data(Data)
  case httpResponse(HTTPURLResponse, Data)
  case error(Error)
}

final class WriteStubState: @unchecked Sendable {
  private let lock = NSLock()
  private var handler: (@Sendable (URLRequest) -> RecordingResponse)?
  private var recordedRequests: [URLRequest] = []

  var handlerValue: (@Sendable (URLRequest) -> RecordingResponse)? {
    get { lock.withLock { handler } }
    set { lock.withLock { handler = newValue } }
  }

  var recordedRequestsValue: [URLRequest] {
    get { lock.withLock { recordedRequests } }
    set { lock.withLock { recordedRequests = newValue } }
  }

  func reset() {
    lock.withLock {
      handler = nil
      recordedRequests = []
    }
  }
}

final class WriteStubURLProtocol: URLProtocol, @unchecked Sendable {
  static let state = WriteStubState()

  static var handler: (@Sendable (URLRequest) -> RecordingResponse)? {
    get { state.handlerValue }
    set { state.handlerValue = newValue }
  }

  static var recordedRequests: [URLRequest] {
    get { state.recordedRequestsValue }
  }

  static func reset() { state.reset() }

  // static_over_final_class doesn't account for the URLProtocol override
  // requirement that these be class members.
  // swiftlint:disable:next static_over_final_class
  override class func canInit(with request: URLRequest) -> Bool {
    guard let url = request.url else { return false }
    return url.host == "127.0.0.1" && url.port == 1 && url.scheme == "http"
  }

  // swiftlint:disable:next static_over_final_class
  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    request
  }

  override func startLoading() {
    var recorded = request
    if recorded.httpBody == nil, let stream = recorded.httpBodyStream {
      recorded.httpBody = Self.drain(stream)
    }
    WriteStubURLProtocol.state.recordedRequestsValue.append(recorded)

    guard let handler = WriteStubURLProtocol.handler else {
      client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
      return
    }
    switch handler(request) {
    case .data(let data):
      client?.urlProtocol(self, didLoad: data)
      client?.urlProtocolDidFinishLoading(self)
    case .httpResponse(let httpResponse, let data):
      client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: data)
      client?.urlProtocolDidFinishLoading(self)
    case .error(let error):
      client?.urlProtocol(self, didFailWithError: error)
    }
  }

  override func stopLoading() {}

  private static func drain(_ stream: InputStream) -> Data? {
    stream.open()
    defer { stream.close() }
    var data = Data()
    let bufferSize = 16_384
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { buffer.deallocate() }
    while stream.hasBytesAvailable {
      let read = stream.read(buffer, maxLength: bufferSize)
      if read <= 0 { break }
      data.append(buffer, count: read)
    }
    return data
  }
}

enum WriteStub {
  /// Complete base fixtures per object kind. Per-test keys override, so a
  /// test writes only the fields it asserts on and the stub still emits
  /// every field the generated decoders require. Error payloads pass
  /// through untouched. A malformed literal fixture is a test-authoring
  /// bug, so it aborts loudly.
  /// JSONSerialization mis-bridges empty Swift collections (`{}`, `[]`)
  /// boxed in `Any` on this toolchain: the empty-collection box is
  /// double-released during bridging and the heap corrupts (abort
  /// "freed pointer was not the last allocation", usually surfaced in
  /// whatever allocator context runs next). Copy the fixture into a
  /// pure Cocoa tree (NSDictionary/NSArray at every level) before
  /// serializing; the Cocoa path is the battle-tested one.
  private static func cocoaTree(_ value: Any) -> Any {
    if let d = value as? [String: Any] {
      let dict = NSMutableDictionary()
      for (k, v) in d { dict[k] = cocoaTree(v) }
      return NSDictionary(dictionary: dict)
    }
    if let a = value as? [Any] {
      return NSArray(array: a.map { cocoaTree($0) })
    }
    return value
  }

  static func install(status: Int, json: [String: Any], headers: [String: String] = [:]) {
    var merged: [String: Any] = json
    if json["error"] == nil {
      let base: [String: Any]
      switch json["object"] as? String {
      case "charge": base = chargeFixture
      case "payment_intent": base = intentFixture
      default: base = refundFixture
      }
      merged = base.merging(json) { _, new in new }
    }
    let body: Data
    do {
      body = try JSONSerialization.data(withJSONObject: cocoaTree(merged), options: [])
    } catch {
      fatalError("invalid test fixture: \(error)")
    }
    install(status: status, body: body, headers: headers)
  }

  private nonisolated(unsafe) static let null = NSNull()

  private nonisolated(unsafe) static let refundFixture: [String: Any] = [
    "amount": 1500, "balance_transaction": null, "charge": "ch_test_123",
    "created": 1_700_000_000, "currency": "usd", "customer": null,
    "customer_account": null, "id": "re_test_123", "livemode": false,
    "metadata": null, "object": "refund", "payment_intent": null,
    "payment_method": null, "reason": null, "receipt_number": null,
    "source_transfer_reversal": null, "status": "succeeded",
    "transfer_reversal": null,
  ]

  private nonisolated(unsafe) static let chargeFixture: [String: Any] = [
    "amount": 1500, "amount_captured": 1500, "amount_refunded": 0,
    "application": null, "application_fee": null, "application_fee_amount": null,
    "balance_transaction": null, "billing_details": [:],
    "calculated_statement_descriptor": null, "captured": true,
    "created": 1_700_000_000, "currency": "usd", "customer": null,
    "description": null, "disputed": false, "failure_balance_transaction": null,
    "failure_code": null, "failure_message": null, "fraud_details": null,
    "id": "ch_test_123", "livemode": false, "metadata": [:], "object": "charge",
    "on_behalf_of": null, "outcome": null, "paid": true, "payment_intent": null,
    "payment_method": null, "payment_method_details": null, "receipt_email": null,
    "receipt_number": null, "receipt_url": null, "refunded": false,
    "review": null, "shipping": null, "source": null, "source_transfer": null,
    "statement_descriptor": null, "statement_descriptor_suffix": null,
    "status": "succeeded", "transfer_data": null, "transfer_group": null,
  ]

  private nonisolated(unsafe) static let intentFixture: [String: Any] = [
    "allowed_payment_method_types": null, "amount": 1500,
    "amount_capturable": 0, "amount_received": 0, "application": null,
    "application_fee_amount": null, "automatic_payment_methods": null,
    "canceled_at": null, "cancellation_reason": null, "capture_method": "automatic",
    "client_secret": "pi_test_secret", "confirmation_method": "automatic",
    "created": 1_700_000_000, "currency": "usd", "customer": null,
    "customer_account": null, "description": null,
    "excluded_payment_method_types": null, "id": "pi_test_123",
    "last_payment_error": null, "latest_charge": null, "livemode": false,
    "managed_payments": null, "metadata": [:], "next_action": null,
    "object": "payment_intent", "on_behalf_of": null, "payment_method": null,
    "payment_method_configuration_details": null, "payment_method_options": null,
    "payment_method_types": ["card"], "payment_record": null,
    "processing": null, "receipt_email": null, "review": null,
    "setup_future_usage": null, "shipping": null, "source": null,
    "statement_descriptor": null, "statement_descriptor_suffix": null,
    "status": "succeeded", "transfer_group": null,
  ]

  static func install(status: Int, body: Data, headers: [String: String] = [:]) {
    WriteStubURLProtocol.handler = { _ in
      var allHeaders = headers
      allHeaders["Content-Type"] = "application/json"
      let response = HTTPURLResponse(
        url: URL(string: "http://127.0.0.1:1/stub")!,
        statusCode: status,
        httpVersion: nil,
        headerFields: allHeaders
      )!
      return RecordingResponse.httpResponse(response, body)
    }
  }

  /// Body of the first recorded request, or nil.
  static func firstBody() -> Data? {
    WriteStubURLProtocol.recordedRequests.first.flatMap { $0.httpBody }
  }

  /// Body of the first recorded request as a form-urlencoded string.
  static func firstBodyString() -> String? {
    firstBody().flatMap { String(data: $0, encoding: .utf8) }
  }
}
