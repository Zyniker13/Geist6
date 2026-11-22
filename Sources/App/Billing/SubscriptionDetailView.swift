import GeistData
import StripeModels
import SwiftUI

/// Detail view for a single subscription: status, items, dates, pause state,
/// and discounts. Active subscriptions can be edited, paused, migrated, or
/// set to cancel at period end; paused ones can be resumed; any live one can
/// be cancelled outright or have its discount removed. Every action requires
/// a writer, so dashboard-locked accounts get a read-only screen.
struct SubscriptionDetailView: View {
  let subscriptionID: String
  let backend: any BillingBackend
  /// Nil for dashboard-locked accounts: no write UI exists at all.
  let writer: BillingWriteService?

  @State private var subscription: Subscription?
  @State private var loadingError: String?
  @State private var activeSheet: SubscriptionSheet?
  @State private var pendingAction: SubscriptionLifecycleAction?
  @State private var writeResult: WriteResult?

  var body: some View {
    Group {
      if let subscription {
        subscriptionView(subscription)
      } else if let error = loadingError {
        ContentUnavailableView(
          "Couldn't load subscription",
          systemImage: "exclamationmark.triangle",
          description: Text(error)
        )
      } else {
        ProgressView()
      }
    }
    .navigationTitle("Subscription")
    .task { await loadSubscription() }
    .toolbar { actionsToolbar }
    .sheet(item: $activeSheet) { sheet in
      sheetView(sheet)
    }
    .confirmationDialog(
      "Confirm", isPresented: Binding(
        get: { pendingAction != nil },
        set: { if !$0 { pendingAction = nil } }
      ), titleVisibility: .visible, presenting: pendingAction
    ) { action in
      Button(action.buttonTitle, role: action.isDestructive ? .destructive : nil) {
        Task { await runLifecycle(action) }
      }
      .accessibilityIdentifier("billing.subscription.\(action.rawValue)Run")
      Button("Cancel", role: .cancel) {}
    } message: { action in
      Text(action.message)
    }
    .writeResultAlert($writeResult)
  }

  // MARK: - Loading

  private func loadSubscription() async {
    do {
      subscription = try await backend.retrieveSubscription(id: subscriptionID)
      loadingError = nil
    } catch {
      loadingError = writeErrorMessage(error)
    }
  }

  private func handleWriteFinished(_ result: WriteResult) {
    activeSheet = nil
    writeResult = result
    Task { await loadSubscription() }
  }

  // MARK: - Actions menu

  @ToolbarContentBuilder
  private var actionsToolbar: some ToolbarContent {
    ToolbarItem(placement: .primaryAction) {
      if let subscription, writer != nil, hasActions(subscription) {
        Menu {
          // `pause_collection` set means the subscription is paused for
          // collection (Stripe docs), regardless of the `status` value the
          // API reports alongside it — offer Resume instead of Pause.
          if subscription.pauseCollection.valueOrNil != nil {
            Button("Resume…") { pendingAction = .resume }
              .accessibilityIdentifier("billing.subscription.resume")
          } else {
            Button("Pause…") { activeSheet = .pause }
              .accessibilityIdentifier("billing.subscription.pause")
          }
          Button("Edit details…") { activeSheet = .edit }
            .accessibilityIdentifier("billing.subscription.edit")
          Button("Add item…") { activeSheet = .addItem }
            .accessibilityIdentifier("billing.subscription.addItem")
          if subscription.billingMode.type == .classic {
            Button("Migrate to flexible billing…") { pendingAction = .migrate }
              .accessibilityIdentifier("billing.subscription.migrate")
          }
          Divider()
          if subscription.cancelAtPeriodEnd {
            Button("Don't cancel at period end") {
              pendingAction = .keep
            }
            .accessibilityIdentifier("billing.subscription.keep")
          } else {
            Button("Cancel at period end…") {
              pendingAction = .cancelAtPeriodEnd
            }
            .accessibilityIdentifier("billing.subscription.cancelAtPeriodEnd")
          }
          if !subscription.discounts.isEmpty {
            Divider()
            Button("Remove discount…", role: .destructive) {
              pendingAction = .deleteDiscount
            }
            .accessibilityIdentifier("billing.subscription.deleteDiscount")
          }
          Button("Cancel now…", role: .destructive) { activeSheet = .cancel }
            .accessibilityIdentifier("billing.subscription.cancel")
        } label: {
          Label("Actions", systemImage: "ellipsis.circle")
        }
        .accessibilityIdentifier("billing.subscription.actions")
      }
    }
  }

