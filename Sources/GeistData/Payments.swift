import Foundation
import StripeModels
import StripeClient

/// The payments surface of the Stripe API used by the payments screens.
///
/// Like `StripeDataBackend`, this protocol is read-only: it has no write
/// methods, so a view model built on it cannot write by construction.
/// Payments writes (refunds, captures, cancellations) go through
/// `PaymentsWriter`, which is only handed out in manage mode.
public protocol PaymentsBackend: StripeDataBackend, Sendable {
    /// Payment intents created in `created`, optionally filtered by customer.
    func paymentIntents(created: DateInterval?, customer: String?) async throws -> [PaymentIntent]

    /// A single payment intent by ID.
    func retrievePaymentIntent(id: String) async throws -> PaymentIntent

    /// Search payment intents with a Stripe Search API query string.
    func searchPaymentIntents(query: String) async throws -> [PaymentIntent]

    /// Charges with the given filters. Distinct from
    /// `StripeDataBackend.charges(created:)`, which the home dashboard uses.
    func charges(created: DateInterval?, customer: String?, paymentIntent: String?) async throws -> [Charge]

    /// Refunds, optionally filtered client-side to one charge.
    func refunds(charge: String?) async throws -> [Refund]

    /// A single refund by ID.
    func retrieveRefund(id: String) async throws -> Refund

    /// Disputes, optionally filtered client-side to one charge.
    func disputes(charge: String?) async throws -> [Dispute]

    /// Setup intents created in `created`, optionally filtered by customer.
    func setupIntents(created: DateInterval?, customer: String?) async throws -> [SetupIntent]

    /// A single setup intent by ID.
    func retrieveSetupIntent(id: String) async throws -> SetupIntent

    /// Payment methods, optionally filtered by customer.
    func paymentMethods(customer: String?) async throws -> [PaymentMethod]

    /// A single payment method by ID.
    func retrievePaymentMethod(id: String) async throws -> PaymentMethod

    /// Payment links, optionally filtered by active state.
    func paymentLinks(active: Bool?) async throws -> [PaymentLink]

    /// A single payment link by ID.
    func retrievePaymentLink(id: String) async throws -> PaymentLink

    /// The line items of one payment link.
    func paymentLinkLineItems(id: String) async throws -> [Item]

    /// Checkout sessions, optionally filtered by creation window, customer,
    /// and status (`open`, `complete`, `expired`).
    func checkoutSessions(created: DateInterval?, customer: String?, status: String?) async throws -> [CheckoutSession]

    /// A single checkout session by ID.
    func retrieveCheckoutSession(id: String) async throws -> CheckoutSession

    /// The line items of one checkout session.
    func checkoutSessionLineItems(id: String) async throws -> [Item]

    /// A single mandate by ID.
    func retrieveMandate(id: String) async throws -> Mandate

    /// A single confirmation token by ID.
    func retrieveConfirmationToken(id: String) async throws -> ConfirmationToken

    /// The amount-details line items of one payment intent.
    func intentLineItems(intent: String) async throws -> [PaymentIntentAmountDetailsLineItem]

    /// A single balance transaction by ID (used by the payment timeline).
    func retrieveBalanceTransaction(id: String) async throws -> BalanceTransaction
}

// MARK: - StripeClient conformance

extension StripeClient: PaymentsBackend {
    public func paymentIntents(created: DateInterval?, customer: String?) async throws -> [PaymentIntent] {
        var params = PaymentIntentListParams()
        if let created {
            params.created = .paymentIntentListParamsCreatedVariant1(
                PaymentIntentListParamsCreatedVariant1(
                    gte: Int(created.start.timeIntervalSince1970),
                    lt: Int(created.end.timeIntervalSince1970)
                )
            )
        }
        params.customer = customer
        let result = try await listPaymentIntents(params)
        return result.data
    }

    public func retrievePaymentIntent(id: String) async throws -> PaymentIntent {
        try await retrievePaymentIntent(intent: id)
    }

