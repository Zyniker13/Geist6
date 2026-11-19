// MockServerTests.swift — Tests/ClientTests
// Contract tests against stripe-mock.
//
// Tests: list, retrieve, create, update, delete, search.
// Pagination and expand are tested via URLProtocol stubs (stripe-mock
// returns has_more=False always and does not expand objects).

import XCTest
import Foundation
@testable import StripeClient
import StripeModels
import GeistData

@MainActor
final class MockServerTests: XCTestCase {

  // MARK: - Harness

  private static let harness = MockHarness()

  // swiftlint:disable:next static_over_final_class
  override class func tearDown() {
    super.tearDown()
    MockHarness.tearDown()
  }

  // MARK: - List

  func testListChargesFull() async throws {
    let client = MockHarness.client
    // Test with params to reproduce the crash
    let result = try await client.perform(
      method: "GET", path: "/v1/charges", params: ["limit": "2"], namespace: .v1)
    XCTAssertEqual(result.status, 200)
    XCTAssertTrue(result.body.count > 0)
  }

  // MARK: - Retrieve

  func testRetrieveChargeFull() async throws {
    let client = MockHarness.client
    let result = try await client.perform(
      method: "GET", path: "/v1/charges/ch_1234567890", params: nil as EmptyParams?, namespace: .v1)
    XCTAssertEqual(result.status, 200)
    XCTAssertTrue(result.body.count > 0)
    let charge = try StripeClient.decoder.decode(
      Charge.self, from: result.body)
    XCTAssertEqual(charge.id, "ch_1234567890")
  }

  func testRetrieveCustomer() async throws {
    let client = MockHarness.client
    let result = try await client.perform(
      method: "GET", path: "/v1/customers/cus_123", params: nil as EmptyParams?, namespace: .v1)
    let customer = try StripeClient.decoder.decode(
      Customer.self, from: result.body)
    XCTAssertEqual(customer.id, "cus_123")
  }

  // MARK: - Create

  func testCreateCustomer() async throws {
    let client = MockHarness.client
    let params = CustomerCreateParams(
      email: "alice@example.com",
      name: "Alice Smith")
    let result = try await client.perform(
      method: "POST", path: "/v1/customers", params: params, namespace: .v1)
    let customer = try StripeClient.decoder.decode(
      Customer.self, from: result.body)
    XCTAssertEqual(customer.email, .value("alice@example.com"))
    XCTAssertEqual(customer.name, .value("Alice Smith"))
  }

  // MARK: - Update

  func testUpdateCustomer() async throws {
    let client = MockHarness.client
    let params = CustomerUpdateParams(name: "Alice Updated")
    let result = try await client.perform(
      method: "POST", path: "/v1/customers/cus_123", params: params, namespace: .v1)
    let customer = try StripeClient.decoder.decode(
      Customer.self, from: result.body)
    XCTAssertEqual(customer.name, .value("Alice Updated"))
  }

  // MARK: - Delete

  func testDeleteCustomer() async throws {
    let client = MockHarness.client
    let result = try await client.perform(
      method: "DELETE", path: "/v1/customers/cus_123", params: nil as EmptyParams?, namespace: .v1)
    let deleted = try StripeClient.decoder.decode(
      DeletionResponse.self, from: result.body)
    XCTAssertTrue(deleted.deleted)
  }

  // MARK: - Regression: conformance wrappers must terminate

  /// Regression (2026-11-18): the `StripeDataBackend` conformance wrapper
  /// `StripeClient.retrieveBalanceTransaction(id:)` called itself, because
  /// the generated service method shares its first parameter label (`id:`).
  /// Every hop re-entered the wrapper on the caller's actor, so a call made
  /// from the charge detail screen's MainActor `load()` spun the main
  /// actor forever: the app never went idle and XCUITest timed out. The
  /// wrapper must delegate to the generated
  /// `retrieveBalanceTransaction(id:_:expand:)` instead.
  ///
  /// The call runs in a detached task raced against a timer: a regression
  /// surfaces as this failure after 15 s instead of hanging the suite.
  ///
  /// Dispatch detail: the recursion only manifests when the call is made
  /// through the `StripeDataBackend` protocol existential (as every app
  /// view does) — there the witness is the wrapper, whose unqualified
  /// `retrieveBalanceTransaction(id: id)` re-enters itself inside the
  /// GeistData module. A direct `StripeClient` call from outside the
  /// module resolves to the generated method instead and would make this
  /// test a false green.
  func testRetrieveBalanceTransactionWrapperTerminates() throws {
    let client = MockHarness.client
    let backend: any PaymentsBackend = client
    let done = expectation(description: "retrieveBalanceTransaction returned")
    Task.detached(priority: .utility) {
      do {
        _ = try await backend.retrieveBalanceTransaction(id: "txn_1234567890")
        done.fulfill()
      } catch {
        XCTFail("unexpected error: \(error)")
      }
    }
    let outcome = XCTWaiter.wait(for: [done], timeout: 15)
    XCTAssertEqual(
      outcome, .completed,
      "retrieveBalanceTransaction(id:) did not return within 15 s; it must call the generated method, not itself")
  }

