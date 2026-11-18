import Foundation
import StripeModels

/// A decoded Stripe JSON value tree, for the universal "open by ID" view.
///
/// Stripe's `/v1` objects are key/value documents; rather than generating a
/// model for every object kind, the generic view decodes the raw response into
/// this tree. Values keep their JSON type so the UI can present them plainly.
public enum StripeJSON: Sendable, Equatable {
    case string(String)
    case number(Double)
    case int(Int)
    case bool(Bool)
    case null
    case array([StripeJSON])
    case object([String: StripeJSON])

    // Typed accessors for the generic object view and tests.
    public var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    public var intValue: Int? {
        if case .int(let value) = self { return value }
        return nil
    }

    public var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }

    /// Subscript for dictionary-style field access on object values;
    /// returns `.null` for non-objects or missing keys (safe default).
    public subscript(key: String) -> StripeJSON {
        if case .object(let fields) = self { return fields[key] ?? .null }
        return .null
    }

    /// Decodes any JSON document into the tree.
    public static func decode(_ data: Data) throws -> StripeJSON {
        let value = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        return make(value)
    }

    private static func make(_ any: Any) -> StripeJSON {
        switch any {
        case is NSNull:
            return .null
        case let number as NSNumber:
            // JSON booleans arrive as CFBoolean-backed NSNumber values;
            // distinguish them from numeric values by their CoreFoundation type.
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return .bool(number.boolValue)
            }
            let type = String(cString: number.objCType)
            if type == "q" || type == "i" || type == "l" || type == "s" {
                return .int(Int(number.int64Value))
            }
            return .number(number.doubleValue)
        case let string as String:
            return .string(string)
        case let array as [Any]:
            return .array(array.map(make))
        case let object as [String: Any]:
            var mapped: [String: StripeJSON] = [:]
            for (key, value) in object { mapped[key] = make(value) }
            return .object(mapped)
        default:
            return .string("\(any)")
        }
    }

    /// A flat, ordered list of top-level (key, rendered-value) pairs for a
    /// simple key/value display. Nested objects and arrays render as counts.
    public func flattened() -> [(key: String, value: String)] {
        guard case .object(let fields) = self else { return [] }
        var pairs: [(String, String)] = []
        for key in fields.keys.sorted() {
            let value = fields[key] ?? .null
            let text: String
            switch value {
            case .string(let stringValue): text = stringValue
            case .int(let intValue): text = "\(intValue)"
            case .number(let doubleValue): text = "\(doubleValue)"
            case .bool(let b): text = b ? "true" : "false"
            case .null: text = "—"
            case .array(let items): text = "[\(items.count)]"
            case .object: text = "{…}"
            }
            pairs.append((key, text))
        }
        return pairs
    }

    /// Extracts a nested string value by dotted key path, e.g. "billing_details.name".
    public func string(atPath path: String) -> String? {
        var current = self
        var components = path.split(separator: ".").map(String.init)
        while !components.isEmpty {
            let key = components.removeFirst()
            guard case .object(let fields) = current, let next = fields[key] else { return nil }
            if components.isEmpty {
                if case .string(let value) = next { return value }
                return nil
            }
            current = next
        }
        return nil
    }
}

/// The Stripe object kinds Geist6 can open by ID, mapped from ID prefix to
/// collection path. Documented prefixes in `docs/stripe/api-inventory.md`.
public enum StripeObjectKind: String, Sendable, CaseIterable, Equatable {
    case account = "account"
    case balanceTransaction = "balance_transaction"
    case charge = "charge"
    case checkoutSession = "checkout_session"
    case coupon = "coupon"
    case customer = "customer"
    case dispute = "dispute"
    case event = "event"
    case invoice = "invoice"
    case paymentIntent = "payment_intent"
    case paymentMethod = "payment_method"
    case payout = "payout"
    case price = "price"
    case product = "product"
    case refund = "refund"
    case setupIntent = "setup_intent"
    case subscription = "subscription"
    case transfer = "transfer"

