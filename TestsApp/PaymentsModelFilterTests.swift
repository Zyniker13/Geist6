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
  var sessionsCreated: DateInterval?
  var sessionsCustomer: String?
  var sessionsStatus: String?
}

private enum StubError: Error { case missing }

/// A payments backend that records list parameters and returns fixtures.
private struct FilterRecordingBackend: PaymentsBackend {
  let recorder: FilterRecorder
  var intents: [PaymentIntent] = []
  var charges: [Charge] = []
  var refunds: [Refund] = []
  var sessions: [CheckoutSession] = []
  var payouts: [Payout] = []

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

  func checkoutSessions(created: DateInterval?, customer: String?, status: String?)
    async throws -> [CheckoutSession]
  {
    recorder.listCalls.append("checkoutSessions")
    recorder.sessionsCreated = created
    recorder.sessionsCustomer = customer
    recorder.sessionsStatus = status
    return sessions
  }

  func retrieveCheckoutSession(id: String) async throws -> CheckoutSession { throw StubError.missing }
  func checkoutSessionLineItems(id: String) async throws -> [Item] { [] }
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
  func balanceTransactions(payout: String) async throws -> [BalanceTransaction] { [] }
  func charges(created: DateInterval?) async throws -> [Charge] { [] }
  func customers(created: DateInterval?, email: String?) async throws -> [Customer] { [] }
  func retrieveCustomer(id: String) async throws -> Customer { throw StubError.missing }
  func retrievePayout(id: String) async throws -> Payout { throw StubError.missing }
  func payouts() async throws -> [Payout] {
    recorder.listCalls.append("payouts")
    return payouts
  }
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

  /// The checkout-session fixture follows the stripe-mock sample shape; only
  /// the fields the tests vary (id, created, status, customer) interpolate.
  static func payout(
    id: String, created: Int, status: String, amount: Int
  ) throws -> Payout {
    let json = """
    {
      "amount": \(amount),
      "arrival_date": \(created + 86_400),
      "automatic": true,
      "created": \(created),
      "currency": "usd",
      "id": "\(id)",
      "livemode": false,
      "method": "standard",
      "object": "payout",
      "reconciliation_status": "not_applicable",
      "source_type": "card",
      "status": "\(status)",
      "type": "bank_account"
    }
    """
    return try JSONDecoder().decode(Payout.self, from: Data(json.utf8))
  }

