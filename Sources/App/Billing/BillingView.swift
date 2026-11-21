import GeistData
import StripeModels
import SwiftUI

/// A tapped row's destination.
enum BillingRoute: Hashable {
  case product(String)
  case coupon(String)
  case promotionCode(String)
  case invoice(String)
}

/// The billing segment: the product catalog with search, and the write
/// entry points when the account allows writes.
struct BillingView: View {
  let account: Account
  let backend: any BillingBackend
  /// Nil for dashboard-locked accounts: no write UI exists at all.
  let writer: BillingWriteService?

  @State private var model: BillingModel?
  @State private var createProductPresented = false
  @State private var createPricePresented = false
  @State private var createCouponPresented = false
  @State private var createPromotionCodePresented = false
  @State private var writeResult: WriteResult?
  @State private var searchText = ""

  var body: some View {
    Group {
      if let model {
        content(model)
      } else {
        ProgressView()
      }
    }
    .navigationTitle("Billing")
    .task {
      if model == nil {
        model = BillingModel(backend: backend)
      }
      await model?.load()
    }
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        if writer != nil {
          Menu {
            Button {
              createProductPresented = true
            } label: {
              Label("New product", systemImage: "shippingbox")
            }
            .accessibilityIdentifier("billing.newProduct")
            Button {
              createPricePresented = true
            } label: {
              Label("New price", systemImage: "tag")
            }
            .accessibilityIdentifier("billing.newPrice")
            Button {
              createCouponPresented = true
            } label: {
              Label("New coupon", systemImage: "ticket")
            }
            .accessibilityIdentifier("billing.newCoupon")
            Button {
              createPromotionCodePresented = true
            } label: {
              Label("New promotion code", systemImage: "qrcode")
            }
            .accessibilityIdentifier("billing.newPromotionCode")
          } label: {
            Label("Add", systemImage: "plus")
          }
          .accessibilityIdentifier("billing.add")
        }
      }
    }
    .sheet(isPresented: $createProductPresented) {
      if let writer {
        CreateProductSheet(writer: writer, onFinished: handleWriteFinished)
      }
    }
    .sheet(isPresented: $createPricePresented) {
      if let writer {
        CreatePriceSheet(writer: writer, presetProductID: nil, onFinished: handleWriteFinished)
      }
    }
    .sheet(isPresented: $createCouponPresented) {
      if let writer {
        CreateCouponSheet(writer: writer, onFinished: handleWriteFinished)
      }
    }
    .sheet(isPresented: $createPromotionCodePresented) {
      if let writer {
        CreatePromotionCodeSheet(
          writer: writer, coupons: model?.coupons ?? [], onFinished: handleWriteFinished)
      }
    }
    .writeResultAlert($writeResult)
  }

  private func handleWriteFinished(_ result: WriteResult) {
    createProductPresented = false
    createPricePresented = false
    createCouponPresented = false
    createPromotionCodePresented = false
    writeResult = result
    Task { await model?.load() }
  }

  @ViewBuilder
  private func content(_ model: BillingModel) -> some View {
    list(model)
  }

  @ViewBuilder
  private func list(_ model: BillingModel) -> some View {
    if model.phase == .loading, model.products.isEmpty, model.coupons.isEmpty,
      model.promotionCodes.isEmpty, model.invoices.isEmpty
    {
      ProgressView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      rows(model)
    }
  }

  @ViewBuilder
  private func rows(_ model: BillingModel) -> some View {
    List {
      // Products section
      Section("Products") {
        if model.products.isEmpty {
          if let error = model.productsError {
            Text("Couldn't load products: ") + Text(error)
          } else {
            Text(model.searchQuery.isEmpty ? "No products yet" : "No matching products")
              .foregroundStyle(.secondary)
          }
        } else {
          ForEach(model.products, id: \.id) { product in
            NavigationLink(value: BillingRoute.product(product.id)) {
              ProductRow(product: product)
            }
            .accessibilityIdentifier("billing.row.product.\(product.id)")
          }
        }
      }

      // Coupons section
      Section("Coupons") {
        if model.coupons.isEmpty {
          if let error = model.couponsError {
            Text("Couldn't load coupons: ") + Text(error)
          } else {
            Text(model.searchQuery.isEmpty ? "No coupons yet" : "No matching coupons")
              .foregroundStyle(.secondary)
          }
        } else {
          ForEach(model.coupons, id: \.id) { coupon in
            NavigationLink(value: BillingRoute.coupon(coupon.id)) {
              CouponRow(coupon: coupon)
            }
            .accessibilityIdentifier("billing.row.coupon.\(coupon.id)")
          }
        }
      }

      // Promotion codes section
      Section("Promotion codes") {
        if model.promotionCodes.isEmpty {
          if let error = model.promotionCodesError {
            Text("Couldn't load promotion codes: ") + Text(error)
          } else {
            Text(model.searchQuery.isEmpty ? "No promotion codes yet" : "No matching promotion codes")
              .foregroundStyle(.secondary)
          }
        } else {
          ForEach(model.promotionCodes, id: \.id) { promo in
            NavigationLink(value: BillingRoute.promotionCode(promo.id)) {
              PromotionCodeRow(promotionCode: promo)
            }
            .accessibilityIdentifier("billing.row.promotion.\(promo.id)")
          }
        }
      }
      // Invoices section
      Section("Invoices") {
        if model.invoices.isEmpty {
          if let error = model.invoicesError {
            Text("Couldn't load invoices: ") + Text(error)
          } else {
            Text(model.searchQuery.isEmpty ? "No invoices yet" : "No matching invoices")
              .foregroundStyle(.secondary)
          }
        } else {
          ForEach(model.invoices, id: \.id) { invoice in
            if let id = invoice.id {
              NavigationLink(value: BillingRoute.invoice(id)) {
                InvoiceRow(invoice: invoice)
              }
              .accessibilityIdentifier("billing.row.invoice.\(id)")
            }
          }
        }
      }
    }
    .overlay(alignment: .top) {
      if model.phase == .loading { ProgressView().padding(.top, 4) }
    }
    .navigationDestination(for: BillingRoute.self) { route in
      switch route {
      case .product(let id):
        ProductDetailView(productID: id, backend: backend, writer: writer)
      case .coupon(let id):
        CouponDetailView(couponID: id, backend: backend, writer: writer)
      case .promotionCode(let id):
        PromotionCodeDetailView(promotionCodeID: id, backend: backend, writer: writer)
      case .invoice(let id):
        InvoiceDetailView(invoiceID: id, backend: backend, writer: writer)
      }
    }
    .searchable(
      text: $searchText,
      placement: .navigationBarDrawer(displayMode: .automatic),
      prompt: "Search products"
    )
    .onSubmit(of: .search) {
      Task { await model.search(searchText) }
    }
  }
}

