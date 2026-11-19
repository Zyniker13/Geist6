import Foundation
import GeistData
import StripeModels
import Testing

@testable import Geist6

/// Hand-checked JSON fixtures for the payments tests. All values are
/// obviously fake (test_ IDs, example.com amounts).
private enum PaymentsFixtures {
  static let decoder = JSONDecoder()

  static func intent(
    id: String, created: Int, status: String, amount: Int, currency: String = "usd"
  ) throws -> PaymentIntent {
    let json = """
    {
      "amount": \(amount),
      "amount_capturable": 0,
      "amount_received": \(amount),
      "capture_method": "automatic",
      "confirmation_method": "automatic",
      "created": \(created),
      "currency": "\(currency)",
      "id": "\(id)",
      "livemode": false,
      "metadata": {},
      "object": "payment_intent",
      "payment_method_types": ["card"],
      "status": "\(status)"
    }
    """
    return try decoder.decode(PaymentIntent.self, from: Data(json.utf8))
  }

  static func refundJSON(
    id: String, created: Int, amount: Int, balanceTransaction: String?, currency: String = "usd"
  ) -> String {
    let balanceField = balanceTransaction.map { "\"\($0)\"" } ?? "null"
    return """
    {
      "amount": \(amount),
      "balance_transaction": \(balanceField),
      "created": \(created),
      "currency": "\(currency)",
      "id": "\(id)",
      "livemode": false,
      "object": "refund",
      "status": "succeeded"
    }
    """
  }

  static func refund(
    id: String, created: Int, amount: Int, balanceTransaction: String?, currency: String = "usd"
  ) throws -> Refund {
    let json = refundJSON(
      id: id, created: created, amount: amount, balanceTransaction: balanceTransaction, currency: currency
    )
    return try decoder.decode(Refund.self, from: Data(json.utf8))
  }

  // swiftlint:disable:next function_parameter_count
  static func charge(
    id: String, created: Int, amount: Int, status: String,
    balanceTransaction: String?, refundIDs: [String], currency: String = "usd"
  ) throws -> Charge {
    let refundList: String
    if refundIDs.isEmpty {
      refundList = "null"
    } else {
      let items = refundIDs.map {
        refundJSON(id: $0, created: created, amount: 0, balanceTransaction: nil)
      }
      .joined(separator: ",")
      refundList = """
      {"data": [\(items)], "has_more": false, "object": "list", "total_count": \(refundIDs.count),
       "url": "/v1/charges/\(id)/refunds"}
      """
    }
    let balanceField = balanceTransaction.map { "\"\($0)\"" } ?? "null"
    let json = """
    {
      "amount": \(amount),
      "amount_capturable": 0,
      "amount_captured": \(amount),
      "amount_refunded": 0,
      "balance_transaction": \(balanceField),
      "billing_details": {},
      "captured": true,
      "created": \(created),
      "currency": "\(currency)",
      "disputed": false,
      "id": "\(id)",
      "livemode": false,
      "metadata": {},
      "object": "charge",
      "paid": true,
      "refunded": false,
      "refunds": \(refundList),
      "status": "\(status)"
    }
    """
    return try decoder.decode(Charge.self, from: Data(json.utf8))
  }

  static func dispute(id: String, created: Int) throws -> Dispute {
    let json = """
    {
      "amount": 1000,
      "balance_transactions": [],
      "charge": "ch_test_1",
      "created": \(created),
      "currency": "usd",
      "evidence": {"enhanced_evidence": {}},
      "evidence_details": {
        "due_by": 1700100000,
        "enhanced_eligibility": {},
        "has_evidence": false,
        "past_due": false,
        "submission_count": 0,
        "submission_method": "manual"
      },
      "enhanced_eligibility_types": [],
      "id": "\(id)",
      "is_charge_refundable": false,
      "livemode": false,
      "metadata": {},
      "object": "dispute",
      "reason": "fraudulent",
      "status": "under_review"
    }
    """
    return try decoder.decode(Dispute.self, from: Data(json.utf8))
  }

