// SubscriptionWrite.swift — GeistData
// The M6 subscription write verbs on BillingWriteService: create, edit,
// cancel, pause/resume, migrate, discount removal, and item add. Every
// request goes through `run`, which refuses writes in dashboard mode,
// attaches an idempotency key, and records the attempt in the audit log.
//
// The hand-written draft structs mirror the pinned spec's request bodies;
// the generated `*Params` types are the source of truth for field names and
// types, so each verb maps a draft onto the matching generated params.

import Foundation
import StripeClient
import StripeModels

extension BillingWriteService {
  /// A line to create on a subscription: an existing price plus quantity, or
  /// ad-hoc price data (currency + product + recurring interval).
  public struct SubscriptionItemDraft: Sendable {
    public let price: String?
    public let quantity: Int?
    public let currency: String?
    public let product: String?
    public let unitAmount: Int?
    public let interval: PlanInterval?

    public init(
      price: String?, quantity: Int?, currency: String?, product: String?,
      unitAmount: Int?, interval: PlanInterval?
    ) {
      self.price = price
      self.quantity = quantity
      self.currency = currency
      self.product = product
      self.unitAmount = unitAmount
      self.interval = interval
    }
  }

  /// The input for creating a subscription.
  public struct SubscriptionDraft: Sendable {
    public let customer: String
    public let items: [SubscriptionItemDraft]
    public let description: String?
    public let metadata: [String: String]?
    public let cancelAtPeriodEnd: Bool?
    public let collectionMethod: InvoiceCollectionMethod?
    public let daysUntilDue: Int?
    public let trialPeriodDays: Int?
    public let prorationBehavior: PortalSubscriptionCancelProrationBehavior?

    public init(
      customer: String, items: [SubscriptionItemDraft], description: String?,
      metadata: [String: String]?, cancelAtPeriodEnd: Bool?,
      collectionMethod: InvoiceCollectionMethod?, daysUntilDue: Int?,
      trialPeriodDays: Int?, prorationBehavior: PortalSubscriptionCancelProrationBehavior?
    ) {
      self.customer = customer
      self.items = items
      self.description = description
      self.metadata = metadata
      self.cancelAtPeriodEnd = cancelAtPeriodEnd
      self.collectionMethod = collectionMethod
      self.daysUntilDue = daysUntilDue
      self.trialPeriodDays = trialPeriodDays
      self.prorationBehavior = prorationBehavior
    }
  }

  /// The input for editing a subscription; `nil` fields are left untouched.
  public struct SubscriptionUpdate: Sendable {
    public let description: String?
    public let metadata: [String: String]?
    public let cancelAtPeriodEnd: Bool?
    public let collectionMethod: InvoiceCollectionMethod?
    public let daysUntilDue: Int?
    public let pauseCollection: SubscriptionUpdatePauseCollection?
    public let prorationBehavior: PortalSubscriptionCancelProrationBehavior?
    public let prorationDate: StripeTimestamp?
    public let cancellationDetails: SubscriptionCancellationDetails?

    public init(
      description: String?, metadata: [String: String]?, cancelAtPeriodEnd: Bool?,
      collectionMethod: InvoiceCollectionMethod?, daysUntilDue: Int?,
      pauseCollection: SubscriptionUpdatePauseCollection?,
      prorationBehavior: PortalSubscriptionCancelProrationBehavior?,
      prorationDate: StripeTimestamp?, cancellationDetails: SubscriptionCancellationDetails?
    ) {
      self.description = description
      self.metadata = metadata
      self.cancelAtPeriodEnd = cancelAtPeriodEnd
      self.collectionMethod = collectionMethod
      self.daysUntilDue = daysUntilDue
      self.pauseCollection = pauseCollection
      self.prorationBehavior = prorationBehavior
      self.prorationDate = prorationDate
      self.cancellationDetails = cancellationDetails
    }
  }

  /// A paused-collection setting: `behavior` plus an optional `resumesAt`.
  public struct SubscriptionUpdatePauseCollection: Sendable {
    public let behavior: SubscriptionsResourcePauseCollectionBehavior
    public let resumesAt: StripeTimestamp?

    public init(behavior: SubscriptionsResourcePauseCollectionBehavior, resumesAt: StripeTimestamp?) {
      self.behavior = behavior
      self.resumesAt = resumesAt
    }
  }

  /// Cancellation feedback, shared by the cancel and update verbs.
  public struct SubscriptionCancellationDetails: Sendable {
    public let comment: String?
    public let feedback: SubscriptionCancelParamsCancellationDetailsFeedback?
    public let feedbackOption: String?

    public init(
      comment: String?,
      feedback: SubscriptionCancelParamsCancellationDetailsFeedback?,
      feedbackOption: String?
    ) {
      self.comment = comment
      self.feedback = feedback
      self.feedbackOption = feedbackOption
    }
  }

