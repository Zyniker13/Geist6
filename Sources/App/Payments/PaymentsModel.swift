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

    var id: String { rawValue }

    var label: String {
      switch self {
      case .paymentIntents: return "Intents"
      case .charges: return "Charges"
      case .refunds: return "Refunds"
      case .setupIntents: return "Setup"
      case .paymentMethods: return "Methods"
      case .paymentLinks: return "Links"
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

  init(backend: any PaymentsBackend) {
    self.backend = backend
  }

  /// Loads the list backing one segment. Each segment loads independently:
  /// a failure in one does not clear another.
  func load(_ segment: Segment) async {
    phase = .loading
    do {
      switch segment {
      case .paymentIntents:
        paymentIntents = try await backend.paymentIntents(created: nil, customer: nil)
      case .charges:
        charges = try await backend.charges(created: nil, customer: nil, paymentIntent: nil)
      case .refunds:
        refunds = try await backend.refunds(charge: nil)
      case .setupIntents:
        setupIntents = try await backend.setupIntents(created: nil)
      case .paymentMethods:
        paymentMethods = try await backend.paymentMethods(customer: nil)
      case .paymentLinks:
        paymentLinks = try await backend.paymentLinks()
      }
      phase = .loaded
    } catch {
      phase = .failed(String(describing: error))
    }
  }
}
