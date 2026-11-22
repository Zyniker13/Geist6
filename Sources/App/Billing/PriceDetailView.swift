import GeistData
import StripeModels
import SwiftUI

/// Detail view for a single price: the amount and billing terms, the product
/// it belongs to, and metadata. The edit action reuses `EditPriceSheet`
/// (Stripe prices are immutable in amount and currency — only nickname,
/// active, and metadata can change); the product link routes back to the
/// product's own detail screen.
struct PriceDetailView: View {
  let priceID: String
  let backend: any BillingBackend
  let writer: BillingWriteService?

  @State private var price: Price?
  @State private var editPresented = false
  @State private var writeResult: WriteResult?
  @State private var loadingError: String?

  var body: some View {
    Group {
      if let price {
        priceView(price)
      } else if let error = loadingError {
        ContentUnavailableView(
          "Couldn't load price",
          systemImage: "exclamationmark.triangle",
          description: Text(error)
        )
      } else {
        ProgressView()
      }
    }
    .navigationTitle("Price")
    .task { await loadPrice() }
    .toolbar {
      if writer != nil, price != nil {
        ToolbarItem(placement: .primaryAction) {
          Button("Edit") { editPresented = true }
            .accessibilityIdentifier("price.edit")
        }
      }
    }
    .sheet(isPresented: $editPresented) {
      if let price, let writer {
        EditPriceSheet(price: price, writer: writer, onFinished: handleWriteFinished)
      }
    }
    .writeResultAlert($writeResult)
  }

  private func loadPrice() async {
    do {
      price = try await backend.retrievePrice(id: priceID)
    } catch {
      loadingError = writeErrorMessage(error)
    }
  }

  private func handleWriteFinished(_ result: WriteResult) {
    editPresented = false
    writeResult = result
    Task {
      do {
        price = try await backend.retrievePrice(id: priceID)
      } catch {
        writeResult = WriteResult(
          title: "Refresh failed", message: writeErrorMessage(error))
      }
    }
  }

  @ViewBuilder
  private func priceView(_ price: Price) -> some View {
    Form {
      Section("Amount") {
        LabeledContent("Price", value: price.id)
        LabeledContent("Amount", value: PriceRow(price: price).amount)
        LabeledContent("Currency", value: price.currency.uppercased())
      }

      Section("Billing") {
        if let recurring = price.recurring.valueOrNil {
          if recurring.intervalCount != 1 {
            LabeledContent(
              "Recurring",
              value: "Every \(recurring.intervalCount) \(recurring.interval.rawValue)s")
          } else {
            LabeledContent("Recurring", value: "Per \(recurring.interval.rawValue)")
          }
          LabeledContent("Usage type", value: recurring.usageType.rawValue)
        } else {
          LabeledContent("Billing", value: "One-time")
        }
        LabeledContent("Type", value: price.type.rawValue)
        LabeledContent("Active", value: price.active ? "Yes" : "No")
      }

      Section("Product") {
        if let productID = BillingModel.priceProductID(price) {
          NavigationLink(value: BillingRoute.product(productID)) {
            LabeledContent("Product", value: productID)
          }
          .accessibilityIdentifier("price.product.\(productID)")
        } else {
          LabeledContent("Product", value: "—")
        }
      }

      MetadataSection(metadata: price.metadata ?? [:])
    }
  }
}