  /// Only live subscriptions offer actions; a canceled one is history.
  private func hasActions(_ subscription: Subscription) -> Bool {
    switch subscription.status {
    case .canceled, .incompleteExpired, .undocumented: return false
    default: return true
    }
  }

  private func runLifecycle(_ action: SubscriptionLifecycleAction) async {
    pendingAction = nil
    guard let writer else { return }
    let id = subscriptionID
    do {
      switch action {
      case .resume:
        _ = try await writer.resumeSubscription(
          id: id, resume: .init(
            billingCycleAnchor: nil, paymentBehavior: nil,
            prorationBehavior: nil, prorationDate: nil),
          summary: "Resume subscription \(id)")
      case .migrate:
        _ = try await writer.migrateSubscription(
          id: id, migrate: .init(type: .flexible, prorationDiscounts: nil),
          summary: "Migrate subscription \(id) to flexible billing")
      case .cancelAtPeriodEnd:
        _ = try await writer.updateSubscription(
          id: id,
          update: .init(
            description: nil, metadata: nil, cancelAtPeriodEnd: true,
            collectionMethod: nil, daysUntilDue: nil, pauseCollection: nil,
            prorationBehavior: nil, prorationDate: nil, cancellationDetails: nil),
          summary: "Set subscription \(id) to cancel at period end")
      case .keep:
        _ = try await writer.updateSubscription(
          id: id,
          update: .init(
            description: nil, metadata: nil, cancelAtPeriodEnd: false,
            collectionMethod: nil, daysUntilDue: nil, pauseCollection: nil,
            prorationBehavior: nil, prorationDate: nil, cancellationDetails: nil),
          summary: "Keep subscription \(id) past the period end")
      case .deleteDiscount:
        _ = try await writer.deleteDiscountSubscription(
          id: id, summary: "Remove discount from subscription \(id)")
      }
      writeResult = WriteResult(
        title: action.successTitle, message: "\(action.successMessage) \(id).")
      await loadSubscription()
    } catch {
      writeResult = WriteResult(
        title: "Write failed", message: writeErrorMessage(error))
    }
  }

  // MARK: - Sheets

  @ViewBuilder
  private func sheetView(_ sheet: SubscriptionSheet) -> some View {
    switch sheet {
    case .edit:
      if let subscription, let writer {
        EditSubscriptionSheet(
          subscription: subscription, writer: writer, onFinished: handleWriteFinished)
      }
    case .cancel:
      if let writer {
        CancelSubscriptionSheet(
          subscriptionID: subscriptionID, writer: writer,
          onFinished: handleWriteFinished)
      }
    case .pause:
      if let writer {
        PauseSubscriptionSheet(
          subscriptionID: subscriptionID, writer: writer,
          onFinished: handleWriteFinished)
      }
    case .addItem:
      if let writer {
        AddSubscriptionItemSheet(
          subscriptionID: subscriptionID, writer: writer,
          onFinished: handleWriteFinished)
      }
    }
  }

  // MARK: - Content

  @ViewBuilder
  private func subscriptionView(_ subscription: Subscription) -> some View {
    Form {
      Section("Summary") {
        Field("Status", subscription.status.displayString)
        if let description = subscription.description.valueOrNil, !description.isEmpty {
          Field("Description", description)
        }
        Field("Currency", subscription.currency.uppercased())
        Field("Billing mode", subscription.billingMode.type.rawValue)
        if subscription.cancelAtPeriodEnd {
          Field("Cancels", "At period end")
        }
        if let cancelAt = subscription.cancelAt.valueOrNil {
          Field(
            "Cancel at",
            cancelAt.date.formatted(date: .abbreviated, time: .shortened))
        }
        Field("ID", subscription.id)
      }

      Section("Customer") {
        Field("Customer", customerLabel(subscription))
      }

      Section("Dates") {
        Field(
          "Created",
          subscription.created.date.formatted(date: .abbreviated, time: .shortened))
        Field(
          "Start",
          subscription.startDate.date.formatted(date: .abbreviated, time: .shortened))
        if let trialStart = subscription.trialStart.valueOrNil {
          Field(
            "Trial start",
            trialStart.date.formatted(date: .abbreviated, time: .omitted))
        }
        if let trialEnd = subscription.trialEnd.valueOrNil {
          Field(
            "Trial end",
            trialEnd.date.formatted(date: .abbreviated, time: .omitted))
        }
        if let endedAt = subscription.endedAt.valueOrNil {
          Field(
            "Ended",
            endedAt.date.formatted(date: .abbreviated, time: .shortened))
        }
        if let canceledAt = subscription.canceledAt.valueOrNil {
          Field(
            "Canceled at",
            canceledAt.date.formatted(date: .abbreviated, time: .shortened))
        }
      }

      if let pause = subscription.pauseCollection.valueOrNil {
        Section("Paused") {
          Field("Behavior", pause.behavior.rawValue)
          if let resumesAt = pause.resumesAt.valueOrNil {
            Field(
              "Resumes",
              resumesAt.date.formatted(date: .abbreviated, time: .shortened))
          }
        }
      }

      Section("Items") {
        ForEach(subscription.items.data, id: \.id) { item in
          itemRow(item)
        }
      }

      if !subscription.discounts.isEmpty {
        Section("Discounts") {
          ForEach(subscription.discounts.indices, id: \.self) { index in
            Field("Discount \(index + 1)", discountLabel(subscription.discounts[index]))
          }
        }
      }

      if !subscription.metadata.isEmpty {
        Section("Metadata") {
          ForEach(subscription.metadata.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
            Field(key, value)
          }
        }
      }
    }
  }

