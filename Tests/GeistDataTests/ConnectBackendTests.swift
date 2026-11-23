// ConnectBackendTests.swift — Tests/GeistDataTests
// The StripeClient conformance of ConnectBackend (M8, decision 0032):
// every call reaches the right endpoint with the right parameters, verified
// through a URLProtocol recorder injected as the client's URLSession
// (deterministic — no sockets, no listener races; a socket-based recorder
// lost whole request lines in swift test and made every call time out).
// Fake keys and IDs throughout.

import Foundation
import StripeModels
import StripeClient
import XCTest
@testable import GeistData

final class ConnectBackendTests: XCTestCase {
    // MARK: - Recording URLProtocol

    /// Records one request per test run and answers with a canned body.
    final class Recorder: URLProtocol {
        nonisolated(unsafe) static var paths: [String] = []
        nonisolated(unsafe) static var queries: [String] = []
        nonisolated(unsafe) static var headers: [[String: String]] = []
        nonisolated(unsafe) static var methods: [String] = []

        static func reset() {
            paths = []
            queries = []
            headers = []
            methods = []
        }

        override static func canInit(with request: URLRequest) -> Bool { true }
        override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

        override func startLoading() {
            let url = request.url!
            if let q = url.query {
                Self.paths.append(url.path)
                Self.queries.append(q)
            } else {
                Self.paths.append(url.path)
                Self.queries.append("")
            }
            var headerMap: [String: String] = [:]
            for (key, value) in request.allHTTPHeaderFields ?? [:] {
                headerMap[key.lowercased()] = value
            }
            Self.headers.append(headerMap)
            Self.methods.append(request.httpMethod ?? "GET")
            let response = HTTPURLResponse(
                url: url, statusCode: 200, httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data("{}".utf8))
            client?.urlProtocolDidFinishLoading(self)
        }

        override func stopLoading() {}
    }

    private func client() -> StripeClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [Recorder.self]
        let session = URLSession(configuration: config)
        return StripeClient(
            apiKey: "sk_test_recorder123", mode: .management,
            baseURL: URL(string: "https://api.example.com")!, session: session)
    }

    override func setUp() {
        super.setUp()
        Recorder.reset()
    }

    private func queryDict(_ query: String) -> [String: String] {
        var result: [String: String] = [:]
        for pair in query.split(separator: "&") {
            let kv = pair.split(separator: "=", maxSplits: 1)
            guard kv.count == 2 else { continue }
            result[String(kv[0]).removingPercentEncoding ?? String(kv[0])] =
                String(kv[1]).removingPercentEncoding ?? String(kv[1])
        }
        return result
    }

    // MARK: - Path and parameter mapping

    func testConnectedAccountsListsV1Accounts() async throws {
        let client = client()
        _ = try? await client.connectedAccounts(created: nil, limit: 10)
        XCTAssertEqual(Recorder.paths, ["/v1/accounts"])
        XCTAssertEqual(queryDict(Recorder.queries[0])["limit"], "10")
        XCTAssertEqual(Recorder.methods, ["GET"])
    }

    func testConnectedAccountsSendsCreatedWindowAsParams() async throws {
        let client = client()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = Date(timeIntervalSince1970: 1_700_100_000)
        _ = try? await client.connectedAccounts(created: DateInterval(start: start, end: end), limit: nil)
        let query = queryDict(Recorder.queries[0])
        XCTAssertEqual(query["created[gte]"], "1700000000")
        XCTAssertEqual(query["created[lt]"], "1700100000")
    }

    func testRetrieveConnectedAccountHitsAccountID() async throws {
        let client = client()
        _ = try? await client.retrieveConnectedAccount(id: "acct_test_123")
        XCTAssertEqual(Recorder.paths, ["/v1/accounts/acct_test_123"])
    }

    func testAccountCapabilitiesHitsCapabilityList() async throws {
        let client = client()
        _ = try? await client.accountCapabilities(account: "acct_test_123")
        XCTAssertEqual(Recorder.paths, ["/v1/accounts/acct_test_123/capabilities"])
    }

    func testAccountPersonsHitsPersonList() async throws {
        let client = client()
        _ = try? await client.accountPersons(account: "acct_test_123")
        XCTAssertEqual(Recorder.paths, ["/v1/accounts/acct_test_123/persons"])
    }

    func testAccountExternalAccountsHitsExternalAccountsList() async throws {
        let client = client()
        _ = try? await client.accountExternalAccounts(account: "acct_test_123")
        XCTAssertEqual(Recorder.paths, ["/v1/accounts/acct_test_123/external_accounts"])
        XCTAssertEqual(queryDict(Recorder.queries[0])["object"], "bank_account")
    }

    func testApplicationFeesListsApplicationFees() async throws {
        let client = client()
        _ = try? await client.applicationFees(charge: nil)
        XCTAssertEqual(Recorder.paths, ["/v1/application_fees"])
    }

    func testApplicationFeesSendsChargeFilter() async throws {
        let client = client()
        _ = try? await client.applicationFees(charge: "ch_test_123")
        XCTAssertEqual(Recorder.paths, ["/v1/application_fees"])
        XCTAssertEqual(queryDict(Recorder.queries[0])["charge"], "ch_test_123")
    }

    func testRetrieveApplicationFeeHitsFeeID() async throws {
        let client = client()
        _ = try? await client.retrieveApplicationFee(id: "fee_test_123")
        XCTAssertEqual(Recorder.paths, ["/v1/application_fees/fee_test_123"])
    }

    // MARK: - Stripe-Account header targeting

    func testStripeAccountHeaderIsSentWhenSet() async throws {
        // A client built with stripeAccount targets one connected account.
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [Recorder.self]
        let session = URLSession(configuration: config)
        let client = StripeClient(
            apiKey: "sk_test_recorder123", mode: .management,
            stripeAccount: "acct_test_123",
            baseURL: URL(string: "https://api.example.com")!, session: session)
        _ = try? await client.retrieveConnectedAccount(id: "acct_test_123")
        XCTAssertEqual(Recorder.paths, ["/v1/accounts/acct_test_123"])
        XCTAssertEqual(Recorder.headers[0]["stripe-account"], "acct_test_123")
    }

    func testPlainClientSendsNoStripeAccountHeader() async throws {
        let client = client()
        _ = try? await client.retrieveConnectedAccount(id: "acct_test_123")
        XCTAssertNil(Recorder.headers[0]["stripe-account"])
    }

    // MARK: - Auth header

    func testAuthorizationBearerIsSent() async throws {
        let client = client()
        _ = try? await client.retrieveConnectedAccount(id: "acct_test_123")
        XCTAssertTrue(Recorder.headers[0]["authorization"]?.hasPrefix("Bearer sk_test_") ?? false)
    }
}
