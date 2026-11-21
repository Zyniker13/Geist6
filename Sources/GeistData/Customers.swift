import Foundation
import StripeModels
import StripeClient

/// The customers surface of the Stripe API used by the customer screens.
///
/// Like `PaymentsBackend`, this protocol is read-only: it has no write
/// methods, so a view model built on it cannot write by construction.
/// Customer writes (create, update, delete, discounts, tax IDs, funding)
/// go through `CustomersWriter`, which is only handed out in manage mode.
///
/// The base verbs (list and retrieve customers) come from
/// `StripeDataBackend`, which this protocol extends.
public protocol CustomersBackend: StripeDataBackend, Sendable {
    /// Search customers with a Stripe Search API query string.
    func searchCustomers(query: String) async throws -> [Customer]

    /// The balance transactions of one customer.
    func customerBalanceTransactions(customer: String) async throws -> [CustomerBalanceTransaction]

    /// A single balance transaction of one customer.
    func retrieveCustomerBalanceTransaction(customer: String, id: String) async throws -> CustomerBalanceTransaction

    /// The cash balance transactions of one customer.
    func customerCashBalanceTransactions(customer: String) async throws -> [CustomerCashBalanceTransaction]

    /// A single cash balance transaction of one customer.
    func retrieveCustomerCashBalanceTransaction(customer: String, id: String) async throws -> CustomerCashBalanceTransaction

    /// The payment sources attached to one customer.
    func customerPaymentSources(customer: String) async throws -> [PaymentSource]

    /// A single payment source attached to one customer.
    func retrieveCustomerPaymentSource(customer: String, id: String) async throws -> PaymentSource

    /// The payment methods of one customer (the per-customer listing),
    /// optionally filtered by payment method type.
    func customerPaymentMethods(customer: String, type: String?) async throws -> [PaymentMethod]

    /// A single payment method of one customer.
    func retrieveCustomerPaymentMethod(customer: String, id: String) async throws -> PaymentMethod

    /// Tax IDs. The tax IDs of one customer when `customer` is given;
    /// the account-wide listing otherwise.
    func taxIDs(customer: String?) async throws -> [TaxId]

    /// A single tax ID, looked up under its customer when `customer` is
    /// given; account-wide otherwise.
    func retrieveTaxID(customer: String?, id: String) async throws -> TaxId
}

// MARK: - StripeClient conformance

extension StripeClient: CustomersBackend {
    public func searchCustomers(query: String) async throws -> [Customer] {
        var params = CustomerSearchParams()
        params.query = query
        let result = try await searchCustomer(params)
        return result.data
    }

    public func customerBalanceTransactions(customer: String) async throws -> [CustomerBalanceTransaction] {
        let result = try await listBalanceTransactions(customer: customer)
        return result.data
    }

    public func retrieveCustomerBalanceTransaction(customer: String, id: String) async throws -> CustomerBalanceTransaction {
        // The generated method's first label is `customer`, so this call is
        // unambiguous with the account-wide balance transaction wrapper in
        // `StripeDataBackend`.
        try await retrieveCustomerBalanceTransaction(customer: customer, transaction: id)
    }

    public func customerCashBalanceTransactions(customer: String) async throws -> [CustomerCashBalanceTransaction] {
        let result = try await listCashBalanceTransactions(customer: customer)
        return result.data
    }

    public func retrieveCustomerCashBalanceTransaction(customer: String, id: String) async throws -> CustomerCashBalanceTransaction {
        try await retrieveCustomerCashBalanceTransaction(customer: customer, transaction: id)
    }

    public func customerPaymentSources(customer: String) async throws -> [PaymentSource] {
        let result = try await listSources(customer: customer)
        return result.data
    }

    public func retrieveCustomerPaymentSource(customer: String, id: String) async throws -> PaymentSource {
        try await retrievePaymentSource(customer: customer, id: id)
    }

    public func customerPaymentMethods(customer: String, type: String?) async throws -> [PaymentMethod] {
        var params = CustomerListPaymentMethodsParams()
        if let type {
            params.type = CustomerListPaymentMethodsParamsType(rawValue: type)
        }
        let result = try await listPaymentMethodsCustomer(customer: customer, params)
        return result.data
    }

    public func retrieveCustomerPaymentMethod(customer: String, id: String) async throws -> PaymentMethod {
        try await retrievePaymentMethodCustomer(customer: customer, paymentMethod: id)
    }

    public func taxIDs(customer: String?) async throws -> [TaxId] {
        if let customer {
            let result = try await listTaxIds(customer: customer)
            return result.data
        }
        let result = try await listTaxIds()
        return result.data
    }

    public func retrieveTaxID(customer: String?, id: String) async throws -> TaxId {
        if let customer {
            try await retrieveTaxId(customer: customer, id: id)
        } else {
            try await retrieveTaxId(id: id)
        }
    }
}