  /// The input for cancelling a subscription.
  public struct SubscriptionCancel: Sendable {
    public let cancellationDetails: SubscriptionCancellationDetails?
    public let invoiceNow: Bool?
    public let prorate: Bool?

    public init(
      cancellationDetails: SubscriptionCancellationDetails?, invoiceNow: Bool?,
      prorate: Bool?
    ) {
      self.cancellationDetails = cancellationDetails
      self.invoiceNow = invoiceNow
      self.prorate = prorate
    }
  }

  /// The input for pausing a subscription.
  public struct SubscriptionPause: Sendable {
    public let billForOutstandingUsageThrough:
      InvoiceCreatePreviewParamsSubscriptionDetailsPauseBillForOutstandingUsageThroughType?
    public let invoicingBehavior:
      SubscriptionSchedulesResourcePauseSchedulePauseSettingsInvoicingBehavior?
    public let type: SubscriptionObject?

    public init(
      billForOutstandingUsageThrough:
        InvoiceCreatePreviewParamsSubscriptionDetailsPauseBillForOutstandingUsageThroughType?,
      invoicingBehavior:
        SubscriptionSchedulesResourcePauseSchedulePauseSettingsInvoicingBehavior?,
      type: SubscriptionObject?
    ) {
      self.billForOutstandingUsageThrough = billForOutstandingUsageThrough
      self.invoicingBehavior = invoicingBehavior
      self.type = type
    }
  }

  /// The input for resuming a paused subscription; `nil` fields are left
  /// untouched.
  public struct SubscriptionResume: Sendable {
    public let billingCycleAnchor: PortalSubscriptionUpdateBillingCycleAnchor?
    public let paymentBehavior:
      SubscriptionSchedulesResourcePauseScheduleResumeSettingsPaymentBehavior?
    public let prorationBehavior: PortalSubscriptionCancelProrationBehavior?
    public let prorationDate: StripeTimestamp?

    public init(
      billingCycleAnchor: PortalSubscriptionUpdateBillingCycleAnchor?,
      paymentBehavior:
        SubscriptionSchedulesResourcePauseScheduleResumeSettingsPaymentBehavior?,
      prorationBehavior: PortalSubscriptionCancelProrationBehavior?,
      prorationDate: StripeTimestamp?
    ) {
      self.billingCycleAnchor = billingCycleAnchor
      self.paymentBehavior = paymentBehavior
      self.prorationBehavior = prorationBehavior
      self.prorationDate = prorationDate
    }
  }

  /// The input for migrating a subscription between billing modes.
  public struct SubscriptionMigrate: Sendable {
    public let type: SubscriptionMigrateParamsBillingModeType
    public let prorationDiscounts: SubscriptionsResourceBillingModeFlexibleProrationDiscounts?

    public init(
      type: SubscriptionMigrateParamsBillingModeType,
      prorationDiscounts: SubscriptionsResourceBillingModeFlexibleProrationDiscounts?
    ) {
      self.type = type
      self.prorationDiscounts = prorationDiscounts
    }
  }

  // MARK: - Create

  /// Creates a subscription. `metadata == nil` leaves metadata unset; a
  /// non-nil value is sent wholesale.
  public func createSubscription(draft: SubscriptionDraft, summary: String) async throws
    -> Subscription
  {
    var params = SubscriptionCreateParams()
    params.customer = draft.customer
    if let metadata = draft.metadata { params.metadata = .value(metadata) }
    params.description = draft.description
    params.cancelAtPeriodEnd = draft.cancelAtPeriodEnd
    params.collectionMethod = draft.collectionMethod
    params.daysUntilDue = draft.daysUntilDue
    params.trialPeriodDays = draft.trialPeriodDays
    params.prorationBehavior = draft.prorationBehavior
    params.items = draft.items.map { item in
      var element = SubscriptionCreateParamsItemsItem()
      if let price = item.price { element.price = price }
      element.quantity = item.quantity
      if let currency = item.currency {
        element.priceData = SubscriptionCreateParamsItemsItemPriceData(
          currency: currency,
          product: item.product ?? "",
          recurring: SubscriptionCreateParamsItemsItemPriceDataRecurring(
            interval: item.interval ?? .month),
          unitAmount: item.unitAmount
        )
      }
      return element
    }
    return try await run(
      Subscription.self, method: "POST", path: "/v1/subscriptions", params: params,
      key: Self.key(), summary: summary)
  }

  // MARK: - Edit