  static func transaction(id: String, created: Int, net: Int) throws -> BalanceTransaction {
    let json = """
    {
      "amount": \(net),
      "available_on": \(created),
      "balance_type": "payments",
      "created": \(created),
      "currency": "usd",
      "fee": 0,
      "fee_details": [],
      "id": "\(id)",
      "net": \(net),
      "object": "balance_transaction",
      "reporting_category": "charge",
      "status": "available",
      "type": "charge"
    }
    """
    return try decoder.decode(BalanceTransaction.self, from: Data(json.utf8))
  }
}

private enum StubError: Error { case missing }

/// An in-memory payments backend that hands back fixed fixtures, so the
/// timeline loader can be tested without a server.
private struct PaymentsFixtureBackend: PaymentsBackend {
  var intents: [PaymentIntent] = []
  var charges: [Charge] = []
  var refundsByID: [String: Refund] = [:]
  var disputes: [Dispute] = []
  var transactionsByID: [String: BalanceTransaction] = [:]
  var refundFailure: Error?

  func paymentIntents(created: DateInterval?, customer: String?) async throws -> [PaymentIntent] { intents }
  func retrievePaymentIntent(id: String) async throws -> PaymentIntent { intents[0] }
  func searchPaymentIntents(query: String) async throws -> [PaymentIntent] { intents }
  func charges(created: DateInterval?, customer: String?, paymentIntent: String?) async throws -> [Charge] { charges }
  func retrieveCharge(id: String) async throws -> Charge { charges[0] }
  func refunds(charge: String?) async throws -> [Refund] { Array(refundsByID.values) }
  func retrieveRefund(id: String) async throws -> Refund {
    if let failure = refundFailure { throw failure }
    guard let refund = refundsByID[id] else { throw StubError.missing }
    return refund
  }
  func disputes(charge: String?) async throws -> [Dispute] { disputes }
  func setupIntents(created: DateInterval?, customer: String?) async throws -> [SetupIntent] { [] }
  func retrieveSetupIntent(id: String) async throws -> SetupIntent { throw StubError.missing }
  func paymentMethods(customer: String?) async throws -> [PaymentMethod] { [] }
  func retrievePaymentMethod(id: String) async throws -> PaymentMethod { throw StubError.missing }
  func paymentLinks(active: Bool?) async throws -> [PaymentLink] { [] }
  func retrievePaymentLink(id: String) async throws -> PaymentLink { throw StubError.missing }
  func paymentLinkLineItems(id: String) async throws -> [Item] { [] }
  func retrieveMandate(id: String) async throws -> Mandate { throw StubError.missing }
  func retrieveConfirmationToken(id: String) async throws -> ConfirmationToken { throw StubError.missing }
  func intentLineItems(intent: String) async throws -> [PaymentIntentAmountDetailsLineItem] { [] }
  func retrieveBalanceTransaction(id: String) async throws -> BalanceTransaction {
    guard let btx = transactionsByID[id] else { throw StubError.missing }
    return btx
  }

  // MARK: StripeDataBackend (unused by the timeline loader; stubs throw).

  func retrieveBalance() async throws -> Balance { throw StubError.missing }
  func balanceTransactions(created: DateInterval?, currency: String?) async throws -> [BalanceTransaction] { [] }
  func charges(created: DateInterval?) async throws -> [Charge] { charges }
  func customers(created: DateInterval?, email: String?) async throws -> [Customer] { [] }
  func retrieveCustomer(id: String) async throws -> Customer { throw StubError.missing }
  func payouts() async throws -> [Payout] { [] }
  func events(created: DateInterval?) async throws -> [Event] { [] }
  func searchCharges(query: String) async throws -> [Charge] { charges }
  func rawObject(path: String) async throws -> Data { throw StubError.missing }
}

@MainActor
struct PaymentTimelineTests {

