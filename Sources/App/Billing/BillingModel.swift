import GeistData
import Observation
import StripeModels

/// Backing model for the Billing screen: the product catalog and its
/// prices. Read-only by construction: `BillingBackend` has no write
/// methods, so the model cannot send one; product and price writes go
/// through `BillingWriteService`, which is built only for accounts
/// without a dashboard lock (the three-gate pattern from payments).
@MainActor
@Observable
final class BillingModel {
  enum Phase: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
  }

  let backend: BillingBackend

  private(set) var phase: Phase = .idle
  private(set) var products: [Product] = []
  private(set) var searchQuery = ""

  init(backend: BillingBackend) {
    self.backend = backend
  }

  /// Loads the catalog: the product list, or search results when a query
  /// is present. Each reload replaces the whole list.
  func load() async {
    phase = .loading
    do {
      if searchQuery.isEmpty {
        products = try await backend.products()
      } else {
        products = try await backend.searchProducts(query: searchQuery)
      }
      phase = .loaded
    } catch {
      phase = .failed(String(describing: error))
    }
  }

  /// Runs the Stripe Search query and replaces the catalog. An empty
  /// query falls back to the plain list.
  func search(_ query: String) async {
    searchQuery = query.trimmingCharacters(in: .whitespaces)
    await load()
  }
}
