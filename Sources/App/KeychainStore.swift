import Foundation
import Security

/// Secure wrapper around the iOS Keychain for API keys and account metadata.
///
/// Keys are never stored in plaintext in memory longer than necessary.
/// The Keychain API is thread-safe for individual calls; the store
/// serialises all access through a dedicated queue.
public final actor KeychainStore: Sendable {

  public init() {}

  // MARK: - Keychain access

  /// Reads a string value from the Keychain.
  public func read(key: String) async -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: key,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)

    guard status == errSecSuccess,
          let data = item as? Data
    else {
      return nil
    }

    return String(data: data, encoding: .utf8)
  }

  /// Writes a string value to the Keychain.
  public func write(key: String, value: String) async {
    let data = value.data(using: .utf8)!

    // Try to update first; if it fails, create.
    let updateQuery: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: key,
    ]
    let setQuery: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: key,
      kSecValueData as String: data,
    ]

    let updateStatus = SecItemUpdate(updateQuery as CFDictionary, [kSecValueData: data] as CFDictionary)
    if updateStatus == errSecSuccess { return }

    SecItemAdd(setQuery as CFDictionary, nil)
  }

  /// Deletes a value from the Keychain.
  public func delete(key: String) async {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: key,
    ]
    SecItemDelete(query as CFDictionary)
  }

  /// Lists all account identifiers stored in the Keychain.
  public func listAccountKeys() async -> [String] {
    // NOTE: Keychain queries do not support glob wildcards; kSecAttrAccount
    // "acct_*" would match only the literal string. List every generic
    // password item and filter by prefix in code instead.
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecReturnAttributes as String: true,
      kSecMatchLimit as String: kSecMatchLimitAll,
    ]

    var items: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &items)

    guard status == errSecSuccess,
          let dataArray = items as? [[String: Any]]
    else {
      return []
    }

    return dataArray.compactMap { $0[kSecAttrAccount as String] as? String }
      .filter { $0.hasPrefix("acct_") }
  }
}