  @Test func timelineOrdersEntriesNewestFirst() async throws {
    let intent = try PaymentsFixtures.intent(
      id: "pi_test_1", created: 1_700_000_000, status: "succeeded", amount: 10_000
    )
    let charge = try PaymentsFixtures.charge(
      id: "ch_test_1", created: 1_700_001_000, amount: 10_000,
      status: "succeeded", balanceTransaction: nil, refundIDs: []
    )
    let backend = PaymentsFixtureBackend(charges: [charge])
    let timeline = try await PaymentTimelineLoader(backend: backend).load(intent: intent)

    #expect(timeline.entries.count == 2)
    #expect(timeline.entries[0].id == "ch_test_1")
    #expect(timeline.entries[1].id == "pi_test_1")
  }

  @Test func timelineIncludesRefundDisputeAndTransactions() async throws {
    let intent = try PaymentsFixtures.intent(
      id: "pi_test_1", created: 1_700_000_000, status: "succeeded", amount: 10_000
    )
    let charge = try PaymentsFixtures.charge(
      id: "ch_test_1", created: 1_700_001_000, amount: 10_000,
      status: "succeeded", balanceTransaction: "txn_test_1", refundIDs: ["re_test_1"]
    )
    let refund = try PaymentsFixtures.refund(
      id: "re_test_1", created: 1_700_002_000, amount: 2_000, balanceTransaction: "txn_test_2"
    )
    let dispute = try PaymentsFixtures.dispute(id: "dp_test_1", created: 1_700_003_000)
    let backend = PaymentsFixtureBackend(
      charges: [charge],
      refundsByID: ["re_test_1": refund],
      disputes: [dispute],
      transactionsByID: [
        "txn_test_1": try PaymentsFixtures.transaction(id: "txn_test_1", created: 1_700_001_500, net: 9_600),
        "txn_test_2": try PaymentsFixtures.transaction(id: "txn_test_2", created: 1_700_002_500, net: -2_000)
      ]
    )
    let timeline = try await PaymentTimelineLoader(backend: backend).load(intent: intent)

    let ids = timeline.entries.map(\.id)
    #expect(ids.contains("re_test_1"))
    #expect(ids.contains("dp_test_1"))
    #expect(ids.contains("txn_test_1"))
    #expect(ids.contains("txn_test_2"))

    // Newest first throughout.
    let dates = timeline.entries.map(\.date)
    #expect(dates == dates.sorted(by: >))

    // The dispute entry carries the dispute object.
    guard case .dispute(let carried)? = timeline.entries.first(where: { $0.id == "dp_test_1" })?.kind else {
      Issue.record("dispute entry missing")
      return
    }
    #expect(carried.id == "dp_test_1")
  }

  @Test func timelineSurvivesMissingPieces() async throws {
    let intent = try PaymentsFixtures.intent(
      id: "pi_test_1", created: 1_700_000_000, status: "succeeded", amount: 10_000
    )
    // One charge whose balance transaction and refunds can't be fetched.
    let charge = try PaymentsFixtures.charge(
      id: "ch_test_1", created: 1_700_001_000, amount: 10_000,
      status: "succeeded", balanceTransaction: "txn_missing", refundIDs: ["re_missing"]
    )
    // A second charge with no payment method details at all.
    let plainCharge = try PaymentsFixtures.charge(
      id: "ch_test_2", created: 1_700_004_000, amount: 5_000,
      status: "pending", balanceTransaction: nil, refundIDs: []
    )
    let backend = PaymentsFixtureBackend(charges: [charge, plainCharge], refundFailure: StubError.missing)
    let timeline = try await PaymentTimelineLoader(backend: backend).load(intent: intent)

    // The timeline still assembles around the gaps.
    let ids = timeline.entries.map(\.id)
    #expect(ids.contains("pi_test_1"))
    #expect(ids.contains("ch_test_1"))
    #expect(ids.contains("ch_test_2"))
    #expect(!ids.contains("txn_missing"))
    #expect(!ids.contains("re_missing"))
  }
}
