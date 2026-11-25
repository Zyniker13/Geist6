import Foundation
import StripeModels
import StripeClient

/// The Connect surface of the Stripe API used by the Connect screens
/// (M8, decision 0032). Read-only: every method is a list or a retrieve.
/// Connect writes (account links, login links, account sessions, capability
/// updates, person changes, external-account deletion, fee refunds) go
/// through `ConnectWriteService`, which is only handed out in manage mode.
public protocol ConnectBackend: Sendable {
    /// Connected accounts of the platform this key belongs to
    /// (GET /v1/accounts with the platform key).
    func connectedAccounts(created: DateInterval?, limit: Int?) async throws -> [Account]

    /// A single connected account by ID.
    func retrieveConnectedAccount(id: String) async throws -> Account

    /// The capabilities of one connected account.
    func accountCapabilities(account: String) async throws -> [Capability]

    /// The persons of one connected account.
    func accountPersons(account: String) async throws -> [Person]

    /// The external accounts (bank accounts and cards) of one connected account.
    func accountExternalAccounts(account: String) async throws -> [BankAccount]

    /// The application fees the platform earned on this account's payments.
    func applicationFees(charge: String?) async throws -> [ApplicationFee]

    /// A single application fee by ID.
    func retrieveApplicationFee(id: String) async throws -> ApplicationFee

    /// The platform's accounts on the v2 namespace (GET /v2/core/accounts).
    /// Supported only by v2-era platform keys: stripe-mock and non-platform
    /// keys fail here, which is the slice-3 detection signal.
    func v2Accounts(limit: Int?) async throws -> [V2CoreAccount]

    /// One v2-namespace account by ID (GET /v2/core/accounts/{id}).
    func retrieveV2Account(id: String) async throws -> V2CoreAccount
}

// MARK: - StripeClient conformance

extension StripeClient: ConnectBackend {
    public func connectedAccounts(created: DateInterval?, limit: Int?) async throws -> [Account] {
        var params = AccountListParams()
        if let created {
            params.created = .accountListParamsCreatedVariant1(
                AccountListParamsCreatedVariant1(
                    gte: Int(created.start.timeIntervalSince1970),
                    lt: Int(created.end.timeIntervalSince1970)
                )
            )
        }
        params.limit = limit
        let result = try await listAccounts(params)
        return result.data
    }

    public func retrieveConnectedAccount(id: String) async throws -> Account {
        try await retrieveAccount(account: id, AccountsAccountRetrieveParams())
    }

    public func accountCapabilities(account: String) async throws -> [Capability] {
        let result = try await listCapabilities(account: account, CapabilityListParams())
        return result.data
    }

    public func accountPersons(account: String) async throws -> [Person] {
        let result = try await listPersons(account: account, PersonListParams())
        return result.data
    }

    public func accountExternalAccounts(account: String) async throws -> [BankAccount] {
        var params = ExternalAccountListParams()
        params.object = .bankAccount
        let result = try await listExternalAccounts(account: account, params)
        let banks = result.data.compactMap { item -> BankAccount? in
            if case .bankAccount(let bank) = item { return bank }
            return nil
        }
        return banks
    }

    public func applicationFees(charge: String?) async throws -> [ApplicationFee] {
        var params = ApplicationFeeListParams()
        params.charge = charge
        let result = try await listApplicationFees(params)
        return result.data
    }

    public func retrieveApplicationFee(id: String) async throws -> ApplicationFee {
        try await retrieveApplicationFee(id: id, ApplicationFeeRetrieveParams())
    }

    public func v2Accounts(limit: Int?) async throws -> [V2CoreAccount] {
        var params = V2CoreAccountListParams()
        params.limit = limit
        let result = try await listV2CoreAccounts(params)
        return result.data
    }

    public func retrieveV2Account(id: String) async throws -> V2CoreAccount {
        try await retrieveAccount(id: id, V2CoreAccountRetrieveParams())
    }
}
