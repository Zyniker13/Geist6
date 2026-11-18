import StripeModels

/// The ID behind a `balance_transaction` field, whether it came back as an
/// ID or as an expanded object.
public func balanceTransactionID(_ field: Nullable<Expandable<BalanceTransaction>>) -> String? {
    switch field.valueOrNil {
    case .id(let id): return id
    case .object(let object): return object.id
    case nil: return nil
    }
}
