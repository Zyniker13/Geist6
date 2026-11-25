import Foundation
import GeistData
import StripeModels
import Testing
@testable import Geist6

// The app's local `Account` shadows Stripe's generated `Account`, so the
// Stripe type is referenced with its module prefix in the fixtures.

private enum ConnectStubError: Error { case boom }
private enum Forbidden: Error { case threeHundredThree }
private struct Stripe403: Error, CustomStringConvertible {
  var description: String {
    "HTTP 403 invalid_request_error Connect requires a platform key (connect_key_invalid)"
  }
}

/// A connect backend that returns fixed rows or fails on demand, so tests
/// can prove the per-section isolation and the platform-key detection
/// behave the way the Connect screens render them.
private struct RecordingConnectBackend: ConnectBackend {
  var accountsError: Error?
  var feesError: Error?
  var accounts: [StripeModels.Account] = []
  var fees: [ApplicationFee] = []
  var account: StripeModels.Account?
  var capabilities: [Capability] = []
  var persons: [Person] = []
  var banks: [BankAccount] = []

  func connectedAccounts(created: DateInterval?, limit: Int?) async throws -> [StripeModels.Account] {
    if let accountsError { throw accountsError }
    return accounts
  }
  func retrieveConnectedAccount(id: String) async throws -> StripeModels.Account {
    if let account { return account }
    throw ConnectStubError.boom
  }
  func accountCapabilities(account: String) async throws -> [Capability] {
    capabilities
  }
  func accountPersons(account: String) async throws -> [Person] { persons }
  func accountExternalAccounts(account: String) async throws -> [BankAccount] { banks }
  func applicationFees(charge: String?) async throws -> [ApplicationFee] {
    if let feesError { throw feesError }
    return fees
  }
  func retrieveApplicationFee(id: String) async throws -> ApplicationFee {
    if let fee = fees.first(where: { $0.id == id }) { return fee }
    throw ConnectStubError.boom
  }
  var v2: [V2CoreAccount] = []
  var v2Error: Error?
  var v2Detail: V2CoreAccount?

  func v2Accounts(limit: Int?) async throws -> [V2CoreAccount] {
    if let v2Error { throw v2Error }
    return v2
  }
  func retrieveV2Account(id: String) async throws -> V2CoreAccount {
    if let v2Detail { return v2Detail }
    throw ConnectStubError.boom
  }
}

/// The fee detail's application-fee fixture, reusable in both load paths.
private let applicationFeeFixtureJSON = """
  {
    "id": "fee_test_123",
    "object": "application_fee",
    "account": "acct_test_123",
    "amount": 100,
    "amount_refunded": 0,
    "application": "ca_test_123",
    "balance_transaction": "txn_test_123",
    "charge": "ch_test_123",
    "created": 1234567890,
    "currency": "usd",
    "livemode": false,
    "refunded": false,
    "refunds": {"object": "list", "data": [], "has_more": false, "total_count": 0, "url": "/v1/application_fees/fee_test_123/refunds"}
  }
  """

private func decoded<T: Decodable>(_ json: String, as type: T.Type) -> T {
  do {
    return try JSONDecoder().decode(T.self, from: Data(json.utf8))
  } catch {
    preconditionFailure("fixture must decode: \(error)")
  }
}

private let connectedAccountFixtureJSON = """
  {
    "id": "acct_test_123",
    "object": "account",
    "business_profile": {"name": "Alice's Shop", "name_ka_na": null},
    "charges_enabled": true,
    "country": "US",
    "created": 1234567890,
    "default_currency": "usd",
    "details_submitted": true,
    "email": "alice@example.com",
    "metadata": {},
    "payouts_enabled": false,
    "requirements": {
      "current_deadline": null,
      "currently_due": ["individual.id_number"],
      "disabled_reason": null,
      "errors": null,
      "eventually_due": [],
      "past_due": [],
      "pending_verification": []
    },
    "type": "express"
  }
  """

private let capabilityFixtureJSON = """
  {
    "id": "card_payments",
    "object": "capability",
    "account": "acct_test_123",
    "requested": true,
    "requested_at": 1234567890,
    "requirements": {
      "current_deadline": null,
      "currently_due": [],
      "disabled_reason": null,
      "errors": null,
      "eventually_due": [],
      "past_due": [],
      "pending_verification": []
    },
    "status": "active"
  }
  """

