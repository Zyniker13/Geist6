import Foundation
import StripeModels

/// The payments-list filter (M4c-5, decision 0019). Each dimension is
/// optional; an empty filter matches everything. `matches(_:)` applies only
/// the dimensions a type has and ignores the rest, so one filter serves all
/// six payment segments (intents, charges, refunds, setup intents, payment
/// methods, payment links, checkout sessions).
///
/// Server-side narrowing is used where the backend protocol supports it
/// (created range, customer, payment-link active state); every other
/// dimension matches client-side over the fetched page. Both layers run
/// over the same filter, so a narrowed server response is only ever trimmed
/// further client-side.
public struct PaymentsFilter: Equatable, Sendable {
    /// Created on or after this instant (inclusive).
    public var dateStart: Date?
    /// Created before this instant (exclusive).
    public var dateEnd: Date?
    /// Customer ID (`cus_test_...`), matched on the object's customer field.
    public var customer: String?
    /// Status raw value (`succeeded`, `requires_payment_method`, ...).
    /// Refunds match the raw status string.
    public var status: String?
    /// Amount bounds in the smallest currency unit, both inclusive.
    public var amountMin: Int?
    public var amountMax: Int?
    /// Payment-method type (`card`, `sepa_debit`, ...). Intents check
    /// `payment_method_types`, charges the charge's method type, payment
    /// methods the method's type, payment links the link's method types.
    public var methodType: String?
    /// Payment links only: the link's active state.
    public var linkActive: Bool?

    public init(
        dateStart: Date? = nil,
        dateEnd: Date? = nil,
        customer: String? = nil,
        status: String? = nil,
        amountMin: Int? = nil,
        amountMax: Int? = nil,
        methodType: String? = nil,
        linkActive: Bool? = nil
    ) {
        self.dateStart = dateStart
        self.dateEnd = dateEnd
        self.customer = customer
        self.status = status
        self.amountMin = amountMin
        self.amountMax = amountMax
        self.methodType = methodType
        self.linkActive = linkActive
    }

    /// The no-op filter: matches everything.
    public static let none = PaymentsFilter()

    /// True when no dimension is set.
    public var isEmpty: Bool {
        self == PaymentsFilter.none
    }

    /// The created range as a half-open interval, or nil unless both bounds
    /// are set. The API takes `created[gte]` and `created[lt]`; an
    /// open-ended range (one bound) is enforced client-side instead of
    /// sending a sentinel timestamp the API might reject.
    public var createdInterval: DateInterval? {
        guard let dateStart, let dateEnd else { return nil }
        return DateInterval(start: dateStart, end: dateEnd)
    }
}

// MARK: - Segments and fields

extension PaymentsFilter {
    /// The payment-list segments a filter can narrow.
    public enum Segment: String, CaseIterable, Sendable {
        case paymentIntents, charges, refunds, setupIntents, paymentMethods, paymentLinks
        case checkoutSessions
    }

    /// A filter dimension, so the UI can show exactly the fields that mean
    /// something for the selected segment.
    public enum Field: String, CaseIterable, Sendable {
        case dateRange, customer, status, amount, methodType, linkActive
    }

    /// The dimensions that apply to a segment. Payment links carry no
    /// created date or customer, refunds have no method type, and so on.
    public static func fields(for segment: Segment) -> Set<Field> {
        switch segment {
        case .paymentIntents, .charges:
            return [.dateRange, .customer, .status, .amount, .methodType]
        case .refunds:
            return [.dateRange, .customer, .status, .amount]
        case .setupIntents:
            return [.dateRange, .customer, .status, .methodType]
        case .paymentMethods:
            return [.dateRange, .customer, .methodType]
        case .paymentLinks:
            return [.methodType, .linkActive]
        case .checkoutSessions:
            return [.dateRange, .customer, .status]
        }
    }

    /// True when at least one dimension relevant to `segment` is set.
    public func isRelevant(to segment: Segment) -> Bool {
        PaymentsFilter.fields(for: segment).contains { isSet($0) }
    }

    private func isSet(_ field: Field) -> Bool {
        switch field {
        case .dateRange: return dateStart != nil || dateEnd != nil
        case .customer: return customer != nil
        case .status: return status != nil
        case .amount: return amountMin != nil || amountMax != nil
        case .methodType: return methodType != nil
        case .linkActive: return linkActive != nil
        }
    }
}

// MARK: - Matching

extension PaymentsFilter {
    /// Created within the half-open range [dateStart, dateEnd): the start is
    /// inclusive, the end exclusive.
    private func matchesCreated(_ created: StripeTimestamp) -> Bool {
        if let dateStart, created.date < dateStart { return false }
        if let dateEnd, created.date >= dateEnd { return false }
        return true
    }

