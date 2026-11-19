import Foundation
import GeistData
import StripeModels
import Testing

@testable import Geist6

/// Records the parameters `PaymentsModel` passes to list calls, so tests
/// can prove the server-side filter dimensions actually ride the requests.
private final class FilterRecorder: @unchecked Sendable {
  var listCalls: [String] = []
  var intentsCreated: DateInterval?
  var intentsCustomer: String?
  var chargesCreated: DateInterval?
  var chargesCustomer: String?
  var setupCreated: DateInterval?
  var setupCustomer: String?
  var methodsCustomer: String?
  var linksActive: Bool?
}

private enum StubError: Error { case missing }

/// A payments backend that records list parameters and returns fixtures.
private struct FilterRecordingBackend: PaymentsBackend {
  let recorder: FilterRecorder
  var intents: [PaymentIntent] = []
  var charges: [Charge] = []
  var refunds: [Refund] = []

  func paymentIntents(created: DateInterval?, customer: String?) async throws -> [PaymentIntent] {
    recorder.listCalls.append("paymentIntents")
    recorder.intentsCreated = created
    recorder.intentsCustomer = customer
    return intents
  }

  func retrievePaymentIntent(id: String) async throws -> PaymentIntent { throw StubError.missing }
  func searchPaymentIntents(query: String) async throws -> [PaymentIntent] { intents }

  func charges(created: DateInterval?, customer: String?, paymentIntent: String?) async throws
    -> [Charge]
  {
    recorder.listCalls.append("charges")
    recorder.chargesCreated = created
    recorder.chargesCustomer = customer
    return charges
  }

  func retrieveCharge(id: String) async throws -> Charge { throw StubError.missing }
  func searchCharges(query: String) async throws -> [Charge] { charges }

  func refunds(charge: String?) async throws -> [Refund] {
    recorder.listCalls.append("refunds")
    return refunds
  }

  func retrieveRefund(id: String) async throws -> Refund { throw StubError.missing }
  func disputes(charge: String?) async throws -> [Dispute] { [] }

  func setupIntents(created: DateInterval?, customer: String?) async throws -> [SetupIntent] {
    recorder.listCalls.append("setupIntents")
    recorder.setupCreated = created
    recorder.setupCustomer = customer
    return []
  }

  func retrieveSetupIntent(id: String) async throws -> SetupIntent { throw StubError.missing }

  func paymentMethods(customer: String?) async throws -> [PaymentMethod] {
    recorder.listCalls.append("paymentMethods")
    recorder.methodsCustomer = customer
    return []
  }

  func retrievePaymentMethod(id: String) async throws -> PaymentMethod { throw StubError.missing }

  func paymentLinks(active: Bool?) async throws -> [PaymentLink] {
    recorder.listCalls.append("paymentLinks")
    recorder.linksActive = active
    return []
  }

  func retrievePaymentLink(id: String) async throws -> PaymentLink { throw StubError.missing }
  func paymentLinkLineItems(id: String) async throws -> [Item] { [] }
  func retrieveMandate(id: String) async throws -> Mandate { throw StubError.missing }
  func retrieveConfirmationToken(id: String) async throws -> ConfirmationToken {
    throw StubError.missing
  }
  func intentLineItems(intent: String) async throws -> [PaymentIntentAmountDetailsLineItem] { [] }
  func retrieveBalanceTransaction(id: String) async throws -> BalanceTransaction {
    throw StubError.missing
  }

  // MARK: StripeDataBackend (unused by the payments list; stubs throw).

  func retrieveBalance() async throws -> Balance { throw StubError.missing }
  func balanceTransactions(created: DateInterval?, currency: String?) async throws
    -> [BalanceTransaction] { [] }
  func charges(created: DateInterval?) async throws -> [Charge] { [] }
  func customers(created: DateInterval?, email: String?) async throws -> [Customer] { [] }
  func retrieveCustomer(id: String) async throws -> Customer { throw StubError.missing }
  func payouts() async throws -> [Payout] { [] }
  func events(created: DateInterval?) async throws -> [Event] { [] }
  func rawObject(path: String) async throws -> Data { throw StubError.missing }
}

/// Minimal fixture builders. All values are obviously fake (test IDs,
/// alice@example.com); shapes follow the objects decoded by the timeline
/// tests, extended with the filter-relevant fields.
private enum FilterFixtures {
  static func intent(
    id: String, created: Int, status: String, amount: Int, customer: String?
  ) throws -> PaymentIntent {
    let customerJSON = customer.map { "\"\($0)\"" } ?? "null"
    let json = """
    {
      "amount": \(amount),
      "amount_capturable": 0,
      "amount_received": \(amount),
      "capture_method": "automatic",
      "confirmation_method": "automatic",
      "created": \(created),
      "currency": "usd",
      "customer": \(customerJSON),
      "id": "\(id)",
      "livemode": false,
      "metadata": {},
      "object": "payment_intent",
      "payment_method_types": ["card"],
      "status": "\(status)"
    }
    """
    return try JSONDecoder().decode(PaymentIntent.self, from: Data(json.utf8))
  }

