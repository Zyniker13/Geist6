import GeistData
import SwiftUI

/// Loads and holds the home dashboard data for one account.
@MainActor
@Observable
final class DashboardModel {
  enum Phase: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
  }

  private(set) var phase: Phase = .idle
  private(set) var snapshot: HomeSnapshot?
  private let loader: HomeDataLoader

  init(backend: any StripeDataBackend) {
    loader = HomeDataLoader(backend: backend)
  }

  func load(period: HomePeriod, currency: String) async {
    phase = .loading
    do {
      let interval = period.interval(now: Date())
      snapshot = try await loader.load(period: interval, currency: currency)
      phase = .loaded
    } catch {
      phase = .failed(Self.message(of: error))
    }
  }

  /// A short user-facing description of a failure.
  static func message(of error: Error) -> String {
    if let localized = error as? LocalizedError, let text = localized.errorDescription, !text.isEmpty {
      return text
    }
    return String(describing: error)
  }
}