  private func itemRow(_ item: SubscriptionItem) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(itemTitle(item))
        .font(.body)
      Text(itemSubtitle(item))
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
    .padding(.vertical, 2)
  }

  private func itemTitle(_ item: SubscriptionItem) -> String {
    if let nickname = item.price.nickname.valueOrNil, !nickname.isEmpty {
      return nickname
    }
    return item.price.id
  }

  private func itemSubtitle(_ item: SubscriptionItem) -> String {
    var parts: [String] = []
    if let quantity = item.quantity {
      parts.append("Qty \(quantity)")
    }
    parts.append(item.price.recurring.valueOrNil?.interval.rawValue ?? "one-shot")
    parts.append(
      MoneyFormat.amount(item.price.unitAmount.valueOrNil ?? 0, currency: item.price.currency))
    parts.append(
      "Period ends \(item.currentPeriodEnd.date.formatted(date: .abbreviated, time: .omitted))")
    return parts.joined(separator: " · ")
  }

  private func customerLabel(_ subscription: Subscription) -> String {
    switch subscription.customer {
    case .string(let id): return id
    case .customer(let customer):
      if let name = customer.name.flatMap({ $0.valueOrNil }), !name.isEmpty {
        return name
      }
      if let email = customer.email.valueOrNil, !email.isEmpty {
        return email
      }
      return customer.id
    case .deletedCustomer(let deleted): return "\(deleted.id) (deleted)"
    case .other: return "—"
    }
  }

  private func discountLabel(_ discount: Expandable<Discount>) -> String {
    if let id = discount.idOrNil { return id }
    return "coupon"
  }
}

// MARK: - Sheet and lifecycle types

/// Sheets presented from the subscription detail view.
private enum SubscriptionSheet: Identifiable {
  case edit
  case cancel
  case pause
  case addItem

  var id: String {
    switch self {
    case .edit: return "edit"
    case .cancel: return "cancel"
    case .pause: return "pause"
    case .addItem: return "addItem"
    }
  }
}

/// A lifecycle action awaiting confirmation.
private enum SubscriptionLifecycleAction: String, Identifiable {
  case resume
  case migrate
  case cancelAtPeriodEnd
  case keep
  case deleteDiscount

  var id: String { rawValue }

  var isDestructive: Bool {
    switch self {
    case .deleteDiscount: return true
    default: return false
    }
  }

  var buttonTitle: String {
    switch self {
    case .resume: return "Resume"
    case .migrate: return "Migrate"
    case .cancelAtPeriodEnd: return "Cancel at period end"
    case .keep: return "Keep"
    case .deleteDiscount: return "Remove discount"
    }
  }

  var successTitle: String {
    switch self {
    case .resume: return "Subscription resumed"
    case .migrate: return "Subscription migrated"
    case .cancelAtPeriodEnd: return "Cancellation scheduled"
    case .keep: return "Cancellation revoked"
    case .deleteDiscount: return "Discount removed"
    }
  }

  var successMessage: String {
    switch self {
    case .resume: return "Resumed"
    case .migrate: return "Migrated"
    case .cancelAtPeriodEnd: return "Set to cancel"
    case .keep: return "Kept"
    case .deleteDiscount: return "Removed from"
    }
  }

  var message: String {
    switch self {
    case .resume:
      return "The subscription will resume collecting payments."
    case .migrate:
      return "The subscription moves to flexible billing mode. This cannot be undone."
    case .cancelAtPeriodEnd:
      return "The subscription stays active until the current period ends, then cancels."
    case .keep:
      return "The scheduled period-end cancellation is removed."
    case .deleteDiscount:
      return "The discount is removed from this subscription. This cannot be undone."
    }
  }
}
