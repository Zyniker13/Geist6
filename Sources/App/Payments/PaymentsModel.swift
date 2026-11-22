import GeistData
import StripeModels
import SwiftUI

/// Loads and holds the payments lists of one account. Read-only by
/// construction: it holds a `PaymentsBackend`, which has no write methods.
@MainActor
@Observable
final class PaymentsModel {
  enum Segment: String, CaseIterable, Identifiable {
    case paymentIntents
    case charges
    case refunds
    case setupIntents
    case paymentMethods
    case paymentLinks
    case checkoutSessions
    case payouts
    case transfers
    case topups

    var id: String { rawValue }

    var label: String {
      switch self {
      case .paymentIntents: return "Intents"
      case .charges: return "Charges"
      case .refunds: return "Refunds"
      case .setupIntents: return "Setup"
      case .paymentMethods: return "Methods"
      case .paymentLinks: return "Links"
      case .checkoutSessions: return "Checkout"
      case .payouts: return "Payouts"
      case .transfers: return "Transfers"
      case .topups: return "Top-ups"
      }
    }
  }

  enum Phase: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
  }

  private let backend: any PaymentsBackend
  private(set) var phase: Phase = .idle
  private(set) var paymentIntents: [PaymentIntent] = []
  private(set) var charges: [Charge] = []
  private(set) var refunds: [Refund] = []
  private(set) var setupIntents: [SetupIntent] = []
  private(set) var paymentMethods: [PaymentMethod] = []
  private(set) var paymentLinks: [PaymentLink] = []
  private(set) var checkoutSessions: [CheckoutSession] = []
  private(set) var payouts: [Payout] = []
  private(set) var transfers: [Transfer] = []
  private(set) var topups: [Topup] = []
  /// The active filter (M4c-5, decision 0019). Applied server-side where
  /// the backend supports it and client-side over the fetched page.
  private(set) var filter = PaymentsFilter()

  init(backend: any PaymentsBackend) {
    self.backend = backend
  }

  /// Loads the list backing one segment. Each segment loads independently:
  /// a failure in one does not clear another. Server-side filter dimensions
  /// (created range, customer, link active state) ride on the list request;
  /// the remaining dimensions trim the fetched page client-side.
  func load(_ segment: Segment) async {
    phase = .loading
    do {
      switch segment {
      case .paymentIntents:
        var items = try await backend.paymentIntents(
          created: filter.createdInterval, customer: filter.customer
        )
        if !filter.isEmpty { items = items.filter { filter.matches($0) } }
        paymentIntents = items
      case .charges:
        var items = try await backend.charges(
          created: filter.createdInterval, customer: filter.customer, paymentIntent: nil
        )
        if !filter.isEmpty { items = items.filter { filter.matches($0) } }
        charges = items
      case .refunds:
        var items = try await backend.refunds(charge: nil)
        if !filter.isEmpty { items = items.filter { filter.matches($0) } }
        refunds = items
      case .setupIntents:
        var items = try await backend.setupIntents(
          created: filter.createdInterval, customer: filter.customer
        )
        if !filter.isEmpty { items = items.filter { filter.matches($0) } }
        setupIntents = items
      case .paymentMethods:
        var items = try await backend.paymentMethods(customer: filter.customer)
        if !filter.isEmpty { items = items.filter { filter.matches($0) } }
        paymentMethods = items
      case .paymentLinks:
        var items = try await backend.paymentLinks(active: filter.linkActive)
        if !filter.isEmpty { items = items.filter { filter.matches($0) } }
        paymentLinks = items
      case .checkoutSessions:
        var items = try await backend.checkoutSessions(
          created: filter.createdInterval, customer: filter.customer, status: filter.status
        )
        if !filter.isEmpty { items = items.filter { filter.matches($0) } }
        checkoutSessions = items
      case .payouts:
        var items = try await backend.payouts()
        if !filter.isEmpty { items = items.filter { filter.matches($0) } }
        payouts = items
      case .transfers:
        var items = try await backend.transfers()
        if !filter.isEmpty { items = items.filter { filter.matches($0) } }
        transfers = items
      case .topups:
        var items = try await backend.topups()
        if !filter.isEmpty { items = items.filter { filter.matches($0) } }
        topups = items
      }
      phase = .loaded
    } catch {
      phase = .failed(String(describing: error))
    }
  }

  /// Applies a new filter. The created-range and customer dimensions narrow
  /// server-side, so every segment is refetched; call this after the filter
  /// editor confirms, not per keystroke.
  func apply(_ newFilter: PaymentsFilter) async {
    guard newFilter != filter else { return }
    filter = newFilter
    for segment in Segment.allCases {
      await load(segment)
    }
  }
}
