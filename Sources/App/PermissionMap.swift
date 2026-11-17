import Foundation

/// Maps API keys to the permissions they have, based on the two
/// recommended permission sets (Dashboard / Management) from the
/// Stripe documentation.
///
/// The map is a compile-time constant: each resource is listed with
/// the permission name and whether it is read or write. At runtime
/// the app can probe a key against a sample endpoint to learn the
/// actual permissions, but the default map follows the recommended
/// sets exactly.
public struct PermissionMap: Sendable {

  /// A single permission entry for one resource.
  public struct Entry: Sendable {
    public let resource: String
    public let permission: String
    public let isWrite: Bool
    public let category: PermissionCategory

    public var label: String { resource }
    public var description: String {
      isWrite ? "\(resource) — read and write" : "\(resource) — read only"
    }
  }

  /// Permission categories used by the Dashboard picker.
  public enum PermissionCategory: String, Sendable {
    case core
    case payments
    case billing
    case products
    case payouts
    case transfers
    case reports
    case connect
    case issuing
    case terminal
    case treasury
    case identity
    case radar
    case financialConnections
    case tax
    case climate
    case sigma
    case webhooks
    case balance
    case files
    case other
  }

  /// The full permission map.
  public var entries: [Entry]

  /// Returns the permission for a given resource.
  public func permission(for resource: String) -> String? {
    entries.first { $0.resource.lowercased() == resource.lowercased() }?.permission
  }

  /// Returns true if the resource is read-only in this map.
  public func isReadOnly(resource: String) -> Bool {
    entries.first { $0.resource.lowercased() == resource.lowercased() }?.isWrite == false
  }

  /// Returns true if the resource is writable in this map.
  public func isWritable(resource: String) -> Bool {
    entries.first { $0.resource.lowercased() == resource.lowercased() }?.isWrite == true
  }

  /// Returns entries in the given category.
  public func entries(in category: PermissionCategory) -> [Entry] {
    entries.filter { $0.category == category }
  }

  /// Returns all categories present in this map.
  public var categories: [PermissionCategory] {
    Array(Set(entries.map { $0.category })).sorted { $0.rawValue < $1.rawValue }
  }

  /// Returns a description of what the key can do.
  public func description() -> String {
    let reads = entries.filter { !$0.isWrite }.map(\.resource)
    let writes = entries.filter { $0.isWrite }.map(\.resource)
    var parts: [String] = []
    if !reads.isEmpty {
      parts.append("read: \(reads.count) resources")
    }
    if !writes.isEmpty {
      parts.append("write: \(writes.count) resources")
    }
    return parts.joined(separator: ", ")
  }

  // MARK: - Dashboard set (read-only)