  static func session(
    id: String, created: Int, status: String, customer: String?
  ) throws -> CheckoutSession {
    let customerJSON = customer.map { "\"\($0)\"" } ?? "null"
    let json = """
    {
      "adaptive_pricing": {"enabled": true},
      "after_expiration": {"recovery": {
        "allow_promotion_codes": true, "enabled": true,
        "expires_at": null, "url": null}},
      "allow_promotion_codes": null,
      "allowed_payment_method_types": null,
      "amount_subtotal": null,
      "amount_total": null,
      "automatic_tax": {"enabled": false, "liability": {"type": "account"},
        "provider": null, "status": null},
      "billing_address_collection": null,
      "cancel_url": "https://example.com/cancel",
      "client_reference_id": null,
      "client_secret": null,
      "collected_information": {"business_name": null, "individual_name": null,
        "shipping_details": {"address": {"city": null, "country": null,
          "line1": null, "line2": null, "postal_code": null, "state": null},
          "name": "name"}},
      "consent": {"promotions": null, "terms_of_service": null},
      "consent_collection": {
        "payment_method_reuse_agreement": {"position": "hidden"},
        "promotions": null, "terms_of_service": null},
      "created": \(created),
      "currency": null,
      "currency_conversion": {"amount_subtotal": 1555417355,
        "amount_total": 1117121693, "fx_rate": "291452898",
        "source_currency": "usd"},
      "custom_fields": [],
      "custom_text": {
        "after_submit": {"message": "message"},
        "shipping_address": {"message": "message"},
        "submit": {"message": "message"},
        "terms_of_service_acceptance": {"message": "message"}},
      "customer": \(customerJSON),
      "customer_account": null,
      "customer_creation": null,
      "customer_details": {"address": {"city": null, "country": null,
          "line1": null, "line2": null, "postal_code": null, "state": null},
        "business_name": null, "email": "alice@example.com",
        "individual_name": null, "name": null, "phone": null,
        "tax_exempt": "none", "tax_ids": null},
      "customer_email": null,
      "discounts": null,
      "expires_at": 1234567890,
      "id": "\(id)",
      "integration_identifier": null,
      "invoice": null,
      "invoice_creation": {"enabled": true, "invoice_data": {
        "account_tax_ids": null, "custom_fields": null, "description": null,
        "footer": null, "issuer": {"type": "account"}, "metadata": null,
        "rendering_options": {"amount_tax_display": null, "template": null}}},
      "livemode": false,
      "locale": null,
      "managed_payments": {"enabled": true},
      "metadata": {},
      "mode": "payment",
      "object": "checkout.session",
      "origin_context": null,
      "payment_intent": "pi_test_123",
      "payment_link": null,
      "payment_method_collection": null,
      "payment_method_configuration_details": {"id": "obj_123", "parent": null},
      "payment_method_options": {},
      "payment_method_types": ["card"],
      "payment_status": "unpaid",
      "permissions": {"update_shipping_details": null},
      "phone_number_collection": {"enabled": false},
      "recovered_from": null,
      "saved_payment_method_options": {"allow_redisplay_filters": null,
        "payment_method_remove": null, "payment_method_save": null},
      "setup_intent": null,
      "shipping_address_collection": {"allowed_countries": ["SC"]},
      "shipping_cost": {"amount_subtotal": 1555417355,
        "amount_tax": 1424534716, "amount_total": 1117121693,
        "shipping_rate": null},
      "shipping_options": [],
      "status": "\(status)",
      "submit_type": null,
      "subscription": null,
      "success_url": "https://example.com/success",
      "total_details": {"amount_discount": 406046392, "amount_shipping": null,
        "amount_tax": 1424534716},
      "ui_mode": null,
      "url": "https://checkout.example.com/pay/c/\(id)",
      "wallet_options": {}
    }
    """
    return try JSONDecoder().decode(CheckoutSession.self, from: Data(json.utf8))
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
    // The checkout segment rides created, customer, and status server-side.
    #expect(recorder.sessionsCustomer == "cus_test_9")
    #expect(recorder.sessionsCreated?.start == filter.dateStart)
    #expect(recorder.sessionsCreated?.end == filter.dateEnd)
    #expect(recorder.sessionsStatus == "succeeded")
    // Every segment is refetched once per apply.
    #expect(recorder.listCalls == [
      "paymentIntents", "charges", "refunds", "setupIntents", "paymentMethods", "paymentLinks",
      "checkoutSessions", "payouts",
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

  /// Checkout sessions: the created/customer/status dimensions ride the list
  /// request server-side, and the fetched page is still trimmed client-side
  /// (a session outside the filter must not appear).
  @Test func checkoutFilterRidesServerParamsAndTrimsClientSide() async throws {
    let recorder = FilterRecorder()
    let backend = FilterRecordingBackend(
      recorder: recorder,
      sessions: [
        try FilterFixtures.session(
          id: "cs_test_match", created: 1_750_000_000, status: "open", customer: "cus_test_1"
        ),
        try FilterFixtures.session(
          id: "cs_test_other", created: 1_750_000_000, status: "expired", customer: "cus_test_1"
        ),
      ]
    )
    let model = PaymentsModel(backend: backend)

    await model.apply(PaymentsFilter(status: "open"))

    #expect(recorder.sessionsStatus == "open")
    #expect(recorder.sessionsCreated == nil, "the date range is unset and must not ride the request")
    #expect(model.checkoutSessions.map(\.id) == ["cs_test_match"])
    #expect(model.phase == .loaded)
  }

  @Test func payoutFilterTrimsClientSideByStatusAndAmount() async throws {
    let recorder = FilterRecorder()
    let backend = FilterRecordingBackend(
      recorder: recorder,
      payouts: [
        try FilterFixtures.payout(
          id: "po_match", created: 1_750_000_000, status: "in_transit", amount: 50_000
        ),
        try FilterFixtures.payout(
          id: "po_wrongStatus", created: 1_750_000_000, status: "paid", amount: 50_000
        ),
        try FilterFixtures.payout(
          id: "po_tooSmall", created: 1_750_000_000, status: "in_transit", amount: 100
        ),
      ]
    )
    let model = PaymentsModel(backend: backend)

    await model.apply(PaymentsFilter(status: "in_transit", amountMin: 10_000))

    #expect(recorder.listCalls.contains("payouts"), "payouts must be listed for their segment")
    #expect(model.payouts.map(\.id) == ["po_match"], "only the in-transit payout above the floor survives")
    #expect(model.phase == .loaded)
  }
}