    public func searchPaymentIntents(query: String) async throws -> [PaymentIntent] {
        var params = PaymentIntentSearchParams()
        params.query = query
        // The generated `searchPaymentIntent` maps the shared generic search
        // result schema, which is typed for charges. The payment-intents
        // search response decodes exactly like a list, so request it typed.
        let result: PaymentFlowsPaymentIntentList = try await request(
            method: "GET",
            path: "/v1/payment_intents/search",
            params: params
        )
        return result.data
    }

    public func charges(created: DateInterval?, customer: String?, paymentIntent: String?) async throws -> [Charge] {
        var params = ChargeListParams()
        if let created {
            params.created = .chargeListParamsCreatedVariant1(
                ChargeListParamsCreatedVariant1(
                    gte: Int(created.start.timeIntervalSince1970),
                    lt: Int(created.end.timeIntervalSince1970)
                )
            )
        }
        params.customer = customer
        params.paymentIntent = paymentIntent
        let result = try await listCharges(params)
        return result.data
    }

    public func refunds(charge: String?) async throws -> [Refund] {
        let result = try await listRefundsV1Refunds()
        guard let charge else { return result.data }
        return result.data.filter { $0.charge.valueOrNil?.idOrNil == charge }
    }

    public func retrieveRefund(id: String) async throws -> Refund {
        try await retrieveRefundV1RefundsRefund(refund: id)
    }

    public func disputes(charge: String?) async throws -> [Dispute] {
        var params = DisputeListParams()
        if let charge { params.charge = charge }
        let result = try await listDisputes(params)
        return result.data
    }

    public func setupIntents(created: DateInterval?, customer: String?) async throws -> [SetupIntent] {
        var params = SetupIntentListParams()
        if let created {
            params.created = .setupIntentListParamsCreatedVariant1(
                SetupIntentListParamsCreatedVariant1(
                    gte: Int(created.start.timeIntervalSince1970),
                    lt: Int(created.end.timeIntervalSince1970)
                )
            )
        }
        params.customer = customer
        let result = try await listSetupIntents(params)
        return result.data
    }

    public func retrieveSetupIntent(id: String) async throws -> SetupIntent {
        try await retrieveSetupIntent(intent: id)
    }

    public func paymentMethods(customer: String?) async throws -> [PaymentMethod] {
        var params = PaymentMethodListParams()
        params.customer = customer
        let result = try await listPaymentMethods(params)
        return result.data
    }

    public func retrievePaymentMethod(id: String) async throws -> PaymentMethod {
        try await retrievePaymentMethod(paymentMethod: id)
    }

    public func paymentLinks(active: Bool?) async throws -> [PaymentLink] {
        var params = PaymentLinkListParams()
        params.active = active
        let result = try await listPaymentLinks(params)
        return result.data
    }

    public func retrievePaymentLink(id: String) async throws -> PaymentLink {
        try await retrievePaymentLink(paymentLink: id)
    }

    public func paymentLinkLineItems(id: String) async throws -> [Item] {
        let result = try await listLineItemsPaymentLink(paymentLink: id)
        return result.data
    }

    public func checkoutSessions(created: DateInterval?, customer: String?, status: String?) async throws -> [CheckoutSession] {
        var params = SessionListParams()
        if let created {
            params.created = .sessionListParamsCreatedVariant1(
                SessionListParamsCreatedVariant1(
                    gte: Int(created.start.timeIntervalSince1970),
                    lt: Int(created.end.timeIntervalSince1970)
                )
            )
        }
        params.customer = customer
        if let status {
            params.status = CheckoutSessionStatus(rawValue: status)
        }
        let result = try await listSessions(params)
        return result.data
    }

    public func retrieveCheckoutSession(id: String) async throws -> CheckoutSession {
        try await retrieveSession(session: id)
    }

    public func checkoutSessionLineItems(id: String) async throws -> [Item] {
        let result = try await listLineItemsSession(session: id)
        return result.data
    }

    public func retrieveMandate(id: String) async throws -> Mandate {
        try await retrieveMandate(mandate: id)
    }

    public func retrieveConfirmationToken(id: String) async throws -> ConfirmationToken {
        try await retrieveConfirmationToken(confirmationToken: id)
    }

    public func intentLineItems(intent: String) async throws -> [PaymentIntentAmountDetailsLineItem] {
        let result = try await listAmountDetailsLineItems(intent: intent)
        return result.data
    }

