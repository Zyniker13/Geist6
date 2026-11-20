import GeistData
import StripeModels
import SwiftUI

/// A tapped row's destination: the product detail screen fetches by ID.
enum BillingRoute: Hashable {
  case product(String)
}

/// The billing segment: the account's product catalog with search, and
/// the write entry points when the account allows writes.
struct BillingView: View {
  let account: Account
  let backend: any BillingBackend
  /// Nil for dashboard-locked accounts: no write UI exists at all.
  let writer: BillingWriteService?

  @State private var model: BillingModel?
  @State private var createProductPresented = false
  @State private var createPricePresented = false
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
    .writeResultAlert($writeResult)
  }

  private func handleWriteFinished(_ result: WriteResult) {
    createProductPresented = false
    createPricePresented = false
    writeResult = result
    Task { await model?.load() }
  }

  @ViewBuilder
  private func content(_ model: BillingModel) -> some View {
    switch model.phase {
    case .failed(let message):
      ContentUnavailableView(
        "Couldn't load billing",
        systemImage: "exclamationmark.triangle",
        description: Text(message)
      )
    default:
      list(model)
    }
  }

  @ViewBuilder
  private func list(_ model: BillingModel) -> some View {
    if model.phase == .loading, model.products.isEmpty {
      ProgressView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else if model.products.isEmpty {
      ContentUnavailableView(
        "No products",
        systemImage: "shippingbox",
        description: Text(emptyDescription(model))
      )
    } else {
      rows(model)
    }
  }

  @ViewBuilder
  private func rows(_ model: BillingModel) -> some View {
    List {
      ForEach(model.products, id: \.id) { product in
        NavigationLink(value: BillingRoute.product(product.id)) {
          ProductRow(product: product)
        }
        .accessibilityIdentifier("billing.row.\(product.id)")
      }
    }
    .overlay(alignment: .top) {
      if model.phase == .loading { ProgressView().padding(.top, 4) }
    }
    .navigationDestination(for: BillingRoute.self) { route in
      switch route {
      case .product(let id):
        ProductDetailView(productID: id, backend: backend, writer: writer)
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

  /// Distinguishes "nothing exists yet" from "the search narrowed it away".
  private func emptyDescription(_ model: BillingModel) -> String {
    if !model.searchQuery.isEmpty {
      return "No results match the search."
    }
    return "Nothing has been created yet."
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
