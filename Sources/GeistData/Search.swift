import Foundation
import StripeModels
import StripeClient

/// A single result from global search.
public enum SearchHit: Sendable, Identifiable, Equatable, Hashable {
    case charge(Charge)
    case customer(Customer)
    case paymentIntent(PaymentIntent)
    /// An object of a kind without a typed detail view, resolved by ID.
    case object(kind: StripeObjectKind, id: String, json: StripeJSON)

    public var id: String {
        switch self {
        case .charge(let charge): return charge.id
        case .customer(let customer): return customer.id
        case .paymentIntent(let intent): return intent.id
        case .object(_, let id, _): return id
        }
    }

    /// A short, human label for the results list.
    public var title: String {
        switch self {
        case .charge(let charge):
            return charge.id
        case .customer(let customer):
            return customer.name?.valueOrNil ?? customer.email.valueOrNil ?? customer.id
        case .paymentIntent(let intent):
            return intent.description.valueOrNil ?? intent.id
        case .object(let kind, let id, _):
            return "\(kind.label) \(id)"
        }
    }

    /// The object kind of this hit, if it is one the open-by-ID router knows.
    public var objectKind: StripeObjectKind? {
        switch self {
        case .charge: return .charge
        case .customer: return .customer
        case .paymentIntent: return .paymentIntent
        case .object(let kind, _, _): return kind
        }
    }
}

/// Hashes by case and ID only. SwiftUI's `navigationDestination(item:)`
/// needs `Hashable`, but the `.object` payload carries a raw JSON tree
/// that is not hashable, and hashing a whole decoded object would be
/// wasted work anyway: two hits with the same kind and ID are the same
/// object.
extension SearchHit {
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .charge: hasher.combine(0)
        case .customer: hasher.combine(1)
        case .paymentIntent: hasher.combine(3)
        case .object: hasher.combine(2)
        }
        hasher.combine(id)
    }

    public static func == (lhs: SearchHit, rhs: SearchHit) -> Bool {
        switch (lhs, rhs) {
        case (.charge(let a), .charge(let b)): return a == b
        case (.customer(let a), .customer(let b)): return a == b
        case (.paymentIntent(let a), .paymentIntent(let b)): return a == b
        case let (.object(k1, i1, _), .object(k2, i2, _)): return k1 == k2 && i1 == i2
        default: return false
        }
    }
}

/// The result set for a query, plus whether it came from the fallback path.
///
/// When the Stripe Search API is unavailable for a query, the service falls
/// back to a plain list fetch filtered client-side. Those results cover only
/// one page, so they are marked `approximate` for honest presentation.
public struct SearchResultSet: Sendable, Equatable {
    public let hits: [SearchHit]
    public let approximate: Bool

    public init(hits: [SearchHit], approximate: Bool = false) {
        self.hits = hits
        self.approximate = approximate
    }
}

/// Errors surfaced by global search.
public enum SearchError: Error, Sendable, Equatable {
    case emptyQuery
    case notFound(String)
}

/// Routes a raw query to the right Stripe lookup.
///
/// The routing order is fixed and documented in `docs/metrics.md`:
/// 1. A Stripe object ID opens that object directly (`retrieve`).
/// 2. An email address filters the customer list.
/// 3. A bare amount searches charges and payment intents.
/// 4. Anything else runs a general Search API query over charges and
///    payment intents.
///
/// Steps 3 and 4 fall back to a plain charges list filtered client-side
/// when the charges Search API reports itself unavailable (HTTP 404 or an
/// explicit "not supported / not enabled" error); see `docs/decisions/0013`.
/// Payment-intent Search hits merge into the same results; see 0023.
public struct SearchService: Sendable {
    public let backend: any StripeDataBackend

    public init(backend: any StripeDataBackend) {
        self.backend = backend
    }

    /// The object kind a query's ID prefix names, if it is one we can open.
    /// Charges and customers resolve to typed hits; every other known kind
    /// resolves through the raw open-by-ID path.
    public static func idKind(_ id: String) -> IDKind? {
        guard let kind = StripeObjectKind.match(id) else { return nil }
        switch kind {
        case .charge: return .charge
        case .customer: return .customer
        default: return .other(kind)
        }
    }

    public enum IDKind: Sendable, Equatable {
        case charge
        case customer
        case other(StripeObjectKind)
    }

    /// Build a charges Search API query for a bare amount, or `nil` if the
    /// query is not a bare amount. The amount is the smallest currency unit,
    /// matching the Search API's `amount` field.
    public static func amountQuery(_ query: String) -> String? {
        let number = "^[0-9]+$"
        let numberCurrency = "^[0-9]+ [A-Z]{3}$"
        if query.range(of: number, options: .regularExpression) != nil
            || query.range(of: numberCurrency, options: .regularExpression) != nil {
            return "amount:\(query)"
        }
        return nil
    }