  static func charge(
    id: String, created: Int, status: String, amount: Int, customer: String?
  ) throws -> Charge {
    let customerJSON = customer.map { "\"\($0)\"" } ?? "null"
    let json = """
    {
      "amount": \(amount),
      "amount_capturable": 0,
      "amount_captured": \(amount),
      "amount_refunded": 0,
      "balance_transaction": null,
      "billing_details": {},
      "captured": true,
      "created": \(created),
      "currency": "usd",
      "customer": \(customerJSON),
      "disputed": false,
      "id": "\(id)",
      "livemode": false,
      "metadata": {},
      "object": "charge",
      "paid": true,
      "payment_method_details": {"type": "card"},
      "refunded": false,
      "refunds": null,
      "status": "\(status)"
    }
    """
    return try JSONDecoder().decode(Charge.self, from: Data(json.utf8))
  }

  static func refund(
    id: String, created: Int, status: String, amount: Int, customer: String?
  ) throws -> Refund {
    let customerJSON = customer.map { "\"\($0)\"" } ?? "null"
    let json = """
    {
      "amount": \(amount),
      "balance_transaction": null,
      "created": \(created),
      "currency": "usd",
      "customer": \(customerJSON),
      "id": "\(id)",
      "livemode": false,
      "object": "refund",
      "status": "\(status)"
    }
    """
    return try JSONDecoder().decode(Refund.self, from: Data(json.utf8))
  }
}

@MainActor
struct PaymentsModelFilterTests {

  @Test func applySetsFilterAndPassesServerSideParams() async throws {
    let recorder = FilterRecorder()
    let model = PaymentsModel(backend: FilterRecordingBackend(recorder: recorder))
    let filter = PaymentsFilter(
      dateStart: Date(timeIntervalSince1970: 1_750_000_000),
      dateEnd: Date(timeIntervalSince1970: 1_750_100_000),
      customer: "cus_test_9",
      status: "succeeded"
    )

    await model.apply(filter)

    #expect(model.filter == filter)
    #expect(recorder.intentsCustomer == "cus_test_9")
    #expect(recorder.intentsCreated?.start == filter.dateStart)
    #expect(recorder.intentsCreated?.end == filter.dateEnd)
    #expect(recorder.chargesCustomer == "cus_test_9")
    #expect(recorder.setupCustomer == "cus_test_9")
    #expect(recorder.methodsCustomer == "cus_test_9")
    // The links segment has no created or customer dimension.
    #expect(recorder.linksActive == nil)
    // Every segment is refetched once per apply.
    #expect(recorder.listCalls == [
      "paymentIntents", "charges", "refunds", "setupIntents", "paymentMethods", "paymentLinks",
    ])
  }

  @Test func applyTrimsFetchedPagesClientSide() async throws {
    let recorder = FilterRecorder()
    let backend = FilterRecordingBackend(
      recorder: recorder,
      intents: [
        try FilterFixtures.intent(
          id: "pi_test_match", created: 1_700_000_000, status: "succeeded", amount: 1_000,
          customer: "cus_test_1"
        ),
        try FilterFixtures.intent(
          id: "pi_test_other", created: 1_700_000_000, status: "requires_payment_method",
          amount: 2_000, customer: "cus_test_1"
        ),
      ],
      charges: [
        try FilterFixtures.charge(
          id: "ch_test_match", created: 1_700_000_000, status: "succeeded", amount: 1_000,
          customer: "cus_test_1"
        ),
        try FilterFixtures.charge(
          id: "ch_test_other", created: 1_700_000_000, status: "failed", amount: 2_000,
          customer: "cus_test_1"
        ),
      ],
      refunds: [
        try FilterFixtures.refund(
          id: "re_test_match", created: 1_700_000_000, status: "succeeded", amount: 1_000,
          customer: "cus_test_1"
        ),
        try FilterFixtures.refund(
          id: "re_test_other", created: 1_700_000_000, status: "canceled", amount: 2_000,
          customer: "cus_test_1"
        ),
      ]
    )
    let model = PaymentsModel(backend: backend)

    await model.apply(PaymentsFilter(status: "succeeded"))

    #expect(model.paymentIntents.map(\.id) == ["pi_test_match"])
    #expect(model.charges.map(\.id) == ["ch_test_match"])
    #expect(model.refunds.map(\.id) == ["re_test_match"])
    #expect(model.phase == .loaded)
  }

  @Test func applyWithUnchangedFilterDoesNotRefetch() async {
    let recorder = FilterRecorder()
    let model = PaymentsModel(backend: FilterRecordingBackend(recorder: recorder))

    await model.apply(PaymentsFilter.none)

    #expect(recorder.listCalls.isEmpty)
    #expect(model.filter == .none)
  }
}
