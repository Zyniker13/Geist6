// BillingWrite.swift — Sources/GeistData
// Billing writes: products, prices, coupons, and promotion codes —
// create, update, and delete.
//
// Three gates stand between a user action and Stripe:
//   1. The UI only builds a writer for accounts that are not dashboard-locked
//      (belt).
//   2. This service refuses to run when the client is in dashboard mode,
//      before anything else happens (suspenders), and records the refusal in
//      the audit log.
//   3. The client itself refuses every non-GET request in dashboard mode
//      before anything reaches the network (floor).
//
// Every request carries an idempotency key — the same key that appears in
// the audit entry, so a retry after an unclear failure repeats exactly one
// request, not two.

import Foundation
import StripeClient
import StripeModels

public enum BillingWriteError: LocalizedError, Equatable {
  /// The service was asked to write while the client is in dashboard mode.
  case dashboardMode

  public var errorDescription: String? {
    switch self {
    case .dashboardMode:
      return "Dashboard mode is read-only. Unlock the account to make changes."
    }
  }
}

public struct BillingWriteService: Sendable {
  /// Reads the account's CURRENT dashboard-lock state. Called before every
  /// write so locking an account mid-session closes it immediately, even if
  /// this writer was built while the account was unlocked.
  public typealias DashboardLockProvider = @MainActor @Sendable () async -> Bool

  public let client: StripeClient
  public let accountID: String
  public let accountName: String
  public let audit: any AuditStore
  private let dashboardLocked: DashboardLockProvider

  public init(
    client: StripeClient, accountID: String, accountName: String, audit: any AuditStore,
    dashboardLocked: @escaping DashboardLockProvider
  ) {
    self.client = client
    self.accountID = accountID
    self.accountName = accountName
    self.audit = audit
    self.dashboardLocked = dashboardLocked
  }

  /// Runs one write: refuses in dashboard mode, performs the request with
  /// an idempotency key, records the outcome, and decodes the response.
  func run<Response: Decodable>(
    _ type: Response.Type,
    method: String,
    path: String,
    params: (some Encodable)?,
    key: String,
    summary: String
  ) async throws -> Response {
    // Gate 2: refuse before anything else — both when the client was built
    // in dashboard mode and when the account is locked right now.
    var locked = client.mode == .dashboard
    if !locked { locked = await dashboardLocked() }
    guard !locked else {
      await audit.record(
        AuditEntry(
          accountID: accountID,
          accountName: accountName,
          summary: summary,
          method: method,
          path: path,
          idempotencyKey: key,
          outcome: "refused: dashboard mode"
        ))
      throw BillingWriteError.dashboardMode
    }
    do {
      let outcome = try await client.perform(
        method: method, path: path, params: params, idempotencyKey: key)
      let decoded: Response
      do {
        decoded = try StripeClient.decoder.decode(Response.self, from: outcome.body)
      } catch {
        throw StripeClientError.decodingFailed(underlying: error, path: path)
      }
      await audit.record(
        AuditEntry(
          accountID: accountID,
          accountName: accountName,
          summary: summary,
          method: method,
          path: path,
          idempotencyKey: key,
          requestID: outcome.requestId,
          outcome: "succeeded"
        ))
      return decoded
    } catch {
      let message: String
      if let apiError = error as? StripeAPIError {
        message = apiError.description
      } else if let local = error as? LocalizedError, let desc = local.errorDescription {
        message = desc
      } else {
        message = String(describing: error)
      }
      await audit.record(
        AuditEntry(
          accountID: accountID,
          accountName: accountName,
          summary: summary,
          method: method,
          path: path,
          idempotencyKey: key,
          outcome: "failed: \(message)"
        ))
      throw error
    }
  }

  static func key() -> String { UUID().uuidString }

  // MARK: - Products

  /// Creates a product. `metadata == nil` leaves metadata untouched; a
  /// non-nil value replaces it wholesale.
  public func createProduct(
    name: String, description: String?, active: Bool?, metadata: [String: String]?,
    summary: String
  ) async throws -> Product {
    var params = ProductCreateParams(name: name)
    params.description = description
    params.active = active
    if let metadata {
      params.metadata = metadata
    }
    return try await run(
      Product.self, method: "POST", path: "/v1/products", params: params,
      key: Self.key(), summary: summary)
  }

  /// The editable fields of a product update. `nil` fields are left
  /// untouched; a non-nil `metadata` replaces it wholesale (an empty
  /// dictionary clears it).
  public struct ProductUpdate: Sendable {
    public let name: String?
    public let description: String?
    public let active: Bool?
    public let metadata: [String: String]?

