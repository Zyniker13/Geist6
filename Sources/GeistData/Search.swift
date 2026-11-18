import Foundation
import StripeModels

/// A single result from global search.
public enum SearchHit: Sendable, Identifiable, Equatable {
    case charge(Charge)
    case customer(Customer)

    public var id: String {
        switch self {
        case .charge(let charge): return charge.id
        case .customer(let customer): return customer.id
        }
    }

    /// A short, human label for the results list.
    public var title: String {
        switch self {
        case .charge(let charge):
            return charge.id
        case .customer(let customer):
            return customer.name?.valueOrNil ?? customer.email.valueOrNil ?? customer.id
        }
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
/// 3. A bare amount uses the charges Search API.
/// 4. Anything else falls back to a general charges Search API query.
public struct SearchService: Sendable {
    public let backend: any StripeDataBackend

    public init(backend: any StripeDataBackend) {
        self.backend = backend
    }

    /// The object kind a query's ID prefix names, if it is one we can open.
    /// Only charges and customers are reachable through the data backend.
    public static func idKind(_ id: String) -> IDKind? {
        if id.hasPrefix("ch_") { return .charge }
        if id.hasPrefix("cus_") { return .customer }
        return nil
    }

    public enum IDKind: Sendable {
        case charge
        case customer
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

    /// The full results list for a query.
    public func search(_ query: String) async throws -> [SearchHit] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SearchError.emptyQuery }

        // 1. Open by ID.
        if let kind = Self.idKind(trimmed) {
            switch kind {
            case .charge:
                let charge = try await backend.retrieveCharge(id: trimmed)
                return [.charge(charge)]
            case .customer:
                let customer = try await backend.retrieveCustomer(id: trimmed)
                return [.customer(customer)]
            }
        }

        // 2. Email → customer list filter.
        if trimmed.contains("@") {
            let matches = try await backend.customers(created: nil, email: trimmed)
            return matches.map { .customer($0) }
        }

        // 3. Amount → charges Search API.
        if let amount = Self.amountQuery(trimmed) {
            let matches = try await backend.searchCharges(query: amount)
            return matches.map { .charge($0) }
        }

        // 4. Fallback: general charges Search API query.
        let matches = try await backend.searchCharges(query: trimmed)
        return matches.map { .charge($0) }
    }

    /// The single best hit for a query, or `notFound` if there is none.
    public func resolve(_ query: String) async throws -> SearchHit {
        let hits = try await search(query)
        guard let first = hits.first else { throw SearchError.notFound(query) }
        return first
    }
}
