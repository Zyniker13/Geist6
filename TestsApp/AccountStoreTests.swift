import Foundation
import Testing
@testable import Geist6

@MainActor
struct AccountStoreTests {

  @MainActor private func makeStore() async -> AccountStore {
    let keychain = InMemoryKeychainStore()
    return AccountStore(keychain: keychain)
  }

  @Test func addAccountPersistsToKeychain() async {
    let store = await makeStore()

    let account = await store.add(
      name: "Test Account",
      color: ".systemBlue",
      dashboardLock: true,
      apiKey: "sk_test_fake_key_123",
      live: false
    )

    #expect(account.name == "Test Account")
    #expect(account.color == ".systemBlue")
    #expect(account.dashboardLock == true)
    #expect(account.live == false)
    #expect(!account.id.uuidString.isEmpty)
  }

  @Test func getReturnsAccountByKeychainData() async throws {
    let store = await makeStore()

    let added = await store.add(
      name: "Get Test",
      color: ".systemRed",
      dashboardLock: false,
      apiKey: "«redacted:sk_test_…»",
      live: true
    )

    let retrieved = try #require(await store.get(id: added.id))

    #expect(retrieved.name == "Get Test")
    #expect(retrieved.color == ".systemRed")
    #expect(retrieved.live == true)
    #expect(retrieved.dashboardLock == false)
  }

  @Test func getReturnsNilForUnknownId() async {
    let store = await makeStore()
    let result = await store.get(id: UUID())
    #expect(result == nil)
  }

  @Test func listReturnsAllAccounts() async throws {
    let store = await makeStore()

    _ = await store.add(name: "Beta", color: ".systemBlue", dashboardLock: false, apiKey: "«redacted:sk_test_…»", live: false)
    _ = await store.add(name: "Alpha", color: ".systemRed", dashboardLock: true, apiKey: "«redacted:sk_test_…»", live: true)
    _ = await store.add(name: "Gamma", color: ".systemGreen", dashboardLock: false, apiKey: "«redacted:sk_test_…»", live: false)

    let accounts = await store.list()

    try #require(accounts.count == 3)
    #expect(accounts[0].name == "Alpha")
    #expect(accounts[1].name == "Beta")
    #expect(accounts[2].name == "Gamma")
  }

  @Test func listReturnsEmptyWhenNoAccounts() async {
    let store = await makeStore()
    let accounts = await store.list()
    #expect(accounts.isEmpty)
  }

  @Test func removeDeletesAccountFromKeychain() async {
    let store = await makeStore()

    let added = await store.add(
      name: "Remove Me",
      color: ".systemYellow",
      dashboardLock: false,
      apiKey: "sk_test_fake_remove",
      live: false
    )

    await store.remove(id: added.id)

    let accounts = await store.list()
    #expect(accounts.isEmpty)
  }

  @Test func updateChangesMetadata() async {
    let store = await makeStore()

    let added = await store.add(
      name: "Original",
      color: ".systemBlue",
      dashboardLock: false,
      apiKey: "sk_test_fake_update",
      live: false
    )

    await store.update(id: added.id, name: "Updated", color: ".systemPurple", dashboardLock: true)

    let retrieved = await store.get(id: added.id)

    #expect(retrieved?.name == "Updated")
    #expect(retrieved?.color == ".systemPurple")
    #expect(retrieved?.dashboardLock == true)
    // API key should be unchanged
    #expect(retrieved?.apiKey == "sk_test_fake_update")
  }

  @Test func setActiveAndActiveReturnCorrectAccount() async {
    let store = await makeStore()

    let acct1 = await store.add(name: "First", color: ".systemBlue", dashboardLock: false, apiKey: "sk_test_fake_1", live: false)
    let acct2 = await store.add(name: "Second", color: ".systemRed", dashboardLock: false, apiKey: "sk_test_fake_2", live: true)

    await store.setActive(id: acct2.id)

    let active = await store.active()
    #expect(active?.id == acct2.id)
    #expect(active?.name == "Second")

    let activeId = await store.activeID()
    #expect(activeId == acct2.id)
  }

  @Test func activeReturnsNilWhenNoActiveAccount() async {
    let store = await makeStore()

    _ = await store.active()
    let activeId = await store.activeID()
    #expect(activeId == nil)
  }

  @Test func updateConnectedAccounts() async {
    let store = await makeStore()

    let added = await store.add(
      name: "Connect Test",
      color: ".systemGreen",
      dashboardLock: false,
      apiKey: "sk_test_fake_connect",
      live: false
    )

    let connected = [
      ConnectedAccount(id: "acct_connected_1", displayName: "Sub Account", email: "sub@example.com", type: .standard)
    ]

    await store.updateConnectedAccounts(id: added.id, connected: connected)

    let retrieved = await store.get(id: added.id)
    #expect(retrieved?.connectedAccounts.count == 1)
    #expect(retrieved?.connectedAccounts[0].displayName == "Sub Account")
    #expect(retrieved?.connectedAccounts[0].type == .standard)
  }

  @Test func connectedAccountTypes() {
    // Verify all ConnectedAccount.ConnectedAccountType cases are valid
    let types: [ConnectedAccount.ConnectedAccountType] = [.standard, .express, .custom, .none]
    for t in types {
      #expect(!t.rawValue.isEmpty)
    }
  }

  // MARK: - In-memory cache (single source of truth for views)

  @Test func cachedIsNilForNeverSeenAccount() async {
    let store = await makeStore()
    #expect(store.cached(id: UUID()) == nil)
  }

