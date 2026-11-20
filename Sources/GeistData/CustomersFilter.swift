import Foundation
import StripeModels

/// The customers-list filter (decision 0026, mirroring the payments filter
/// of decision 0019): a created range and an exact email match. The created
/// range narrows server-side through the list request's `created` parameter;
/// the email is matched client-side over the fetched page, because Stripe's
/// customer list takes an exact email but partial inputs should still find
/// their rows after a page fetch.
public struct CustomersFilter: Equatable, Sendable {
    /// Created on or after this instant (inclusive).
    public var dateStart: Date?
    /// Created before this instant (exclusive).
    public var dateEnd: Date?
    /// Exact email address, or a fragment matched client-side.
    public var email: String?

    public init(dateStart: Date? = nil, dateEnd: Date? = nil, email: String? = nil) {
        self.dateStart = dateStart
        self.dateEnd = dateEnd
        self.email = email
    }

    /// The no-op filter: matches everything.
    public static let none = CustomersFilter()

    /// True when no dimension is set.
    public var isEmpty: Bool {
        self == CustomersFilter.none
    }

    /// The created range as a half-open interval, or nil unless both bounds
    /// are set. The API takes `created[gte]` and `created[lt]`; an
    /// open-ended range (one bound) is enforced client-side instead of
    /// sending a sentinel timestamp the API might reject.
    public var createdInterval: DateInterval? {
        guard let dateStart, let dateEnd else { return nil }
        return DateInterval(start: dateStart, end: dateEnd)
    }

    /// True when the customer passes every set dimension: created within
    /// the half-open range, and email containing the filter text
    /// case-insensitively (empty text matches everything).
    public func matches(_ customer: Customer) -> Bool {
        if let dateStart, customer.created.date < dateStart { return false }
        if let dateEnd, customer.created.date >= dateEnd { return false }
        if let email, !email.isEmpty {
            let candidate = customer.email.valueOrNil ?? ""
            guard candidate.localizedCaseInsensitiveContains(email) else { return false }
        }
        return true
    }
}
