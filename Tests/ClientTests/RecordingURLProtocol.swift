import Foundation
import XCTest
@testable import StripeClient

// MARK: - State (Sendable wrapper for mutable global state)

/// A Sendable container for RecordingURLProtocol mutable state.
/// Swift 6 requires all mutable global state to be wrapped in a
/// Sendable type.
final class State: @unchecked Sendable {
  // Handlers must be @Sendable: closures formed in @MainActor test code
  // otherwise inherit main-actor isolation, and invoking them from
  // URLSession's URLProtocol queue trips the dispatch main-thread
  // assertion at runtime.
  private var handler: (@Sendable (URLRequest) -> RecordingResponse)? = nil
  private var recordedRequests: [URLRequest] = []
  private var recordedResponses: [URLResponse] = []
  private let queue = DispatchQueue(label: "geist6.RecordingURLProtocol.State")

  var handlerValue: (@Sendable (URLRequest) -> RecordingResponse)? {
    get { queue.sync { handler } }
    set { queue.sync { handler = newValue } }
  }

  var recordedRequestsValue: [URLRequest] {
    get { queue.sync { recordedRequests } }
    set { queue.sync { recordedRequests = newValue } }
  }

  var recordedResponsesValue: [URLResponse] {
    get { queue.sync { recordedResponses } }
    set { queue.sync { recordedResponses = newValue } }
  }

  func appendRequest(_ req: URLRequest) {
    queue.sync { recordedRequests.append(req) }
  }

  func appendResponse(_ resp: URLResponse) {
    queue.sync { recordedResponses.append(resp) }
  }

  func reset() {
    queue.sync {
      handler = nil
      recordedRequests = []
      recordedResponses = []
    }
  }
}

// MARK: - ThreadSafeCounter

/// Counter that can be incremented from any queue. URLSession's
/// URLProtocol callbacks run off the main actor, so test handlers must
/// not mutate captured locals there (Swift 6 dynamic isolation
/// enforcement traps on the cross-actor access).
final class ThreadSafeCounter: @unchecked Sendable {
  private let lock = NSLock()
  private var value = 0
  func increment() -> Int {
    lock.lock()
    defer { lock.unlock() }
    value += 1
    return value
  }
  var current: Int {
    lock.lock()
    defer { lock.unlock() }
    return value
  }
}

// MARK: - RecordingURLProtocol

/// A URLProtocol that records requests/responses and delegates to a
/// test-provided handler.
final class RecordingURLProtocol: URLProtocol, @unchecked Sendable {

  fileprivate static let state = State()

  // MARK: - Public accessors

  static var handler: (@Sendable (URLRequest) -> RecordingResponse)? {
    get { state.handlerValue }
    set { state.handlerValue = newValue }
  }

  static var recordedRequests: [URLRequest] {
    get { state.recordedRequestsValue }
    set { state.recordedRequestsValue = newValue }
  }

  static var recordedResponses: [URLResponse] {
    get { state.recordedResponsesValue }
    set { state.recordedResponsesValue = newValue }
  }

  static func reset() { state.reset() }

  // MARK: - URLProtocol overrides

  override class func canInit(with request: URLRequest) -> Bool {
    // Intercept everything aimed at the stub base URL (port 1). The
    // client appends real API paths (/v1/...) to the base URL, so the
    // match cannot be path-based.
    guard let url = request.url else { return false }
    return url.host == "127.0.0.1" && url.port == 1 && url.scheme == "http"
  }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    var r = request
    if r.value(forHTTPHeaderField: "Content-Type") == nil {
      r.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }
    return r
  }

  override func startLoading() {
    // URLSession converts httpBody into a stream before the request
    // reaches a URLProtocol; drain the stream so recorded requests
    // expose their body via httpBody for assertions.
    var recorded = request
    if recorded.httpBody == nil, let stream = recorded.httpBodyStream {
      recorded.httpBody = Self.drain(stream)
    }
    RecordingURLProtocol.state.appendRequest(recorded)

    guard let handler = RecordingURLProtocol.handler else {
      client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
      return
    }
    let response = handler(request)

    switch response {
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

  /// Reads an InputStream to the end. The stream is already positioned at
  /// the start when handed over by URLSession.
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

// MARK: - RecordingResponse

/// Response variants that a URLProtocol handler can produce.
enum RecordingResponse {
  case data(Data)
  case httpResponse(HTTPURLResponse, Data)
  case error(Error)
}

// MARK: - StubBuilder

/// Configures `RecordingURLProtocol` to return a fixed stub response.
struct StubBuilder {
  static func install(status: Int, body: Data?, headers: [String: String] = [:]) {
    RecordingURLProtocol.handler = { _ in
      var h = headers
      h["Content-Type"] = "application/json"
      let hr = HTTPURLResponse(
        url: URL(string: "http://127.0.0.1:1/stub")!,
        statusCode: status,
        httpVersion: nil,
        headerFields: h
      )!
      RecordingURLProtocol.state.appendResponse(hr)
      return RecordingResponse.httpResponse(hr, body ?? Data())
    }
  }

  static func install(status: Int, json: [String: Any], headers: [String: String] = [:]) {
    let body = try! JSONSerialization.data(withJSONObject: json, options: [])
    install(status: status, body: body, headers: headers)
  }
}
