import GeistData
import Observation
import StripeModels

/// Backing model for the Billing screen: the product catalog, coupons, and
/// promotion codes. Read-only by construction: `BillingBackend` has no write
/// methods, so the model cannot send one; writes go through
/// `BillingWriteService`, which is built only for accounts without a
/// dashboard lock (the three-gate pattern from payments).
@MainActor
@Observable
final class BillingModel {
  enum Phase: Equatable {
    case idle
    case loading
    case loaded
  }

  let backend: BillingBackend

  private(set) var phase: Phase = .idle
  private(set) var products: [Product] = []
  private(set) var coupons: [Coupon] = []
  private(set) var promotionCodes: [PromotionCode] = []
  private(set) var invoices: [Invoice] = []
  /// Per-section load failures. The screen renders each section
  /// independently: a decode or network failure in one section leaves the
  /// others loaded instead of blanking the whole screen.
  private(set) var productsError: String?
  private(set) var couponsError: String?
  private(set) var promotionCodesError: String?
  private(set) var invoicesError: String?
  private(set) var searchQuery = ""

  init(backend: BillingBackend) {
    self.backend = backend
  }

  /// Loads the catalog: products, coupons, promotion codes, and invoices.
  /// The sections load concurrently and settle independently; the load ends
  /// once every section has either rows or a section error.
  func load() async {
    phase = .loading
    async let productsSettled: Void = loadProducts()
    async let couponsSettled: Void = loadCoupons()
    async let promotionCodesSettled: Void = loadPromotionCodes()
    async let invoicesSettled: Void = loadInvoices()
    _ = await (productsSettled, couponsSettled, promotionCodesSettled, invoicesSettled)
    phase = .loaded
  }

  private func loadProducts() async {
    do {
      products = searchQuery.isEmpty
        ? try await backend.products()
        : try await backend.searchProducts(query: searchQuery)
      productsError = nil
    } catch {
      productsError = String(describing: error)
    }
  }

  private func loadCoupons() async {
    do {
      let all = try await backend.coupons()
      coupons = searchQuery.isEmpty
        ? all
        : all.filter { coupon in matches(coupon.id) || matches(coupon.name.valueOrNil) }
      couponsError = nil
    } catch {
      couponsError = String(describing: error)
    }
  }

  private func loadPromotionCodes() async {
    do {
      let all = try await backend.promotionCodes()
      promotionCodes = searchQuery.isEmpty
        ? all
        : all.filter { promotionCode in
          matches(promotionCode.code)
            || matches(promotionCode.promotion.coupon.valueOrNil?.idOrNil)
        }
      promotionCodesError = nil
    } catch {
      promotionCodesError = String(describing: error)
    }
  }

  private func loadInvoices() async {
    do {
      let all = try await backend.invoices()
      invoices = searchQuery.isEmpty
        ? all
        : all.filter { invoice in
          matches(invoice.id)
            || matches(invoice.customerEmail.valueOrNil)
            || matches(invoice.number.valueOrNil)
        }
      invoicesError = nil
    } catch {
      invoicesError = String(describing: error)
    }
  }

  /// Case-insensitive substring match against the active search query.
  private func matches(_ text: String?) -> Bool {
    guard let text, !searchQuery.isEmpty else { return false }
    return text.localizedCaseInsensitiveContains(searchQuery)
  }

  /// Runs the Stripe Search query and replaces the product list. An empty
  /// query falls back to the plain list.
  func search(_ query: String) async {
    searchQuery = query.trimmingCharacters(in: .whitespaces)
    await load()
  }
}
