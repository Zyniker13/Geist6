import Foundation
import Observation

/// Manages the set of known Stripe accounts and their keys.
///
/// Keys are stored in the Keychain; account metadata (name, color,
/// dashboard lock, connected accounts) is stored as JSON in the
/// Keychain under a single key per account.
@MainActor
@Observable
public final class AccountStore {

  private let keychain: KeychainStore

  public init(keychain: KeychainStore = KeychainStore()) {
    self.keychain = keychain
  }

  // MARK: - Add / remove / get

  /// Adds a new account. The API key is stored in the Keychain under
  /// `acct_<UUID>`. Returns the account.
  public func add(
    name: String,
    color: String,
    dashboardLock: Bool,
    apiKey: String,
    live: Bool,
    connectedAccounts: [ConnectedAccount] = []
  ) async -> Account {
    let account = Account(
      id: UUID(),
      name: name,
      color: color,
      dashboardLock: dashboardLock,
      apiKey: apiKey,
      live: live,
      connectedAccounts: connectedAccounts
    )
    let key = "acct_\(account.id.uuidString)"
    await keychain.write(key: key, value: apiKey)

    let metadata = AccountMetadata(
      name: name,
      color: color,
      dashboardLock: dashboardLock,
      live: live,
      connectedAccounts: connectedAccounts
    )
    let data = try? JSONEncoder().encode(metadata)
    if let data {
      await keychain.write(key: "meta_\(account.id.uuidString)", value: String(data: data, encoding: .utf8) ?? "")
    }

    return account
  }

  /// Returns the account with the given ID, or nil.
  public func get(id: UUID) async -> Account? {
    let key = "acct_\(id.uuidString)"
    let apiKey = await keychain.read(key: key)
    guard let apiKey else { return nil }

    let metaKey = "meta_\(id.uuidString)"
    let metaStr = await keychain.read(key: metaKey)
    guard let metaData = metaStr?.data(using: .utf8),
          let metadata = try? JSONDecoder().decode(AccountMetadata.self, from: metaData)
    else {
      return Account(id: id, name: "Unknown", color: ".systemGray", dashboardLock: false, apiKey: "[REDACTED]", live: false)
    }

    return Account(
      id: id,
      name: metadata.name,
      color: metadata.color,
      dashboardLock: metadata.dashboardLock,
      apiKey: apiKey,
      live: metadata.live,
      connectedAccounts: metadata.connectedAccounts
    )
  }

  /// Returns all known accounts.
  public func list() async -> [Account] {
    let keys = await keychain.listAccountKeys()
    var accounts: [Account] = []

    for key in keys {
      let uuidStr = key.replacingOccurrences(of: "acct_", with: "")
      guard let id = UUID(uuidString: uuidStr) else { continue }
      if let account = await get(id: id) {
        accounts.append(account)
      }
    }

    return accounts.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
  }

  /// Removes an account and its key from the Keychain.
  public func remove(id: UUID) async {
    await keychain.delete(key: "acct_\(id.uuidString)")
    await keychain.delete(key: "meta_\(id.uuidString)")
  }

  /// Updates an account's metadata (name, color, dashboard lock).
  /// The API key is not changed.
  public func update(
    id: UUID,
    name: String,
    color: String,
    dashboardLock: Bool
  ) async {
    let key = "acct_\(id.uuidString)"
    let apiKey = await keychain.read(key: key)
    guard let _ = apiKey else { return }

    let metaKey = "meta_\(id.uuidString)"
    let metaStr = await keychain.read(key: metaKey)

    var metadata: AccountMetadata
    if let metaData = metaStr?.data(using: .utf8),
       let decoded = try? JSONDecoder().decode(AccountMetadata.self, from: metaData)
    {
      metadata = decoded
    } else {
      metadata = AccountMetadata(name: "", color: "", dashboardLock: false, live: false, connectedAccounts: [])
    }

    metadata.name = name
    metadata.color = color
    metadata.dashboardLock = dashboardLock

    let data = try? JSONEncoder().encode(metadata)
    if let data {
      await keychain.write(key: metaKey, value: String(data: data, encoding: .utf8) ?? "")
    }
  }

  /// Updates the connected accounts for an existing account.
  public func updateConnectedAccounts(id: UUID, connected: [ConnectedAccount]) async {
    let key = "acct_\(id.uuidString)"
    let apiKey = await keychain.read(key: key)
    guard let _ = apiKey else { return }

    let metaKey = "meta_\(id.uuidString)"
    let metaStr = await keychain.read(key: metaKey)

    var metadata: AccountMetadata
    if let metaData = metaStr?.data(using: .utf8),
       let decoded = try? JSONDecoder().decode(AccountMetadata.self, from: metaData)
    {
      metadata = decoded
    } else {
      metadata = AccountMetadata(name: "", color: "", dashboardLock: false, live: false, connectedAccounts: [])
    }

    metadata.connectedAccounts = connected

    let data = try? JSONEncoder().encode(metadata)
    if let data {
      await keychain.write(key: metaKey, value: String(data: data, encoding: .utf8) ?? "")
    }
  }

  /// Returns the currently active account ID, or nil.
  public func activeID() async -> UUID? {
    let key = "active_account_id"
    let str = await keychain.read(key: key)
    return str.flatMap { UUID(uuidString: $0) }
  }

  /// Sets the active account.
  public func setActive(id: UUID) async {
    await keychain.write(key: "active_account_id", value: id.uuidString)
  }

  /// Returns the active account, or nil.
  public func active() async -> Account? {
    guard let id = await activeID() else { return nil }
    return await get(id: id)
  }
}

// MARK: - Internal metadata struct (stored as JSON in Keychain)

private struct AccountMetadata: Codable, Sendable {
  var name: String
  var color: String
  var dashboardLock: Bool
  var live: Bool
  var connectedAccounts: [ConnectedAccount]
}
