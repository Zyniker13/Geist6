import GeistData
import StripeModels
import SwiftUI

/// Loads and holds the customers lists of one account. Read-only by
/// construction: it holds a `CustomersBackend`, which has no write methods
/// — customer writes go through `CustomersWriteService`, held by the view.
@MainActor
@Observable
final class CustomersModel {
  enum Segment: String, CaseIterable, Identifiable {
    case customers
    case taxIDs

    var id: String { rawValue }

    var label: String {
      switch self {
      case .customers: return "Customers"
      case .taxIDs: return "Tax IDs"
      }
    }
  }

  enum Phase: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
  }

  private let backend: any CustomersBackend
  private(set) var phase: Phase = .idle
  private(set) var customers: [Customer] = []
  private(set) var taxIDs: [TaxId] = []
  /// The active filter (decision 0026). The created range narrows
  /// server-side; the email fragment trims the fetched page client-side.
  private(set) var filter = CustomersFilter()
  /// Stripe Search query over customers, when set. An empty string falls
  /// back to the plain filtered list.
  var searchQuery = ""

  init(backend: any CustomersBackend) {
    self.backend = backend
  }

  /// Loads the list backing one segment. Each segment loads independently:
  /// a failure in one does not clear the other.
  func load(_ segment: Segment) async {
    phase = .loading
    switch segment {
    case .customers:
      do {
        var items: [Customer]
        if !searchQuery.isEmpty {
          items = try await backend.searchCustomers(query: searchQuery)
        } else {
          items = try await backend.customers(created: filter.createdInterval, email: nil)
        }
        if !filter.isEmpty {
          items = items.filter { filter.matches($0) }
        }
        customers = items
      } catch {
        phase = .failed(String(describing: error))
        return
      }
    case .taxIDs:
      do {
        taxIDs = try await backend.taxIDs(customer: nil)
      } catch {
        phase = .failed(String(describing: error))
        return
      }
    }
    phase = .loaded
  }

  /// Applies a new filter and reloads the customers list. The created range
  /// narrows server-side, so the list is refetched; call this after the
  /// filter editor confirms, not per keystroke.
  func apply(_ newFilter: CustomersFilter) async {
    guard newFilter != filter else { return }
    filter = newFilter
    await load(.customers)
  }

  /// Runs the Stripe Search query and replaces the customers list. An
  /// empty query falls back to the plain filtered list.
  func search(_ query: String) async {
    searchQuery = query.trimmingCharacters(in: .whitespaces)
    await load(.customers)
  }
}