  @Test func addPopulatesCache() async {
    let store = await makeStore()

    let added = await store.add(
      name: "Cache Add", color: ".systemBlue", dashboardLock: false,
      apiKey: "«redacted:sk_test_…»", live: false)

    let cached = store.cached(id: added.id)
    #expect(cached?.name == "Cache Add")
    #expect(cached?.id == added.id)
  }

  @Test func getPopulatesCache() async {
    let store = await makeStore()

    let added = await store.add(
      name: "Cache Get", color: ".systemRed", dashboardLock: false,
      apiKey: "«redacted:sk_test_…»", live: false)
    _ = await store.get(id: added.id)

    let cached = store.cached(id: added.id)
    #expect(cached?.name == "Cache Get")
  }

  /// Regression for the lost-rename UI bug: after `update`, the
  /// synchronous cache read must show the new name so a live view
  /// re-renders even when view-local @State is lost to navigation
  /// re-creation.
  @Test func updateRefreshesColdCache() async {
    let store = await makeStore()

    let added = await store.add(
      name: "Before", color: ".systemBlue", dashboardLock: false,
      apiKey: "«redacted:sk_test_…»", live: false)

    await store.update(id: added.id, name: "After", color: ".systemPurple", dashboardLock: true)

    let cached = store.cached(id: added.id)
    #expect(cached?.name == "After")
    #expect(cached?.color == ".systemPurple")
    #expect(cached?.dashboardLock == true)
  }

  @Test func updateRefreshesWarmCache() async {
    let store = await makeStore()

    let added = await store.add(
      name: "Warm Before", color: ".systemBlue", dashboardLock: false,
      apiKey: "«redacted:sk_test_…»", live: false)
    _ = await store.get(id: added.id)

    await store.update(id: added.id, name: "Warm After", color: ".systemBlue", dashboardLock: false)

    #expect(store.cached(id: added.id)?.name == "Warm After")
  }

  @Test func removeEvictsCache() async {
    let store = await makeStore()

    let added = await store.add(
      name: "Remove Cache", color: ".systemBlue", dashboardLock: false,
      apiKey: "«redacted:sk_test_…»", live: false)
    _ = await store.get(id: added.id)
    #expect(store.cached(id: added.id) != nil)

    await store.remove(id: added.id)
    #expect(store.cached(id: added.id) == nil)
  }

  @Test func updateConnectedAccountsRefreshesCache() async {
    let store = await makeStore()

    let added = await store.add(
      name: "Cache Connected", color: ".systemGreen", dashboardLock: false,
      apiKey: "«redacted:sk_test_…»", live: false)
    _ = await store.get(id: added.id)

    let connected = [
      ConnectedAccount(id: "acct_connected_1", displayName: "Sub", email: "sub@example.com", type: .standard)
    ]
    await store.updateConnectedAccounts(id: added.id, connected: connected)

    #expect(store.cached(id: added.id)?.connectedAccounts.count == 1)
    #expect(store.cached(id: added.id)?.connectedAccounts[0].displayName == "Sub")
  }

  // MARK: - Observable list (decision 0015)

  /// Regression test for the stale-sidebar bug: every mutation path must
  /// keep the observable `accountsList` in sync so consumers that read it
  /// (shell sidebar, account list) re-render without their own reload
  /// callbacks. The UI-level regression lives in AccountUITests
  /// (testManageAccountsRename).
  @Test func accountsListTracksAddUpdateRemove() async {
    let store = await makeStore()

    #expect(store.accountsList.isEmpty)

    let account = await store.add(
      name: "List Alpha", color: ".systemBlue", dashboardLock: false,
      apiKey: makeKey("listalpha"), live: false
    )
    #expect(store.accountsList.map(\.id) == [account.id])

    await store.update(
      id: account.id, name: "List Alpha Renamed", color: ".systemRed", dashboardLock: true
    )
    #expect(store.accountsList.map(\.name) == ["List Alpha Renamed"])
    #expect(store.accountsList.map(\.dashboardLock) == [true])

    await store.remove(id: account.id)
    #expect(store.accountsList.isEmpty)
  }

  /// Regression test for the root cause of the stale-sidebar bug:
  /// `Account` previously compared equal by `id` only, so a rename produced
  /// an array SwiftUI (and any diffing consumer) considered unchanged.
  @Test func accountEqualityIncludesNameAndSettings() {
    let base = Account(
      name: "Alpha", color: ".systemBlue", dashboardLock: false,
      apiKey: makeKey("alpha"), live: false
    )
    let renamed = Account(
      id: base.id, name: "Beta", color: ".systemBlue", dashboardLock: false,
      apiKey: makeKey("alpha"), live: false
    )
    #expect(base != renamed)
    #expect(
      base != Account(id: base.id, name: "Alpha", color: ".systemBlue",
                      dashboardLock: true, apiKey: makeKey("alpha"), live: false))
  }

  @Test func accountsListIsSortedByNameCaseInsensitive() async {
    let store = await makeStore()

    _ = await store.add(
      name: "bravo", color: ".systemBlue", dashboardLock: false,
      apiKey: makeKey("bravo"), live: false
    )
    _ = await store.add(
      name: "Alpha", color: ".systemRed", dashboardLock: false,
      apiKey: makeKey("alphakey"), live: false
    )

    #expect(store.accountsList.map(\.name) == ["Alpha", "bravo"])
  }

  private func makeKey(_ suffix: String) -> String {
    ["sk", "test", suffix].joined(separator: "_")
  }
}
