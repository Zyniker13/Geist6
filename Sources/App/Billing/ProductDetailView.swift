import GeistData
import StripeModels
import SwiftUI

/// The product detail screen: the product's fields, its prices, and the
/// edit/add-price/delete actions when the account allows writes.
struct ProductDetailView: View {
  enum Phase: Equatable {
    case loading
    case loaded
    case failed(String)
  }

  let productID: String
  let backend: any BillingBackend
  /// Nil for dashboard-locked accounts: no write UI exists at all.
  let writer: BillingWriteService?

  @State private var phase: Phase = .loading
  @State private var product: Product?
  @State private var prices: [Price] = []
  @State private var editPresented = false
  @State private var createPricePresented = false
  @State private var deletePresented = false
  @State private var editingPrice: EditingPrice?
  @State private var writeResult: WriteResult?

  var body: some View {
    List {
      switch phase {
      case .loading:
        ProgressView()
          .frame(maxWidth: .infinity)
          .accessibilityIdentifier("billing.product.loading")
      case .failed(let message):
        Text(message)
          .font(.footnote)
          .foregroundStyle(.red)
          .accessibilityIdentifier("billing.product.error")
      case .loaded:
        if let product {
          fields(product)
          pricesSection
        }
      }
    }
    .navigationTitle(title ?? "Product")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      actionsToolbar
    }
    .task {
      await load()
    }
    .sheet(isPresented: $editPresented) {
      if let product, let writer {
        EditProductSheet(
          product: product, writer: writer,
          onFinished: handleWriteFinished)
          .presentationDetents([.medium, .large])
      }
    }
    .sheet(isPresented: $createPricePresented) {
      if let writer {
        CreatePriceSheet(
          writer: writer, presetProductID: productID,
          onFinished: handleWriteFinished)
          .presentationDetents([.medium, .large])
      }
    }
    .sheet(item: $editingPrice) { editing in
      if let writer {
        EditPriceSheet(
          price: editing.price, writer: writer, onFinished: handleWriteFinished)
          .presentationDetents([.medium, .large])
      }
    }
    .confirmationDialog(
      "Delete this product? This cannot be undone.",
      isPresented: $deletePresented, titleVisibility: .visible
    ) {
      Button("Delete product", role: .destructive) {
        Task { await runDelete() }
      }
      Button("Cancel", role: .cancel) {}
    }
    .writeResultAlert($writeResult)
  }

  private var title: String? {
    if let product {
      if !product.name.isEmpty { return product.name }
      return product.id
    }
    return nil
  }

  private func load() async {
    phase = .loading
    do {
      product = try await backend.retrieveProduct(id: productID)
      prices = try await backend.prices(product: productID)
      phase = .loaded
    } catch {
      phase = .failed(String(describing: error))
    }
  }

  private func handleWriteFinished(_ result: WriteResult) {
    editPresented = false
    createPricePresented = false
    writeResult = result
    Task { await load() }
  }

  private func runDelete() async {
    guard let writer else { return }
    do {
      _ = try await writer.deleteProduct(id: productID, summary: "Delete \(productID)")
      writeResult = WriteResult(
        title: "Product deleted", message: "Delete request sent for \(productID).")
      await load()
    } catch {
      writeResult = WriteResult(title: "Write failed", message: writeErrorMessage(error))
    }
  }

  @ToolbarContentBuilder
  private var actionsToolbar: some ToolbarContent {
    ToolbarItem(placement: .primaryAction) {
      if let writer, case .loaded = phase {
        Menu {
          Button("Edit product…") { editPresented = true }
            .accessibilityIdentifier("billing.product.edit")
          Button("Add price…") { createPricePresented = true }
            .accessibilityIdentifier("billing.product.addPrice")
          Button("Delete product…", role: .destructive) { deletePresented = true }
            .accessibilityIdentifier("billing.product.delete")
        } label: {
          Label("Actions", systemImage: "ellipsis.circle")
        }
        .accessibilityIdentifier("billing.product.actions")
      }
    }
  }

  // MARK: Sections

  @ViewBuilder
  private func fields(_ product: Product) -> some View {
    Section("Product") {
      LabeledContent("ID", value: product.id)
      if !product.name.isEmpty {
        LabeledContent("Name", value: product.name)
      }
      if let description = product.description.valueOrNil, !description.isEmpty {
        LabeledContent("Description", value: description)
      }
      LabeledContent("Active", value: product.active ? "Yes" : "No")
      if let defaultPriceID = product.defaultPrice?.valueOrNil?.idOrNil {
        LabeledContent("Default price", value: defaultPriceID)
      }
      if let unitLabel = product.unitLabel?.valueOrNil, !unitLabel.isEmpty {
        LabeledContent("Unit label", value: unitLabel)
      }
      if let statement = product.statementDescriptor?.valueOrNil, !statement.isEmpty {
        LabeledContent("Statement descriptor", value: statement)
      }
      LabeledContent(
        "Created",
        value: "\(product.created.date.formatted(date: .abbreviated, time: .omitted))")
    }
    MetadataSection(metadata: product.metadata ?? [:])
  }

  @ViewBuilder
  private var pricesSection: some View {
    Section("Prices") {
      if prices.isEmpty {
        Text("No prices.")
          .foregroundStyle(.secondary)
          .accessibilityIdentifier("billing.prices.empty")
      } else {
        ForEach(prices, id: \.id) { price in
          if writer != nil {
            Button {
              editingPrice = EditingPrice(price: price)
            } label: {
              PriceRow(price: price)
            }
            .accessibilityIdentifier("billing.price.\(price.id)")
          } else {
            PriceRow(price: price)
              .accessibilityIdentifier("billing.price.\(price.id)")
          }
        }
      }
    }
  }
}

// MARK: - Rows

/// Identifiable wrapper so a tapped price row can drive `sheet(item:)`.
private struct EditingPrice: Identifiable {
  let price: Price
  var id: String { price.id }
}

/// One price row: formatted amount, billing interval, active state.
struct PriceRow: View {
  let price: Price

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
    if let nickname = price.nickname.valueOrNil, !nickname.isEmpty {
      return nickname
    }
    return amount
  }

  private var subtitle: String {
    var parts = [amount]
    if let recurring = price.recurring.valueOrNil {
      if recurring.intervalCount != 1 {
        parts.append("every \(recurring.intervalCount) \(recurring.interval.rawValue)s")
      } else {
        parts.append("per \(recurring.interval.rawValue)")
      }
    } else {
      parts.append("one-time")
    }
    if !price.active {
      parts.append("inactive")
    }
    return parts.joined(separator: " · ")
  }

  /// The formatted unit amount; falls back to the price ID when the
  /// amount is not set.
  var amount: String {
    if let unitAmount = price.unitAmount.valueOrNil {
      return MoneyFormat.amount(unitAmount, currency: price.currency)
    }
    return price.id
  }
}