    public func retrieveBalanceTransaction(id: String) async throws -> BalanceTransaction {
        // Unqualified `retrieveBalanceTransaction(id: id)` would re-enter THIS
        // wrapper (same first label, default-arg-compatible signature) and spin
        // the caller's actor forever. Spelling out the generated method's
        // parameters makes the call unambiguous.
        try await retrieveBalanceTransaction(id: id, nil, expand: nil)
    }
}

// MARK: - Payment timeline

/// One entry in a payment's history: what happened, when, and where to read on.
public struct PaymentTimelineEntry: Sendable, Identifiable, Equatable {
    public enum Kind: Equatable, Sendable {
        /// The payment intent itself.
        case intent(PaymentIntent)
        /// A charge on the intent.
        case charge(Charge)
        /// A refund on a charge.
        case refund(Refund)
        /// A dispute on a charge.
        case dispute(Dispute)
        /// A balance transaction (the money movement behind a charge or refund).
        case balanceTransaction(BalanceTransaction)
    }

    public var id: String
    public var kind: Kind
    /// When the entry happened, for ordering (newest first).
    public var date: Date

    public init(id: String, kind: Kind, date: Date) {
        self.id = id
        self.kind = kind
        self.date = date
    }
}

/// The assembled history of a payment intent: its charges, each charge's
/// refunds and disputes, and the balance transactions behind the money
/// movements. The loader is read-only by construction (it takes only a
/// `PaymentsBackend`).
public struct PaymentTimeline: Sendable, Equatable {
    public var entries: [PaymentTimelineEntry]

    public init(entries: [PaymentTimelineEntry]) {
        self.entries = entries
    }
}

/// Assembles a `PaymentTimeline` for one payment intent.
public struct PaymentTimelineLoader: Sendable {
    private let backend: any PaymentsBackend

    public init(backend: any PaymentsBackend) {
        self.backend = backend
    }

    /// Builds the timeline. Missing pieces (a charge without its balance
    /// transaction, an unknown dispute) are skipped rather than failing the
    /// whole timeline: the payment history is a read-only convenience over
    /// several endpoints, and one gap should not hide the rest.
    public func load(intent: PaymentIntent) async throws -> PaymentTimeline {
        var entries: [PaymentTimelineEntry] = [
            PaymentTimelineEntry(id: intent.id, kind: .intent(intent), date: intent.created.date)
        ]

        let charges = try await backend.charges(created: nil, customer: nil, paymentIntent: intent.id)
        for charge in charges {
            let chargeDate = charge.created.date
            entries.append(PaymentTimelineEntry(id: charge.id, kind: .charge(charge), date: chargeDate))

            let refunds = (charge.refunds?.valueOrNil?.data ?? []).map { $0.id }
            for refundID in refunds {
                if let refund = try? await backend.retrieveRefund(id: refundID) {
                    entries.append(
                        PaymentTimelineEntry(
                            id: refund.id,
                            kind: .refund(refund),
                            date: refund.created.date
                        )
                    )
                    if let btxID = balanceTransactionID(refund.balanceTransaction) {
                        if let btx = try? await backend.retrieveBalanceTransaction(id: btxID) {
                            entries.append(
                                PaymentTimelineEntry(
                                    id: btx.id,
                                    kind: .balanceTransaction(btx),
                                    date: btx.created.date
                                )
                            )
                        }
                    }
                }
            }

            let disputes = (try? await backend.disputes(charge: charge.id)) ?? []
            for dispute in disputes {
                entries.append(
                    PaymentTimelineEntry(
                        id: dispute.id,
                        kind: .dispute(dispute),
                        date: dispute.created.date
                    )
                )
            }

            if let btxID = balanceTransactionID(charge.balanceTransaction) {
                if let btx = try? await backend.retrieveBalanceTransaction(id: btxID) {
                    entries.append(
                        PaymentTimelineEntry(
                            id: btx.id,
                            kind: .balanceTransaction(btx),
                            date: btx.created.date
                        )
                    )
                }
            }
        }

        entries.sort { $0.date > $1.date }
        return PaymentTimeline(entries: entries)
    }
}