    public init(name: String?, description: String?, active: Bool?, metadata: [String: String]?) {
      self.name = name
      self.description = description
      self.active = active
      self.metadata = metadata
    }
  }

  /// Updates a product with the fields set in `update`.
  public func updateProduct(
    id: String, update: ProductUpdate, summary: String
  ) async throws -> Product {
    var params = ProductUpdateParams()
    params.name = update.name
    if let description = update.description {
      params.description = .value(description)
    }
    params.active = update.active
    if let metadata = update.metadata {
      params.metadata = .value(metadata)
    }
    return try await run(
      Product.self, method: "POST", path: "/v1/products/\(id)", params: params,
      key: Self.key(), summary: summary)
  }

  /// Deletes a product.
  public func deleteProduct(id: String, summary: String) async throws -> DeletedProduct {
    return try await run(
      DeletedProduct.self, method: "DELETE", path: "/v1/products/\(id)",
      params: ProductDeleteParams(), key: Self.key(), summary: summary)
  }

  // MARK: - Prices

  /// A price to create. A non-nil `recurringInterval` makes it a recurring
  /// price; `nil` makes it one-time. `metadata == nil` leaves metadata
  /// untouched; a non-nil value replaces it wholesale.
  public struct PriceDraft: Sendable {
    public let product: String
    public let currency: String
    public let unitAmount: Int?
    public let nickname: String?
    public let recurringInterval: String?
    public let recurringIntervalCount: Int?
    public let active: Bool?
    public let metadata: [String: String]?

    public init(
      product: String, currency: String, unitAmount: Int?, nickname: String?,
      recurringInterval: String?, recurringIntervalCount: Int?, active: Bool?,
      metadata: [String: String]?
    ) {
      self.product = product
      self.currency = currency
      self.unitAmount = unitAmount
      self.nickname = nickname
      self.recurringInterval = recurringInterval
      self.recurringIntervalCount = recurringIntervalCount
      self.active = active
      self.metadata = metadata
    }
  }

  /// Creates a price from `draft`.
  public func createPrice(draft: PriceDraft, summary: String) async throws -> Price {
    var params = PriceCreateParams(currency: draft.currency)
    params.product = draft.product
    params.unitAmount = draft.unitAmount
    params.nickname = draft.nickname
    if let intervalString = draft.recurringInterval {
      var recurring = PriceCreateParamsRecurring(interval: PlanInterval(rawValue: intervalString))
      recurring.intervalCount = draft.recurringIntervalCount
      params.recurring = recurring
    }
    params.active = draft.active
    if let metadata = draft.metadata {
      params.metadata = metadata
    }
    return try await run(
      Price.self, method: "POST", path: "/v1/prices", params: params,
      key: Self.key(), summary: summary)
  }

  /// Updates a price's nickname, active flag, and metadata. Stripe does not
  /// allow changing a price's amount or currency after creation; a new price
  /// is created instead. `nil` fields are left untouched; a non-nil
  /// `metadata` replaces it wholesale (an empty dictionary clears it).
  public func updatePrice(
    id: String, nickname: String?, active: Bool?, metadata: [String: String]?,
    summary: String
  ) async throws -> Price {
    var params = PriceUpdateParams()
    params.nickname = nickname
    params.active = active
    if let metadata {
      params.metadata = .value(metadata)
    }
    return try await run(
      Price.self, method: "POST", path: "/v1/prices/\(id)", params: params,
      key: Self.key(), summary: summary)
  }

  // MARK: - Coupons

  /// A coupon to create. Stripe requires exactly one of `percentOff` or
  /// `amountOff`; `currency` is required when `amountOff` is set.
  /// `duration` is one of "once", "repeating", "forever".
  /// `metadata == nil` leaves metadata untouched; a non-nil value replaces
  /// it wholesale.
  public struct CouponDraft: Sendable {
    public let name: String?
    public let percentOff: Decimal?
    public let amountOff: Int?
    public let currency: String?
    public let duration: String
    public let durationInMonths: Int?
    public let redeemBy: Date?
    public let maxRedemptions: Int?
    public let metadata: [String: String]?