  /// Edits a subscription; `nil` fields are left untouched. `metadata == nil`
  /// leaves metadata unset, a non-nil value is sent wholesale.
  public func updateSubscription(id: String, update: SubscriptionUpdate, summary: String)
    async throws -> Subscription
  {
    var params = SubscriptionUpdateParams()
    if let description = update.description {
      params.description = .value(description)
    }
    if let metadata = update.metadata { params.metadata = .value(metadata) }
    params.cancelAtPeriodEnd = update.cancelAtPeriodEnd
    params.collectionMethod = update.collectionMethod
    params.daysUntilDue = update.daysUntilDue
    if let pause = update.pauseCollection {
      params.pauseCollection = .value(
        SubscriptionUpdateParamsPauseCollection(
          behavior: pause.behavior, resumesAt: pause.resumesAt))
    }
    params.prorationBehavior = update.prorationBehavior
    params.prorationDate = update.prorationDate
    if let details = update.cancellationDetails {
      params.cancellationDetails = SubscriptionUpdateParamsCancellationDetails(
        comment: details.comment.map(Clearable.value),
        feedback: details.feedback,
        feedbackOption: details.feedbackOption)
    }
    return try await run(
      Subscription.self, method: "POST", path: "/v1/subscriptions/\(id)", params: params,
      key: Self.key(), summary: summary)
  }

  // MARK: - Lifecycle

  /// Cancels a subscription.
  public func cancelSubscription(id: String, cancel: SubscriptionCancel, summary: String)
    async throws -> Subscription
  {
    var params = SubscriptionCancelParams()
    if let details = cancel.cancellationDetails {
      params.cancellationDetails = SubscriptionCancelParamsCancellationDetails(
        comment: details.comment.map(Clearable.value),
        feedback: details.feedback,
        feedbackOption: details.feedbackOption)
    }
    params.invoiceNow = cancel.invoiceNow
    params.prorate = cancel.prorate
    return try await run(
      Subscription.self, method: "DELETE", path: "/v1/subscriptions/\(id)", params: params,
      key: Self.key(), summary: summary)
  }

  /// Pauses a subscription.
  public func pauseSubscription(id: String, pause: SubscriptionPause, summary: String)
    async throws -> Subscription
  {
    var params = SubscriptionPauseParams()
    if let through = pause.billForOutstandingUsageThrough {
      params.billFor = SubscriptionPauseParamsBillFor(
        outstandingUsageThrough: SubscriptionPauseParamsBillForOutstandingUsageThrough(
          type: through))
    }
    params.invoicingBehavior = pause.invoicingBehavior
    params.type = pause.type
    return try await run(
      Subscription.self, method: "POST", path: "/v1/subscriptions/\(id)/pause", params: params,
      key: Self.key(), summary: summary)
  }

  /// Resumes a paused subscription.
  public func resumeSubscription(id: String, resume: SubscriptionResume, summary: String)
    async throws -> Subscription
  {
    var params = SubscriptionResumeParams()
    if let anchor = resume.billingCycleAnchor {
      params.billingCycleAnchor = SubscriptionResumeParamsBillingCycleAnchor(type: anchor)
    }
    params.paymentBehavior = resume.paymentBehavior
    params.prorationBehavior = resume.prorationBehavior
    params.prorationDate = resume.prorationDate
    return try await run(
      Subscription.self, method: "POST", path: "/v1/subscriptions/\(id)/resume", params: params,
      key: Self.key(), summary: summary)
  }

  /// Moves a subscription between billing modes.
  public func migrateSubscription(id: String, migrate: SubscriptionMigrate, summary: String)
    async throws -> Subscription
  {
    var params = SubscriptionMigrateParams(
      billingMode: SubscriptionMigrateParamsBillingMode(
        flexible: migrate.prorationDiscounts.map {
          SubscriptionMigrateParamsBillingModeFlexible(prorationDiscounts: $0)
        },
        type: migrate.type))
    return try await run(
      Subscription.self, method: "POST", path: "/v1/subscriptions/\(id)/migrate", params: params,
      key: Self.key(), summary: summary)
  }

  /// Removes any discount from a subscription.
  public func deleteDiscountSubscription(id: String, summary: String) async throws
    -> DeletedDiscount
  {
    return try await run(
      DeletedDiscount.self, method: "DELETE", path: "/v1/subscriptions/\(id)/discount",
      params: nil as EmptyParams?, key: Self.key(), summary: summary)
  }

  // MARK: - Items

  /// Adds a line to a subscription, prorating by default.
  public func addSubscriptionItem(id: String, item: SubscriptionItemDraft, summary: String)
    async throws -> SubscriptionItem
  {
    var params = SubscriptionItemCreateParams(subscription: id)
    if let price = item.price { params.price = price }
    params.quantity = item.quantity
    if let currency = item.currency {
      params.priceData = SubscriptionItemCreateParamsPriceData(
        currency: currency,
        product: item.product ?? "",
        recurring: SubscriptionItemCreateParamsPriceDataRecurring(
          interval: item.interval ?? .month),
        unitAmount: item.unitAmount
      )
    }
    params.prorationBehavior = .alwaysInvoice
    return try await run(
      SubscriptionItem.self, method: "POST", path: "/v1/subscription_items", params: params,
      key: Self.key(), summary: summary)
  }
}
