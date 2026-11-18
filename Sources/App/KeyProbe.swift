import Foundation
import StripeClient
import StripeModels
import StripeSpec

/// Probes a Stripe API key against a sample endpoint for each resource
/// in the permission map to learn the actual permissions at runtime.
///
/// Each probe fires a `GET /v1/<resource>?limit=1` (or `/v2` equivalent)
/// and records whether the call succeeds (allowed) or returns a 403/401
/// (denied). The result is a `PermissionProbe` per resource.
public struct KeyProbe: Sendable {

  /// Result of probing one resource.
  public struct Result: Sendable {
    public let resource: String
    public let allowed: Bool
    public let permission: String?

    public init(resource: String, allowed: Bool, permission: String?) {
      self.resource = resource
      self.allowed = allowed
      self.permission = permission
    }
  }

  /// The full list of probe results.
  public let results: [Result]

  /// Returns results for the given category.
  public func results(in category: PermissionMap.PermissionCategory) -> [Result] {
    results.filter { $0.resource == category.rawValue.capitalized }
  }

  /// Returns the count of allowed resources.
  public var allowedCount: Int {
    results.filter(\.allowed).count
  }

  /// Returns the count of denied resources.
  public var deniedCount: Int {
    results.filter { !$0.allowed }.count
  }

  /// Probes the given key against all resources in the permission map.
  ///
  /// Uses the provided client to fire GET requests against sample endpoints.
  /// A 200 response means the resource is allowed; 403/401 means denied.
  /// Other errors (404, 500, transport) are treated as denied.
  public static func probe(
    client: StripeClient,
    permissionMap: PermissionMap
  ) async -> KeyProbe {
    var results: [Result] = []

    for entry in permissionMap.entries {
      let allowed = await probeResource(client: client, entry: entry)
      results.append(Result(resource: entry.resource, allowed: allowed, permission: entry.permission))
    }

    return KeyProbe(results: results)
  }

  /// Sample GET endpoints used to probe each resource.
  ///
  /// A resource missing from this map falls back to the charges list,
  /// which every restricted key either can or cannot list — matching the
  /// permission map's granularity.
  private static let samplePaths: [String: String] = [
    "Accounts": "/v1/account",
    "Balance": "/v1/balance",
    "Events": "/v1/events?limit=1",
    "Files": "/v1/files?limit=1",
    "Charges": "/v1/charges?limit=1",
    "PaymentIntents": "/v1/payment_intents?limit=1",
    "SetupIntents": "/v1/setup_intents?limit=1",
    "PaymentMethods": "/v1/payment_methods?limit=1",
    "Customers": "/v1/customers?limit=1",
    "Disputes": "/v1/disputes?limit=1",
    "Mandates": "/v1/mandates?limit=1",
    "ReviewApprovals": "/v1/review/approved?limit=1",
    "RadarReviews": "/v1/review/open?limit=1",
    "Invoices": "/v1/invoices?limit=1",
    "SubscriptionItems": "/v1/subscription_items?limit=1",
    "Subscriptions": "/v1/subscriptions?limit=1",
    "Coupons": "/v1/coupons?limit=1",
    "PromotionCodes": "/v1/promotion_codes?limit=1",
    "CreditNotes": "/v1/credit_notes?limit=1",
    "CheckoutSessions": "/v1/checkout/sessions?limit=1",
    "PaymentLinks": "/v1/payment_links?limit=1",
    "BillingMeters": "/v1/billing/meters?limit=1",
    "BillingMeterEvents": "/v1/billing/meter_event_summaries?limit=1",
    "Products": "/v1/products?limit=1",
    "Prices": "/v1/prices?limit=1",
    "ShippingRates": "/v1/shipping_rates?limit=1",
    "TopUps": "/v1/topups?limit=1",
    "Transfers": "/v1/transfers?limit=1",
    "ApplicationFees": "/v1/application_fees?limit=1",
    "ReportRuns": "/v1/report_types/ledger_monthly/run",
    "ReportTypes": "/v1/report_types",
    "ApplePayDomains": "/v1/apple_pay/domains?limit=1",
    "PaymentMethodDomains": "/v1/payment_method_domains?limit=1",
    "PaymentMethodConfigurations": "/v1/payment_method_configurations?limit=1",
    "TestClocks": "/v1/test_helpers/test_clocks?limit=1",
    "TaxRates": "/v1/tax/rates?limit=1",
    "Entitlements": "/v1/entitlements/active_entitlements?limit=1",
    "CustomerSessions": "/v1/customer_sessions?limit=1",
    "ConfirmationTokens": "/v1/confirmation_tokens?limit=1",
    "BalanceTransactionSources": "/v1/balance_transactions?limit=1",
    "Payouts": "/v1/payouts?limit=1",
    "Quotes": "/v1/quotes?limit=1",
    "CustomerPortal": "/v1/customer_portal/portal_sessions?limit=1",
  ]

  /// Probes a single resource by firing a GET request against its sample endpoint.
  private static func probeResource(
    client: StripeClient,
    entry: PermissionMap.Entry
  ) async -> Bool {
    let path = samplePaths[entry.resource] ?? "/v1/charges?limit=1"

    do {
      let _: Account = try await client.request(method: "GET", path: path)
      return true
    } catch {
      // 401/403 mean the key lacks the permission; 404, 5xx and transport
      // errors are treated as denied too — the feature is unusable either way.
      return false
    }
  }
}
