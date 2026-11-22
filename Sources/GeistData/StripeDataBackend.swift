import Foundation
import StripeModels
import StripeClient

/// The read-only surface of the Stripe API that Geist6's data layer uses.
///
/// `StripeClient` conforms to this in production. Tests substitute an
/// in-memory implementation, which is what lets the home dashboard and global
/// search be exercised without a network, and lets the "no write in dashboard
/// mode" guarantee be proven by construction: the protocol has no write method.
public protocol StripeDataBackend: Sendable {
    /// The account's current balance, by currency.
    func retrieveBalance() async throws -> Balance

    /// Balance transactions (the ledger) in `created`, optionally one currency.
    func balanceTransactions(created: DateInterval?, currency: String?) async throws -> [BalanceTransaction]

    /// Charges created in `created`.
    func charges(created: DateInterval?) async throws -> [Charge]

    /// A single charge by ID.
    func retrieveCharge(id: String) async throws -> Charge

    /// Customers created in `created`, optionally filtered by exact email.
    func customers(created: DateInterval?, email: String?) async throws -> [Customer]

    /// A single customer by ID.
    func retrieveCustomer(id: String) async throws -> Customer

    /// The account's payouts.
    func payouts() async throws -> [Payout]

    /// A single payout by ID.
    func retrievePayout(id: String) async throws -> Payout

    /// Webhook/API events created in `created`.
    func events(created: DateInterval?) async throws -> [Event]

    /// Search charges with a Stripe Search API query string.
    func searchCharges(query: String) async throws -> [Charge]

    /// Search payment intents with a Stripe Search API query string.
    func searchPaymentIntents(query: String) async throws -> [PaymentIntent]

    /// Fetches the raw response body of a read-only GET under `/v1`.
    ///
    /// Used by the universal open-by-ID lookup, which has no typed model.
    /// The path must be a GET collection path; this protocol has no write
    /// methods, and the production conformance only ever issues GETs.
    func rawObject(path: String) async throws -> Data
}

// MARK: - StripeClient conformance

extension StripeClient: StripeDataBackend {
    public func retrieveBalance() async throws -> Balance {
        try await retrieveBalance(expand: nil)
    }

    public func balanceTransactions(created: DateInterval?, currency: String?) async throws -> [BalanceTransaction] {
        var params = BalanceTransactionListParams()
        if let created {
            params.created = .balanceTransactionListParamsCreatedVariant1(
                BalanceTransactionListParamsCreatedVariant1(
                    gte: Int(created.start.timeIntervalSince1970),
                    lt: Int(created.end.timeIntervalSince1970)
                )
            )
        }
        params.currency = currency
        let result = try await listBalanceTransactions(params)
        return result.data
    }

    public func charges(created: DateInterval?) async throws -> [Charge] {
        var params = ChargeListParams()
        if let created {
            params.created = .chargeListParamsCreatedVariant1(
                ChargeListParamsCreatedVariant1(
                    gte: Int(created.start.timeIntervalSince1970),
                    lt: Int(created.end.timeIntervalSince1970)
                )
            )
        }
        let result = try await listCharges(params)
        return result.data
    }

    public func retrieveCharge(id: String) async throws -> Charge {
        try await retrieveCharge(charge: id)
    }

    public func customers(created: DateInterval?, email: String?) async throws -> [Customer] {
        var params = CustomerListParams()
        if let created {
            params.created = .customerListParamsCreatedVariant1(
                CustomerListParamsCreatedVariant1(
                    gte: Int(created.start.timeIntervalSince1970),
                    lt: Int(created.end.timeIntervalSince1970)
                )
            )
        }
        params.email = email
        let result = try await listCustomers(params)
        return result.data
    }

    public func retrieveCustomer(id: String) async throws -> Customer {
        let response = try await retrieveCustomer(customer: id)
        guard case .customer(let customer) = response else {
            throw StripeClientError.missingResponse
        }
        return customer
    }

    public func payouts() async throws -> [Payout] {
        let result = try await listPayouts()
        return result.data
    }

    public func retrievePayout(id: String) async throws -> Payout {
        try await retrievePayout(payout: id)
    }

    public func events(created: DateInterval?) async throws -> [Event] {
        var params = EventListParams()
        if let created {
            params.created = .eventListParamsCreatedVariant1(
                EventListParamsCreatedVariant1(
                    gte: Int(created.start.timeIntervalSince1970),
                    lt: Int(created.end.timeIntervalSince1970)
                )
            )
        }
        let result = try await listEvents(params)
        return result.data
    }

    public func searchCharges(query: String) async throws -> [Charge] {
        let params = ChargeSearchParams(query: query)
        let result = try await searchCharge(params)
        return result.data
    }

    public func rawObject(path: String) async throws -> Data {
        // `params` is an unnamed `some Encodable`, so an explicit typed nil
        // is required when no parameters are sent.
        try await perform(method: "GET", path: path, params: Optional<[String: String]>.none).body
    }
}
