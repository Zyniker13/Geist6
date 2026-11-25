import GeistData
import Observation
import StripeModels

// The app's local `Account` (Keychain-stored Stripe account) shadows
// Stripe's generated `Account` (a connected account) in this module, so
// the Stripe type is aliased explicitly.
typealias StripeAccount = StripeModels.Account

/// Backing model for the Connect screen (M8): the platform's connected
/// accounts and the platform-earned application fees. Read-only by
/// construction: it holds a `ConnectBackend`, which has no write methods.
///
/// Platform-key detection (decision 0032): a key string alone cannot
/// distinguish a platform key from a plain account key. The first load of
/// the accounts section decides — a 200 list means the key is a platform
/// key; any error means the Connect screens show that error (a 403 with
/// Stripe's "not a platform" message included verbatim) instead of a
/// generic failure.
@MainActor
@Observable
final class ConnectModel {
  enum Phase: Equatable {
    case idle
    case loading
    case loaded
  }

  let backend: any ConnectBackend

  private(set) var phase: Phase = .idle
  private(set) var accounts: [StripeAccount] = []
  private(set) var fees: [ApplicationFee] = []
  private(set) var accountsError: String?
  private(set) var feesError: String?
  private(set) var searchQuery = ""
  /// True when the platform key also serves the v2 accounts namespace:
  /// the v2 list succeeded, so `v2Accounts` carries the rows and the
  /// Connected accounts section renders v2 rows (slice 3, decision 0032).
  private(set) var usesV2Accounts = false
  private(set) var v2Accounts: [V2CoreAccount] = []

  /// The search field's setter for the view's binding. Re-filters the
  /// already-loaded page client-side (the list request is not re-sent).
  func setSearch(_ query: String) {
    searchQuery = query
    if usesV2Accounts {
      v2Accounts = filteredV2(allV2Accounts)
      accounts = []
    } else {
      accounts = filtered(allAccounts)
      v2Accounts = []
    }
  }
  /// The unfiltered page from the last successful load, kept so the
  /// search can narrow and widen it without another request.
  private var allAccounts: [StripeAccount] = []
  /// The v1/v2 twin of `allAccounts` for the v2 namespace.
  private var allV2Accounts: [V2CoreAccount] = []

  init(backend: any ConnectBackend) {
    self.backend = backend
  }

  /// Loads the connected accounts and the application fees. Sections load
  /// concurrently and settle independently (the Billing pattern, decision
  /// 0027): a failure in one leaves the other loaded.
  func load() async {
    phase = .loading
    async let accountsSettled: Void = loadAccounts()
    async let feesSettled: Void = loadFees()
    _ = await (accountsSettled, feesSettled)
    phase = .loaded
  }

  /// Reloads only the connected accounts (after a write, or on demand).
  /// The v2 namespace is probed first: a v2-era platform key answers it
  /// and the rows render as v2 accounts; a v1-era platform key or a
  /// non-platform key does not, so the v1 list decides between "plain
  /// platform key" and "not a platform key" (decision 0032). The probe's
  /// failure is never surfaced as an error of its own.
  func loadAccounts() async {
    if let v2 = try? await backend.v2Accounts(limit: 100), !v2.isEmpty {
      usesV2Accounts = true
      allV2Accounts = v2
      v2Accounts = filteredV2(v2)
      accounts = []
      allAccounts = []
      accountsError = nil
      return
    }
    usesV2Accounts = false
    v2Accounts = []
    allV2Accounts = []
    do {
      let all = try await backend.connectedAccounts(created: nil, limit: 100)
      allAccounts = all
      accounts = filtered(all)
      accountsError = nil
    } catch {
      accountsError = String(describing: error)
    }
  }

  private func loadFees() async {
    do {
      fees = try await backend.applicationFees(charge: nil)
      feesError = nil
    } catch {
      feesError = String(describing: error)
    }
  }

  private func filtered(_ all: [StripeAccount]) -> [StripeAccount] {
    guard !searchQuery.isEmpty else { return all }
    return all.filter { account in
      matches(account.id) || matches(account.email?.valueOrNil)
        || matches(businessName(account))
    }
  }

  /// The v2 twin of `filtered`: ID, display name, and contact email.
  private func filteredV2(_ all: [V2CoreAccount]) -> [V2CoreAccount] {
    guard !searchQuery.isEmpty else { return all }
    return all.filter { account in
      matches(account.id) || matches(account.displayName)
        || matches(account.contactEmail)
    }
  }

  /// The display title of a v2 account row: display name, then ID.
  func v2Title(_ account: V2CoreAccount) -> String {
    account.displayName ?? account.id
  }

  /// The business profile's name, through the Nullable wrapper.
  func businessName(_ account: StripeAccount) -> String? {
    account.businessProfile?.valueOrNil?.name.valueOrNil
  }

  private func matches(_ field: String?) -> Bool {
    guard let field else { return false }
    return field.localizedCaseInsensitiveContains(searchQuery)
  }

  /// True when the accounts section errored with Stripe's permission
  /// failure: the key is not a platform key, so connected accounts are not
  /// reachable with it. Rendered as guidance, not a generic error.
  var keyIsNotPlatform: Bool {
    guard let accountsError else { return false }
    return accountsError.contains("403") || accountsError.contains("connect_key_invalid")
  }
}
