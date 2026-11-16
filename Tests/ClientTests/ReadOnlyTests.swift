// ReadOnlyTests.swift — Tests/ClientTests
// Dashboard mode must refuse every non-GET request. Proven by a test.
//
// Testing.md requires: "Dashboard mode must be unable to send a write,
// proven by a test." This suite proves it before any network touches
// the wire (baseURL is unreachable, so any network attempt would fail
// with a transport error, not dashboardModeReadOnly).

import XCTest
@testable import StripeClient

@MainActor
final class ReadOnlyTests: XCTestCase {

  func setupClient(mode: StripeClient.Mode) -> StripeClient {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [RecordingURLProtocol.self]
    RecordingURLProtocol.recordedRequests = []
    RecordingURLProtocol.recordedResponses = []
    return StripeClient(
      apiKey: "sk_test_fake", mode: mode, baseURL: URL(string: "http://127.0.0.1:1")!,
      configuration: config)
  }

  // MARK: - Dashboard mode refuses writes

  func testDashboardModeRefusesPost() async {
    let client = setupClient(mode: .dashboard)
    do {
      _ = try await client.perform(
        method: "POST", path: "/v1/customers", params: nil as EmptyParams?, namespace: .v1)
      XCTFail("POST should throw")
    } catch let error as StripeClientError {
      switch error {
      case .dashboardModeReadOnly:
        break
      default:
        XCTFail("Expected dashboardModeReadOnly, got \(error)")
      }
    } catch {
      XCTFail("Expected dashboardModeReadOnly, got \(error)")
    }
  }

  func testDashboardModeRefusesPut() async {
    let client = setupClient(mode: .dashboard)
    do {
      _ = try await client.perform(
        method: "PUT", path: "/v1/customers/cu_123", params: nil as EmptyParams?, namespace: .v1)
      XCTFail("PUT should throw")
    } catch let error as StripeClientError {
      switch error {
      case .dashboardModeReadOnly:
        break
      default:
        XCTFail("Expected dashboardModeReadOnly, got \(error)")
      }
    } catch {
      XCTFail("Expected dashboardModeReadOnly, got \(error)")
    }
  }

  func testDashboardModeRefusesDelete() async {
    let client = setupClient(mode: .dashboard)
    do {
      _ = try await client.perform(
        method: "DELETE", path: "/v1/customers/cu_123", params: nil as EmptyParams?, namespace: .v1)
      XCTFail("DELETE should throw")
    } catch let error as StripeClientError {
      switch error {
      case .dashboardModeReadOnly:
        break
      default:
        XCTFail("Expected dashboardModeReadOnly, got \(error)")
      }
    } catch {
      XCTFail("Expected dashboardModeReadOnly, got \(error)")
    }
  }

  func testDashboardModeAllowsGet() async {
    let client = setupClient(mode: .dashboard)
    StubBuilder.install(status: 200, json: ["data": [], "has_more": false])
    do {
      let result = try await client.perform(
        method: "GET", path: "/v1/customers", params: nil as EmptyParams?, namespace: .v1)
      // Must reach the network layer (stub), not throw dashboard error
      XCTAssertNotNil(result.body)
    } catch {
      XCTFail("GET should not throw in dashboard mode, got \(error)")
    }
  }

  func testDashboardModeRefusesPatch() async {
    let client = setupClient(mode: .dashboard)
    do {
      _ = try await client.perform(
        method: "PATCH", path: "/v1/customers/cu_123", params: nil as EmptyParams?, namespace: .v1)
      XCTFail("PATCH should throw")
    } catch let error as StripeClientError {
      switch error {
      case .dashboardModeReadOnly:
        break
      default:
        XCTFail("Expected dashboardModeReadOnly, got \(error)")
      }
    } catch {
      XCTFail("Expected dashboardModeReadOnly, got \(error)")
    }
  }

  // MARK: - Non-dashboard mode allows writes

  func testNonDashboardModeAllowsPost() async {
    let client = setupClient(mode: .management)
    StubBuilder.install(status: 200, json: ["id": "cus_test1"])
    do {
      let result = try await client.perform(
        method: "POST", path: "/v1/customers", params: nil as EmptyParams?, namespace: .v1)
      XCTAssertNotNil(result.body)
    } catch {
      XCTFail("POST should not throw in management mode, got \(error)")
    }
  }

  func testNonDashboardModeAllowsDelete() async {
    let client = setupClient(mode: .management)
    StubBuilder.install(status: 200, json: ["id": "cus_test1", "deleted": true])
    do {
      let result = try await client.perform(
        method: "DELETE", path: "/v1/customers/cus_test1", params: nil as EmptyParams?, namespace: .v1)
      XCTAssertNotNil(result.body)
    } catch {
      XCTFail("DELETE should not throw in management mode, got \(error)")
    }
  }
}