// MARK: - Rows

/// One product in the catalog list: name, description, active state.
struct ProductRow: View {
  let product: Product

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title)
        .font(.body)
      Text(subtitle)
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
    .padding(.vertical, 2)
  }

  private var title: String {
    if !product.name.isEmpty { return product.name }
    return product.id
  }

  private var subtitle: String {
    var parts: [String] = []
    if let description = product.description.valueOrNil, !description.isEmpty {
      parts.append(description)
    }
    parts.append(product.active ? "Active" : "Inactive")
    return parts.joined(separator: " · ")
  }
}

/// One coupon in the list: name, discount type, duration.
struct CouponRow: View {
  let coupon: Coupon

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title)
        .font(.body)
      Text(subtitle)
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
    .padding(.vertical, 2)
  }

  private var title: String {
    if let name = coupon.name.valueOrNil, !name.isEmpty { return name }
    return coupon.id
  }

  private var subtitle: String {
    var parts: [String] = []
    if let amountOff = coupon.amountOff.valueOrNil {
      let formatted = String(format: "%.2f", Double(amountOff) / 100.0)
      let currency = (coupon.currency.valueOrNil ?? "usd").uppercased()
      parts.append("−\(formatted) \(currency)")
    } else if let percentOff = coupon.percentOff.valueOrNil {
      parts.append("\(percentOff)% off")
    }
    parts.append(coupon.duration.displayString)
    parts.append(coupon.valid ? "Valid" : "Invalid")
    return parts.joined(separator: " · ")
  }
}

/// One promotion code in the list: code string, active state, coupon name.
struct PromotionCodeRow: View {
  let promotionCode: PromotionCode

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title)
        .font(.body)
      Text(subtitle)
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
    .padding(.vertical, 2)
  }

  private var title: String {
    if !promotionCode.code.isEmpty { return promotionCode.code }
    return promotionCode.id
  }

  private var subtitle: String {
    var parts: [String] = []
    if let couponName = promotionCode.promotion.coupon.valueOrNil?.objectOrNil?.name.valueOrNil,
      !couponName.isEmpty
    {
      parts.append(couponName)
    }
    parts.append(promotionCode.active ? "Active" : "Inactive")
    parts.append("Redeemed \(promotionCode.timesRedeemed)×")
    return parts.joined(separator: " · ")
  }
}

/// One invoice in the list: number, status, total, customer email.
struct InvoiceRow: View {
  let invoice: Invoice

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title)
        .font(.body)
      Text(subtitle)
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
    .padding(.vertical, 2)
  }

  private var title: String {
    if let number = invoice.number.valueOrNil, !number.isEmpty { return number }
    return invoice.id ?? "—"
  }

  private var subtitle: String {
    var parts: [String] = []
    parts.append(invoice.statusDisplay)
    parts.append(MoneyFormat.amount(invoice.total, currency: invoice.currency))
    if let email = invoice.customerEmail.valueOrNil, !email.isEmpty {
      parts.append(email)
    }
    return parts.joined(separator: " · ")
  }
}

// MARK: - Helpers

extension CouponDuration {
  var displayString: String {
    switch self {
    case .once: return "Once"
    case .repeating: return "Repeating"
    case .forever: return "Forever"
    case .undocumented(let value): return value
    }
  }
}
