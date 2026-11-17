import Foundation

/// Protocol for keychain-backed storage, enabling in-memory test doubles.
public protocol KeychainStoreProtocol: Sendable {
  func read(key: String) async -> String?
  func write(key: String, value: String) async
  func delete(key: String) async
  func listAccountKeys() async -> [String]
}

/// In-memory implementation of KeychainStoreProtocol for unit tests.
///
/// Each instance is independent, so parallel test runs never collide
/// or wipe each other's data.
public final actor InMemoryKeychainStore: KeychainStoreProtocol, Sendable {

  private var store: [String: String] = [:]

  public init() {}

  public func read(key: String) async -> String? {
    store[key]
  }

  public func write(key: String, value: String) async {
    store[key] = value
  }

  public func delete(key: String) async {
    store.removeValue(forKey: key)
  }

  public func listAccountKeys() async -> [String] {
    store.keys.filter { $0.hasPrefix("acct_") }.sorted()
  }
}