    /// Amount within the inclusive bounds.
    private func matchesAmount(_ amount: Int) -> Bool {
        if let amountMin, amount < amountMin { return false }
        if let amountMax, amount > amountMax { return false }
        return true
    }

    /// Customer ID equal to the filter's customer, when one is set. An
    /// object without a customer (empty extraction) does not match.
    private func matchesCustomer(_ id: String) -> Bool {
        guard let customer else { return true }
        return !id.isEmpty && id == customer
    }

    private func matchesMethodType(_ types: [String]) -> Bool {
        guard let methodType else { return true }
        return types.contains(methodType)
    }

    public func matches(_ intent: PaymentIntent) -> Bool {
        matchesCreated(intent.created)
            && matchesAmount(intent.amount)
            && matchesCustomer(customerID(intent.customer.valueOrNil))
            && matchesMethodType(intent.paymentMethodTypes)
            && (status.map { intent.status.rawValue == $0 } ?? true)
    }

    public func matches(_ charge: Charge) -> Bool {
        matchesCreated(charge.created)
            && matchesAmount(charge.amount)
            && matchesCustomer(customerID(charge.customer.valueOrNil))
            && matchesMethodType(charge.paymentMethodDetails.valueOrNil.map { [$0.type] } ?? [])
            && (status.map { charge.status.rawValue == $0 } ?? true)
    }

    public func matches(_ refund: Refund) -> Bool {
        matchesCreated(refund.created)
            && matchesAmount(refund.amount)
            && matchesCustomer(customerID(refund.customer.valueOrNil))
            && (status.map { refund.status.valueOrNil == $0 } ?? true)
    }

    public func matches(_ intent: SetupIntent) -> Bool {
        matchesCreated(intent.created)
            && matchesCustomer(customerID(intent.customer.valueOrNil))
            && matchesMethodType(intent.paymentMethodTypes)
            && (status.map { intent.status.rawValue == $0 } ?? true)
    }

    public func matches(_ method: PaymentMethod) -> Bool {
        matchesCreated(method.created)
            && matchesCustomer(customerID(method.customer.valueOrNil))
            && matchesMethodType([method.type.rawValue])
    }

    public func matches(_ link: PaymentLink) -> Bool {
        matchesMethodType(link.paymentMethodTypes.valueOrNil?.map(\.rawValue) ?? [])
            && (linkActive.map { link.active == $0 } ?? true)
    }

    /// Checkout sessions: created, customer, and status (`open`, `complete`,
    /// `expired`) apply; amount is skipped because `amount_total` is null
    /// until the session is completed.
    public func matches(_ session: CheckoutSession) -> Bool {
        matchesCreated(session.created)
            && matchesCustomer(customerID(session.customer.valueOrNil))
            && (status.map { session.status.valueOrNil?.rawValue == $0 } ?? true)
    }
}

// MARK: - Customer extraction

/// The object's customer ID, or "" when absent or unexpandable. These small
/// switches mirror the App target's helpers so the filter keeps GeistData
/// free of an App dependency.
private func customerID(_ customer: PaymentIntentCustomer?) -> String {
    switch customer {
    case .string(let id): return id
    case .customer(let customer): return customer.id
    case .deletedCustomer(let deleted): return deleted.id
    case .none, .other: return ""
    }
}

private func customerID(_ customer: ChargeCustomer?) -> String {
    switch customer {
    case .string(let id): return id
    case .customer(let customer): return customer.id
    case .deletedCustomer(let deleted): return deleted.id
    case .none, .other: return ""
    }
}

private func customerID(_ customer: RefundCustomer?) -> String {
    switch customer {
    case .string(let id): return id
    case .customer(let customer): return customer.id
    case .deletedCustomer(let deleted): return deleted.id
    case .none, .other: return ""
    }
}

private func customerID(_ customer: SetupIntentCustomer?) -> String {
    switch customer {
    case .string(let id): return id
    case .customer(let customer): return customer.id
    case .deletedCustomer(let deleted): return deleted.id
    case .none, .other: return ""
    }
}

private func customerID(_ customer: CheckoutSessionCustomer?) -> String {
    switch customer {
    case .string(let id): return id
    case .customer(let customer): return customer.id
    case .deletedCustomer(let deleted): return deleted.id
    case .none, .other: return ""
    }
}

private func customerID(_ customer: Expandable<Customer>?) -> String {
    switch customer {
    case .id(let id): return id
    case .object(let customer): return customer.id
    case .none: return ""
    }
}
