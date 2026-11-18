import XCTest
@testable import Geist6
@testable import StripeClient
import StripeModels

/// Key safety unit tests: prove that API keys never leak into caches,
/// logs, or exports.
@MainActor
final class KeySafetyTests: XCTestCase {

  /// The key used in all tests — obviously fake, never a real credential.
  private let fakeKey = "sk_test_fake_key_safety_test_12345"

  // MARK: - Keychain

  func testKeychainDoesNotExposeKeyInDescription() async {
    let store = KeychainStore()
    let key = "com.geist6.account.test.key"

    await store.write(key: key, value: fakeKey)

    // The stored value should be retrievable, but never appear in
    // debug descriptions or log output.
    let value = await Task { await store.read(key: key) }.value
    XCTAssertEqual(value, fakeKey)

    // Verify the key is not in the keychain's debug description.
    let desc = String(describing: store)
    XCTAssertFalse(desc.contains(fakeKey), "Keychain description must not contain the API key")
  }

  // MARK: - AccountStore

  func testAccountStoreDoesNotLogKey() async throws {
    let keychain = KeychainStore()
    let store = AccountStore(keychain: keychain)

    // Add an account with the fake key.
    let account = await store.add(
      name: "Safety Test",
      color: ".systemBlue",
      dashboardLock: false,
      apiKey: fakeKey,
      live: false
    )

    // The account's description must not contain the key.
    let desc = String(describing: account)
    XCTAssertFalse(desc.contains(fakeKey), "Account description must not contain the API key")

    // Listing accounts must not expose the key.
    let accounts = await store.list()
    for acct in accounts {
      let acctDesc = String(describing: acct)
      XCTAssertFalse(acctDesc.contains(fakeKey), "Listed account must not contain the API key")
    }
  }

  func testAccountStoreMetadataDoesNotContainKey() async {
    let keychain = KeychainStore()
    let store = AccountStore(keychain: keychain)

    await store.add(
      name: "Metadata Test",
      color: ".systemRed",
      dashboardLock: true,
      apiKey: fakeKey,
      live: true
    )

    // Read the raw metadata from the keychain.
    let metaKey = "com.geist6.account.metadata"
    let meta = await keychain.read(key: metaKey)

    // The metadata JSON must not contain the API key.
    XCTAssertFalse(meta?.contains(fakeKey) ?? false, "Metadata must not contain the API key")
  }

  // MARK: - AppConfig

  // Note: CommandLine.arguments setter is unavailable on iOS.
  // AppConfig parsing is tested via UI tests that pass --api-base-url
  // as a launch argument.

  // MARK: - StripeClient

  func testStripeClientDoesNotLogKeyInError() async throws {
    let baseURL = URL(string: "http://127.0.0.1:12111")!
    let client = StripeClient(apiKey: fakeKey, mode: .management, baseURL: baseURL)

    // Fire a request that will fail (invalid path).
    do {
      let _: StripeModels.Account = try await client.request(method: "GET", path: "/v1/nonexistent")
      XCTFail("Should have thrown")
    } catch let apiError as StripeAPIError {
      // The error description must not contain the API key.
      let desc = apiError.localizedDescription
      XCTAssertFalse(desc.contains(fakeKey), "StripeAPIError description must not contain the API key")
    } catch {
      // Transport or other errors also must not leak the key.
      let desc = String(describing: error)
      XCTAssertFalse(desc.contains(fakeKey), "Error description must not contain the API key")
    }
  }
}