    public init(
      name: String?, percentOff: Decimal?, amountOff: Int?, currency: String?,
      duration: String, durationInMonths: Int?, redeemBy: Date?,
      maxRedemptions: Int?, metadata: [String: String]?
    ) {
      self.name = name
      self.percentOff = percentOff
      self.amountOff = amountOff
      self.currency = currency
      self.duration = duration
      self.durationInMonths = durationInMonths
      self.redeemBy = redeemBy
      self.maxRedemptions = maxRedemptions
      self.metadata = metadata
    }
  }

  /// Creates a coupon from `draft`.
  public func createCoupon(draft: CouponDraft, summary: String) async throws -> Coupon {
    var params = CouponCreateParams()
    params.name = draft.name
    params.percentOff = draft.percentOff
    params.amountOff = draft.amountOff
    params.currency = draft.currency
    params.duration = CouponDuration(rawValue: draft.duration)
    params.durationInMonths = draft.durationInMonths
    if let redeemBy = draft.redeemBy {
      params.redeemBy = StripeTimestamp(redeemBy)
    }
    params.maxRedemptions = draft.maxRedemptions
    if let metadata = draft.metadata {
      params.metadata = .value(metadata)
    }
    return try await run(
      Coupon.self, method: "POST", path: "/v1/coupons", params: params,
      key: Self.key(), summary: summary)
  }

  /// The editable fields of a coupon update. `nil` fields are left
  /// untouched; a non-nil `metadata` replaces it wholesale (an empty
  /// dictionary clears it).
  public struct CouponUpdate: Sendable {
    public let name: String?
    public let metadata: [String: String]?

    public init(name: String?, metadata: [String: String]?) {
      self.name = name
      self.metadata = metadata
    }
  }

  /// Updates a coupon with the fields set in `update`.
  public func updateCoupon(
    id: String, update: CouponUpdate, summary: String
  ) async throws -> Coupon {
    var params = CouponUpdateParams()
    params.name = update.name
    if let metadata = update.metadata {
      params.metadata = .value(metadata)
    }
    return try await run(
      Coupon.self, method: "POST", path: "/v1/coupons/\(id)", params: params,
      key: Self.key(), summary: summary)
  }

  /// Deletes a coupon.
  public func deleteCoupon(id: String, summary: String) async throws -> DeletedCoupon {
    return try await run(
      DeletedCoupon.self, method: "DELETE", path: "/v1/coupons/\(id)",
      params: CouponDeleteParams(), key: Self.key(), summary: summary)
  }

  // MARK: - Promotion codes

  /// A promotion code to create. `code` is the redemption string; when nil,
  /// Stripe generates one. `metadata == nil` leaves metadata untouched; a
  /// non-nil value replaces it wholesale.
  public struct PromotionCodeDraft: Sendable {
    public let coupon: String
    public let code: String?
    public let active: Bool?
    public let expiresAt: Date?
    public let maxRedemptions: Int?
    public let customer: String?
    public let metadata: [String: String]?

    public init(
      coupon: String, code: String?, active: Bool?, expiresAt: Date?,
      maxRedemptions: Int?, customer: String?, metadata: [String: String]?
    ) {
      self.coupon = coupon
      self.code = code
      self.active = active
      self.expiresAt = expiresAt
      self.maxRedemptions = maxRedemptions
      self.customer = customer
      self.metadata = metadata
    }
  }

  /// Creates a promotion code from `draft`.
  public func createPromotionCode(
    draft: PromotionCodeDraft, summary: String
  ) async throws -> PromotionCode {
    var params = PromotionCodeCreateParams(
      promotion: .init(coupon: draft.coupon, type: .coupon))
    params.code = draft.code
    params.active = draft.active
    if let expiresAt = draft.expiresAt {
      params.expiresAt = StripeTimestamp(expiresAt)
    }
    params.maxRedemptions = draft.maxRedemptions
    params.customer = draft.customer
    if let metadata = draft.metadata {
      params.metadata = metadata
    }
    return try await run(
      PromotionCode.self, method: "POST", path: "/v1/promotion_codes",
      params: params, key: Self.key(), summary: summary)
  }

  /// Updates a promotion code's active flag and metadata. `nil` fields are
  /// left untouched; a non-nil `metadata` replaces it wholesale (an empty
  /// dictionary clears it).
  public func updatePromotionCode(
    id: String, active: Bool?, metadata: [String: String]?, summary: String
  ) async throws -> PromotionCode {
    var params = PromotionCodeUpdateParams()
    params.active = active
    if let metadata {
      params.metadata = .value(metadata)
    }
    return try await run(
      PromotionCode.self, method: "POST", path: "/v1/promotion_codes/\(id)",
      params: params, key: Self.key(), summary: summary)
  }
}