  // Search and 404-error handling are covered in RequestShapeTests via
  // URLProtocol stubs: stripe-mock serves fixture objects for any
  // resource id (so an unknown id does not 404) and does not implement
  // the /v1 search endpoints.
}

// MARK: - MockHarness

/// Boots stripe-mock on a free port, waits for readiness, and provides
/// a configured StripeClient. Tears down the process on suite end.
@MainActor
private final class MockHarness: @unchecked Sendable {

  private static let semaphore = DispatchSemaphore(value: 1)
  @MainActor private static var process: Process?
  @MainActor private static var port: Int = 0
  @MainActor private static var _client: StripeClient!

  static var client: StripeClient {
    semaphore.wait()
    defer { semaphore.signal() }
    guard let client = _client else {
      boot()
      return _client!
    }
    return client
  }

  static func tearDown() {
    semaphore.wait()
    defer { semaphore.signal() }
    process?.terminate()
    process = nil
  }

  private static func boot() {
    port = findFreePort()
    let proc = Process()
    // Locate stripe-mock: env override first, then common Homebrew paths.
    let candidates = [
      ProcessInfo.processInfo.environment["STRIPE_MOCK_PATH"],
      "/opt/homebrew/bin/stripe-mock",
      "/usr/local/bin/stripe-mock"
    ]
    let path = candidates
      .compactMap { $0 }
      .first { FileManager.default.isExecutableFile(atPath: $0) }
    guard let path else {
      fatalError("stripe-mock not found; install it (brew install stripe-mock) or set STRIPE_MOCK_PATH")
    }
    proc.executableURL = URL(fileURLWithPath: path)
    proc.arguments = ["-http-port", String(port)]
    do {
      try proc.run()
    } catch {
      fatalError("stripe-mock failed to launch at \(path): \(error)")
    }
    guard waitForReady(port: port, timeout: 10) else {
      fatalError("stripe-mock did not become ready on port \(port)")
    }
    process = proc
    _client = StripeClient(apiKey: "sk_test_fake", mode: .management, baseURL: URL(string: "http://127.0.0.1:\(port)")!)
  }

  private static func findFreePort() -> Int {
    let socket = socket(AF_INET, SOCK_STREAM, 0)
    guard socket >= 0 else { return 12111 }
    var addr = sockaddr_in()
    addr.sin_family = sa_family_t(AF_INET)
    addr.sin_port = 0 // let OS pick
    addr.sin_addr.s_addr = inet_addr("127.0.0.1")
    let bindResult = withUnsafePointer(to: &addr) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        bind(socket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
      }
    }
    guard bindResult == 0 else { close(socket); return 12111 }
    var sockAddr = sockaddr()
    var sockAddrLen = socklen_t(MemoryLayout<sockaddr>.size)
    _ = withUnsafeMutablePointer(to: &sockAddr) {
      getsockname(socket, $0, &sockAddrLen)
    }
    close(socket)
    // Convert sockaddr to sockaddr_in to read sin_port
    let sinPort = withUnsafePointer(to: &sockAddr) {
      $0.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
        $0.pointee.sin_port
      }
    }
    return Int(UInt16(bigEndian: sinPort))
  }

  private static func waitForReady(port: Int, timeout: Double) -> Bool {
    let bgQueue = DispatchQueue(label: "MockHarness.readyCheck", qos: .utility)
    let sem = DispatchSemaphore(value: 0)
    let url = URL(string: "http://127.0.0.1:\(port)/v1/charges")!
    let start = Date.timeIntervalSinceReferenceDate
    final class Box: @unchecked Sendable { var value = false }
    let box = Box()

    bgQueue.async {
      var ready = false
      while !ready && Date.timeIntervalSinceReferenceDate - start < timeout {
        let innerSem = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: url) { _, response, _ in
          // 401 means stripe-mock is up and requires auth — that counts as ready.
          if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 100 {
            ready = true
          }
          innerSem.signal()
        }.resume()
        _ = innerSem.wait(timeout: .now() + 1.0)
        if !ready { Thread.sleep(forTimeInterval: 0.2) }
      }
      box.value = ready
      sem.signal()
    }

    _ = sem.wait(timeout: .now() + timeout + 2.0)
    return box.value
  }
}