@MainActor
@Suite
struct ConnectModelTests {
  /// The accounts section populates from the backend and stays error-free
  /// on success.
  @Test func accountsSectionPopulatesFromBackend() async {
    let backend = RecordingConnectBackend(
      accounts: [decoded(connectedAccountFixtureJSON, as: StripeModels.Account.self)])
    let model = ConnectModel(backend: backend)
    await model.load()
    #expect(model.phase == .loaded)
    #expect(model.accountsError == nil)
    #expect(model.accounts.count == 1)
    #expect(model.accounts.first?.id == "acct_test_123")
    #expect(ConnectedAccountRow.title(model.accounts[0]) == "Alice's Shop")
  }

  /// A failure in one section must not clear the other (decision 0027):
  /// the fees section failing keeps accounts loaded and vice versa.
  @Test func feeFailureKeepsAccountsLoaded() async {
    let backend = RecordingConnectBackend(
      feesError: ConnectStubError.boom,
      accounts: [decoded(connectedAccountFixtureJSON, as: StripeModels.Account.self)])
    let model = ConnectModel(backend: backend)
    await model.load()
    #expect(model.phase == .loaded)
    #expect(model.feesError != nil)
    #expect(model.accountsError == nil)
    #expect(model.accounts.count == 1)
  }

  @Test func accountFailureKeepsFeesLoaded() async {
    let backend = RecordingConnectBackend(
      accountsError: ConnectStubError.boom,
      fees: [decoded(applicationFeeFixtureJSON, as: ApplicationFee.self)])
    let model = ConnectModel(backend: backend)
    await model.load()
    #expect(model.phase == .loaded)
    #expect(model.accountsError != nil)
    #expect(model.feesError == nil)
    #expect(model.fees.count == 1)
  }

  /// Every section failing still ends the load: the screen shows errors,
  /// not an eternal spinner.
  @Test func everySectionFailingStillEndsTheLoad() async {
    let backend = RecordingConnectBackend(
      accountsError: ConnectStubError.boom, feesError: ConnectStubError.boom)
    let model = ConnectModel(backend: backend)
    await model.load()
    #expect(model.phase == .loaded)
    #expect(model.accountsError != nil)
    #expect(model.feesError != nil)
  }

  /// The 403 from listing connected accounts with a non-platform key is
  /// detected as "not a platform key" (decision 0032), not shown as a
  /// generic failure.
  @Test func forbiddenListMeansNotAPlatformKey() async {
    let backend = RecordingConnectBackend(accountsError: Stripe403())
    let model = ConnectModel(backend: backend)
    await model.load()
    #expect(model.keyIsNotPlatform)
  }

  /// Other failures are not platform-detection: a network error must not
  /// claim the key is wrong.
  @Test func otherErrorsAreNotPlatformDetection() async {
    let backend = RecordingConnectBackend(accountsError: ConnectStubError.boom)
    let model = ConnectModel(backend: backend)
    await model.load()
    #expect(!model.keyIsNotPlatform)
  }

  /// Search filters accounts by ID, email, and business name.
  @Test func searchFiltersAccountsByIDEmailAndName() async {
    let backend = RecordingConnectBackend(
      accounts: [
        decoded(connectedAccountFixtureJSON, as: StripeModels.Account.self),
        decoded(alternateAccountFixtureJSON, as: StripeModels.Account.self),
      ])
    let model = ConnectModel(backend: backend)
    await model.load()

    model.setSearch("acct_alt")
    #expect(model.accounts.count == 1)
    #expect(model.accounts.first?.id == "acct_alt")

    model.setSearch("alice@example.com")
    #expect(model.accounts.count == 1)
    #expect(model.accounts.first?.id == "acct_test_123")

    model.setSearch("ALICE'S")
    #expect(model.accounts.count == 1)
    #expect(model.accounts.first?.id == "acct_test_123")

    model.setSearch("")
    #expect(model.accounts.count == 2)
  }

  /// A success after a failure clears the stored error on the next load.
  @Test func reloadClearsStaleError() async {
    var backend = RecordingConnectBackend(accountsError: ConnectStubError.boom)
    let model = ConnectModel(backend: backend)
    await model.load()
    #expect(model.accountsError != nil)
    backend.accountsError = nil
    backend.accounts = [decoded(connectedAccountFixtureJSON, as: StripeModels.Account.self)]
    let refreshed = ConnectModel(backend: backend)
    await refreshed.load()
    #expect(refreshed.accountsError == nil)
    #expect(refreshed.accounts.count == 1)
  }