  public static let dashboard: PermissionMap = {
    var entries: [Entry] = []

    // Core
    entries.append(Entry(resource: "Accounts", permission: "connected_account_read", isWrite: false, category: .connect))
    entries.append(Entry(resource: "Balance", permission: "balance_read", isWrite: false, category: .balance))
    entries.append(Entry(resource: "Events", permission: "event_read", isWrite: false, category: .other))
    entries.append(Entry(resource: "Files", permission: "file_read", isWrite: false, category: .files))

    // Payments
    entries.append(Entry(resource: "Charges", permission: "charge_read", isWrite: false, category: .payments))
    entries.append(Entry(resource: "PaymentIntents", permission: "payment_intent_read", isWrite: false, category: .payments))
    entries.append(Entry(resource: "SetupIntents", permission: "setup_intent_read", isWrite: false, category: .payments))
    entries.append(Entry(resource: "PaymentMethods", permission: "payment_method_read", isWrite: false, category: .payments))
    entries.append(Entry(resource: "Customers", permission: "customer_read", isWrite: false, category: .payments))
    entries.append(Entry(resource: "Disputes", permission: "dispute_read", isWrite: false, category: .payments))
    entries.append(Entry(resource: "Mandates", permission: "mandate_read", isWrite: false, category: .payments))
    entries.append(Entry(resource: "ReviewApprovals", permission: "review_read", isWrite: false, category: .radar))

    // Billing
    entries.append(Entry(resource: "Invoices", permission: "invoice_read", isWrite: false, category: .billing))
    entries.append(Entry(resource: "SubscriptionItems", permission: "subscription_read", isWrite: false, category: .billing))
    entries.append(Entry(resource: "Subscriptions", permission: "subscription_read", isWrite: false, category: .billing))
    entries.append(Entry(resource: "Coupons", permission: "promotion_code_read", isWrite: false, category: .billing))
    entries.append(Entry(resource: "PromotionCodes", permission: "promotion_code_read", isWrite: false, category: .billing))
    entries.append(Entry(resource: "CreditNotes", permission: "credit_note_read", isWrite: false, category: .billing))
    entries.append(Entry(resource: "CheckoutSessions", permission: "checkout_session_read", isWrite: false, category: .billing))
    entries.append(Entry(resource: "PaymentLinks", permission: "payment_links_read", isWrite: false, category: .billing))
    entries.append(Entry(resource: "BillingMeters", permission: "billing_meter_read", isWrite: false, category: .billing))
    entries.append(Entry(resource: "BillingMeterEvents", permission: "billing_meter_event_read", isWrite: false, category: .billing))

    // Products
    entries.append(Entry(resource: "Products", permission: "product_read", isWrite: false, category: .products))
    entries.append(Entry(resource: "Prices", permission: "plan_read", isWrite: false, category: .products))
    entries.append(Entry(resource: "ShippingRates", permission: "shipping_rate_read", isWrite: false, category: .products))

    // Payouts & Transfers
    entries.append(Entry(resource: "TopUps", permission: "top_up_read", isWrite: false, category: .payouts))
    entries.append(Entry(resource: "Transfers", permission: "transfer_read", isWrite: false, category: .transfers))
    entries.append(Entry(resource: "ApplicationFees", permission: "application_fee_read", isWrite: false, category: .payouts))

    // Reports
    entries.append(Entry(resource: "ReportRuns", permission: "report_runs_and_report_types_read", isWrite: false, category: .reports))
    entries.append(Entry(resource: "ReportTypes", permission: "report_runs_and_report_types_read", isWrite: false, category: .reports))

    // Other
    entries.append(Entry(resource: "ApplePayDomains", permission: "apple_pay_domain_read", isWrite: false, category: .other))
    entries.append(Entry(resource: "PaymentMethodDomains", permission: "payment_method_domain_read", isWrite: false, category: .other))
    entries.append(Entry(resource: "PaymentMethodConfigurations", permission: "payment_method_configurations_read", isWrite: false, category: .other))
    entries.append(Entry(resource: "TestClocks", permission: "billing_clock_read", isWrite: false, category: .other))
    entries.append(Entry(resource: "TaxRates", permission: "tax_rate_read", isWrite: false, category: .tax))
    entries.append(Entry(resource: "Entitlements", permission: "entitlement_read", isWrite: false, category: .other))
    entries.append(Entry(resource: "CustomerSessions", permission: "customer_session_read", isWrite: false, category: .other))
    entries.append(Entry(resource: "ConfirmationTokens", permission: "confirmation_token_read", isWrite: false, category: .other))
    entries.append(Entry(resource: "RadarReviews", permission: "review_read", isWrite: false, category: .radar))
    entries.append(Entry(resource: "BalanceTransactionSources", permission: "balance_transaction_source_read", isWrite: false, category: .balance))

    return PermissionMap(entries: entries)
  }()

  // MARK: - Management set (read + write)

  public static let management: PermissionMap = {
    var entries = dashboard.entries

    // Add write permissions
    let writes: [(String, String)] = [
      ("Charges", "charge_write"),
      ("PaymentIntents", "payment_intent_write"),
      ("SetupIntents", "setup_intent_write"),
      ("PaymentMethods", "payment_method_write"),
      ("Customers", "customer_write"),
      ("Invoices", "invoice_write"),
      ("Subscriptions", "subscription_write"),
      ("Products", "product_write"),
      ("Prices", "plan_write"),
      ("Quotes", "quote_write"),
      ("PromotionCodes", "promotion_code_write"),
      ("Coupons", "coupon_write"),
      ("CreditNotes", "credit_note_write"),
      ("TopUps", "top_up_write"),
      ("Transfers", "transfer_write"),
      ("Payouts", "payout_write"),
      ("Disputes", "dispute_write"),
      ("RadarReviews", "review_write"),
      ("CustomerPortal", "customer_portal_write"),
      ("TaxRates", "tax_rate_write"),
      ("TestClocks", "billing_clock_write"),
      ("BillingMeters", "billing_meter_write"),
      ("BillingMeterEvents", "billing_meter_event_write"),
      ("Files", "file_write"),
      ("Mandates", "mandate_write"),
    ]

    // Remove read-only entries for resources that have write permissions
    for (resource, _) in writes {
      entries.removeAll { $0.resource == resource }
    }

    // Add write entries with correct categories
    for (resource, permission) in writes {
      let category: PermissionCategory = {
        switch resource {
        case "Charges", "PaymentIntents", "SetupIntents", "PaymentMethods", "Customers", "Mandates":
          return .payments
        case "Invoices", "Subscriptions", "Coupons", "PromotionCodes", "CreditNotes", "TestClocks",
             "BillingMeters", "BillingMeterEvents":
          return .billing
        case "Products", "Prices":
          return .products
        case "TopUps":
          return .payouts
        case "Transfers":
          return .transfers
        case "Payouts":
          return .payouts
        case "Disputes":
          return .payments
        case "RadarReviews":
          return .radar
        case "CustomerPortal":
          return .billing
        case "TaxRates":
          return .tax
        case "Files":
          return .files
        case "Quotes":
          return .billing
        default:
          return .other
        }
      }()
      entries.append(Entry(resource: resource, permission: permission, isWrite: true, category: category))
    }

    return PermissionMap(entries: entries)
  }()
}