    /// The kind for a Stripe object ID, or `nil` when the prefix is unknown
    /// (including non-Stripe strings).
    public static func match(_ id: String) -> StripeObjectKind? {
        // Longest prefixes first so `txn_` wins over `tx_`.
        let prefixes: [(String, StripeObjectKind)] = [
            ("acct_", .account),
            ("bal_", .balanceTransaction),
            ("txn_", .balanceTransaction),
            ("tx_", .balanceTransaction),
            ("ch_", .charge),
            ("cs_", .checkoutSession),
            ("co_", .coupon),
            ("cus_", .customer),
            ("dp_", .dispute),
            ("fr_", .dispute),
            ("evt_", .event),
            ("in_", .invoice),
            ("pi_", .paymentIntent),
            ("pm_", .paymentMethod),
            ("po_", .payout),
            ("price_", .price),
            ("prod_", .product),
            ("re_", .refund),
            ("seti_", .setupIntent),
            ("sub_", .subscription),
            ("tr_", .transfer)
        ]
        for (prefix, kind) in prefixes where id.hasPrefix(prefix) {
            return kind
        }
        return nil
    }

    /// The `/v1` collection path for the kind.
    public var collectionPath: String {
        switch self {
        case .account: return "accounts"
        case .balanceTransaction: return "balance_transactions"
        case .charge: return "charges"
        case .checkoutSession: return "checkout/sessions"
        case .coupon: return "coupons"
        case .customer: return "customers"
        case .dispute: return "disputes"
        case .event: return "events"
        case .invoice: return "invoices"
        case .paymentIntent: return "payment_intents"
        case .paymentMethod: return "payment_methods"
        case .payout: return "payouts"
        case .price: return "prices"
        case .product: return "products"
        case .refund: return "refunds"
        case .setupIntent: return "setup_intents"
        case .subscription: return "subscriptions"
        case .transfer: return "transfers"
        }
    }

    /// A human label for UI ("Payment intent", "Balance transaction").
    public var label: String {
        switch self {
        case .account: return "Account"
        case .balanceTransaction: return "Balance transaction"
        case .charge: return "Charge"
        case .checkoutSession: return "Checkout session"
        case .coupon: return "Coupon"
        case .customer: return "Customer"
        case .dispute: return "Dispute"
        case .event: return "Event"
        case .invoice: return "Invoice"
        case .paymentIntent: return "Payment intent"
        case .paymentMethod: return "Payment method"
        case .payout: return "Payout"
        case .price: return "Price"
        case .product: return "Product"
        case .refund: return "Refund"
        case .setupIntent: return "Setup intent"
        case .subscription: return "Subscription"
        case .transfer: return "Transfer"
        }
    }
}

/// Errors from the universal open-by-ID lookup.
public enum ObjectByIDError: Error, Sendable {
    case unknownKind(String)
    case decodeFailed(underlying: Error)
}

/// Opens any Stripe object by ID without a per-kind model.
///
/// The kind comes from the ID prefix; the fetch is a read-only GET of
/// `/v1/<collection>/<id>` via the backend's `rawObject`, decoded into a
/// `StripeJSON` tree for the generic object view.
public struct ObjectByIDService: Sendable {
    public let backend: any StripeDataBackend

    public init(backend: any StripeDataBackend) {
        self.backend = backend
    }

    /// A resolved object ready for display.
    public struct ResolvedObject: Sendable, Equatable {
        public let kind: StripeObjectKind
        public let id: String
        public let json: StripeJSON

        public init(kind: StripeObjectKind, id: String, json: StripeJSON) {
            self.kind = kind
            self.id = id
            self.json = json
        }
    }

    /// Fetches the object named by `id`, or throws `ObjectByIDError`.
    public func fetch(_ id: String) async throws -> ResolvedObject {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let kind = StripeObjectKind.match(trimmed) else {
            throw ObjectByIDError.unknownKind(trimmed)
        }
        let path = "/v1/\(kind.collectionPath)/\(trimmed)"
        let data: Data
        do {
            data = try await backend.rawObject(path: path)
        } catch {
            throw ObjectByIDError.decodeFailed(underlying: error)
        }
        let json: StripeJSON
        do {
            json = try StripeJSON.decode(data)
        } catch {
            throw ObjectByIDError.decodeFailed(underlying: error)
        }
        return ResolvedObject(kind: kind, id: trimmed, json: json)
    }
}