    /// Whether an error indicates the Search API is unavailable for this
    /// object or account (as opposed to a transport or auth failure).
    public static func searchUnavailable(_ error: Error) -> Bool {
        guard let apiError = error as? StripeAPIError else { return false }
        if apiError.status == 404 { return true }
        let message = [apiError.detail.message, apiError.detail.code]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")
        // Stripe's real wording is "Search has not been enabled for this
        // account", so match "been enabled" as well as the shorter form.
        let markers = ["been enabled", "not enabled", "no such endpoint", "does not support", "unsupported"]
        return markers.contains { message.contains($0) }
    }

    /// The full results list for a query.
    public func search(_ query: String) async throws -> SearchResultSet {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SearchError.emptyQuery }

        // 1. Open by ID.
        if let kind = Self.idKind(trimmed) {
            switch kind {
            case .charge:
                let charge = try await backend.retrieveCharge(id: trimmed)
                return SearchResultSet(hits: [.charge(charge)])
            case .customer:
                let customer = try await backend.retrieveCustomer(id: trimmed)
                return SearchResultSet(hits: [.customer(customer)])
            case .other(let stripeKind):
                let resolved = try await ObjectByIDService(backend: backend).fetch(trimmed)
                return SearchResultSet(hits: [.object(kind: stripeKind, id: resolved.id, json: resolved.json)])
            }
        }

        // 2. Email → customer list filter.
        if trimmed.contains("@") {
            let matches = try await backend.customers(created: nil, email: trimmed)
            return SearchResultSet(hits: matches.map { .customer($0) })
        }

        // 3. Amount → charges and payment intents Search API (with fallback).
        if let amount = Self.amountQuery(trimmed) {
            return try await chargesAndIntents(amount)
        }

        // 4. Fallback: general Search API query for charges and intents.
        return try await chargesAndIntents(trimmed)
    }

    /// Searches charges and payment intents for one query, merging both
    /// sides into a single result set. Each side tolerates its own
    /// Search-unavailable error: a side that is unavailable contributes
    /// nothing, and when the charge side is unavailable the client-side
    /// fallback list supplies the charge hits (marked approximate). A
    /// failure that is not an availability error is rethrown.
    private func chargesAndIntents(_ query: String) async throws -> SearchResultSet {
        var chargeHits: [SearchHit]?
        do {
            chargeHits = try await backend.searchCharges(query: query).map { .charge($0) }
        } catch {
            guard Self.searchUnavailable(error) else { throw error }
        }
        var intentHits: [SearchHit] = []
        do {
            intentHits = try await backend.searchPaymentIntents(query: query)
                .map { .paymentIntent($0) }
        } catch {
            guard Self.searchUnavailable(error) else { throw error }
        }
        if let chargeHits {
            return SearchResultSet(hits: chargeHits + intentHits)
        }
        // Charges Search unavailable: fall back to the plain charges list
        // (approximate), keeping any intent hits found alongside it.
        let fallback = try await fallbackCharges(matching: query)
        return SearchResultSet(hits: fallback.0 + intentHits, approximate: true)
    }

    /// Fetches the plain charges list and filters client-side by the query:
    /// substring match on id/description/customer, or an exact amount when
    /// the whole query parses as a number. One page, best-effort.
    private func fallbackCharges(matching query: String) async throws -> ([SearchHit], Bool) {
        let all = try await backend.charges(created: nil)
        let needle = query.lowercased()
        let amount = Int(query)
        let matches = all.filter { charge in
            if needle.contains("@"), let email = charge.billingDetails.email.valueOrNil {
                return email.lowercased() == needle
            }
            if charge.id.lowercased().contains(needle) { return true }
            if let description = charge.description.valueOrNil,
                description.lowercased().contains(needle) {
                return true
            }
            if let customer = Self.customerID(of: charge), customer.lowercased().contains(needle) {
                return true
            }
            if let amount, charge.amount == amount { return true }
            return false
        }
        return (matches.map { .charge($0) }, true)
    }

    /// The customer ID of a charge, whatever expanded shape the API sent.
    private static func customerID(of charge: Charge) -> String? {
        switch charge.customer.valueOrNil {
        case .string(let id): return id
        case .customer(let customer): return customer.id
        default: return nil
        }
    }

    /// The single best hit for a query, or `notFound` if there is none.
    public func resolve(_ query: String) async throws -> SearchHit {
        let results = try await search(query)
        guard let first = results.hits.first else { throw SearchError.notFound(query) }
        return first
    }
}