  /// A v2-era platform key: the v2 probe answers, the section renders v2
  /// rows, and the v1 list is never consulted (decision 0032, slice 3).
  @Test func v2ListWinsAndRendersV2Rows() async {
    var backend = RecordingConnectBackend(
      accounts: [decoded(connectedAccountFixtureJSON, as: StripeModels.Account.self)])
    backend.v2 = [decodedV2(v2AccountFixtureJSON)]
    let model = ConnectModel(backend: backend)
    await model.load()
    #expect(model.usesV2Accounts)
    #expect(model.v2Accounts.count == 1)
    #expect(model.v2Accounts.first?.id == "acct_test_v2_1")
    #expect(model.accounts.isEmpty)
    #expect(model.accountsError == nil)
    #expect(model.v2Title(model.v2Accounts[0]) == "Vera's Stand")
  }

  /// A v1-era platform key: the v2 probe fails, the v1 list answers, and
  /// the screen stays on v1 rows with no error from the probe.
  @Test func v1ListServesWhenV2ProbeFails() async {
    var backend = RecordingConnectBackend(
      accounts: [decoded(connectedAccountFixtureJSON, as: StripeModels.Account.self)])
    backend.v2Error = Stripe403()
    let model = ConnectModel(backend: backend)
    await model.load()
    #expect(!model.usesV2Accounts)
    #expect(model.v2Accounts.isEmpty)
    #expect(model.accounts.count == 1)
    #expect(model.accountsError == nil)
  }

  /// An empty v2 page does not claim v2 mode: a key that answers 200 with
  /// no accounts still falls back so the v1 list and its states render.
  @Test func emptyV2PageFallsBackToV1() async {
    var backend = RecordingConnectBackend(
      accounts: [decoded(connectedAccountFixtureJSON, as: StripeModels.Account.self)])
    backend.v2 = []
    let model = ConnectModel(backend: backend)
    await model.load()
    #expect(!model.usesV2Accounts)
    #expect(model.accounts.count == 1)
  }

  /// Search narrows the loaded v2 page client-side by name, email, and ID.
  @Test func searchFiltersV2Accounts() async {
    var backend = RecordingConnectBackend()
    backend.v2 = [
      decodedV2(v2AccountFixtureJSON),
      decodedV2("""
      {
        "id": "acct_test_v2_2",
        "object": "v2.core.account",
        "applied_configurations": ["recipient"],
        "contact_email": "buyer@example.com",
        "created": "2026-11-02T00:00:00Z",
        "display_name": "Boris' Depot",
        "livemode": false
      }
      """),
    ]
    let model = ConnectModel(backend: backend)
    await model.load()

    model.setSearch("vera")
    #expect(model.v2Accounts.count == 1)
    #expect(model.v2Accounts.first?.id == "acct_test_v2_1")

    model.setSearch("buyer@")
    #expect(model.v2Accounts.count == 1)
    #expect(model.v2Accounts.first?.id == "acct_test_v2_2")

    model.setSearch("acct_test_v2_1")
    #expect(model.v2Accounts.count == 1)

    model.setSearch("")
    #expect(model.v2Accounts.count == 2)
  }
}

private let alternateAccountFixtureJSON = """
  {
    "id": "acct_alt",
    "object": "account",
    "business_profile": {"name": "Bob's Depot", "name_ka_na": null},
    "charges_enabled": false,
    "country": "US",
    "created": 1234567891,
    "default_currency": "usd",
    "details_submitted": false,
    "email": "bob@example.com",
    "metadata": {},
    "payouts_enabled": false,
    "requirements": {
      "current_deadline": null,
      "currently_due": [],
      "disabled_reason": "requirements.past_due",
      "errors": null,
      "eventually_due": [],
      "past_due": ["individual.id_number"],
      "pending_verification": []
    },
    "type": "express"
  }
  """

/// A recorded v2 account row (decision 0032: the v2 namespace is proven
/// with hand-written fixtures using obviously fake values).
private let v2AccountFixtureJSON = """
  {
    "id": "acct_test_v2_1",
    "object": "v2.core.account",
    "applied_configurations": ["merchant"],
    "closed": false,
    "contact_email": "seller@example.com",
    "created": "2026-11-01T00:00:00Z",
    "display_name": "Vera's Stand",
    "identity": {"country": "US"},
    "livemode": false,
    "metadata": {}
  }
  """

private func decodedV2(_ json: String) -> V2CoreAccount {
  do {
    return try JSONDecoder().decode(V2CoreAccount.self, from: Data(json.utf8))
  } catch {
    preconditionFailure("v2 fixture must decode: \(error)")
  }
}
