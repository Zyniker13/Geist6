import GeistData
import StripeModels
import SwiftUI

/// Detail view for a single promotion code. Shows all fields and provides
/// edit (active flag + metadata) when the account allows writes.
/// Promotion codes cannot be deleted in Stripe — only deactivated.
struct PromotionCodeDetailView: View {
  let promotionCodeID: String
  let backend: any BillingBackend
  let writer: BillingWriteService?

  @State private var promotionCode: PromotionCode?
  @State private var editPresented = false
  @State private var writeResult: WriteResult?
  @State private var loadingError: String?

  var body: some View {
    Group {
      if let promotionCode {
        promoView(promotionCode)
      } else if let error = loadingError {
        ContentUnavailableView(
          "Couldn't load promotion code",
          systemImage: "exclamationmark.triangle",
          description: Text(error)
        )
      } else {
        ProgressView()
      }
    }
    .navigationTitle("Promotion code")
    .task { await loadPromotionCode() }
    .toolbar {
      if writer != nil {
        ToolbarItem(placement: .primaryAction) {
          Button("Edit") { editPresented = true }
            .accessibilityIdentifier("promo.edit")
        }
      }
    }
    .sheet(isPresented: $editPresented) {
      if let promotionCode, let writer {
        EditPromotionCodeSheet(
          promotionCode: promotionCode, writer: writer, onFinished: handleWriteFinished)
      }
    }
    .writeResultAlert($writeResult)
  }

  private func loadPromotionCode() async {
    do {
      promotionCode = try await backend.retrievePromotionCode(id: promotionCodeID)
    } catch {
      loadingError = writeErrorMessage(error)
    }
  }

  private func handleWriteFinished(_ result: WriteResult) {
    editPresented = false
    writeResult = nil
    Task {
      do {
        promotionCode = try await backend.retrievePromotionCode(id: promotionCodeID)
      } catch {
        writeResult = WriteResult(
          title: "Refresh failed", message: writeErrorMessage(error))
      }
    }
  }

  @ViewBuilder
  private func promoView(_ promo: PromotionCode) -> some View {
    Form {
      detailsSection(promo)
      couponSection(promo)
      limitsSection(promo)
      metadataSection(promo)
    }
  }

  @ViewBuilder
  private func detailsSection(_ promo: PromotionCode) -> some View {
    Section("Details") {
      Field("Code", promo.code)
      Field("ID", promo.id)
      Field("Active", promo.active ? "Yes" : "No")
    }
  }

  @ViewBuilder
  private func couponSection(_ promo: PromotionCode) -> some View {
    Section("Coupon") {
      if let couponName = promo.promotion.coupon.valueOrNil?.objectOrNil?.name.valueOrNil {
        Field("Coupon", couponName)
      }
      if let couponID = promo.promotion.coupon.valueOrNil?.idOrNil {
        Field("Coupon ID", couponID)
      }
    }
  }

  @ViewBuilder
  private func limitsSection(_ promo: PromotionCode) -> some View {
    Section("Limits") {
      Field("Times redeemed", "\(promo.timesRedeemed)")
      if let maxRedemptions = promo.maxRedemptions.valueOrNil {
        Field("Max redemptions", "\(maxRedemptions)")
      }
      if let expiresAt = promo.expiresAt.valueOrNil {
        Field("Expires at", expiresAt.date.formatted(date: .abbreviated, time: .omitted))
      }
      if let customer = promo.customer.valueOrNil {
        customerField(customer)
      }
    }
  }

  @ViewBuilder
  private func customerField(_ customer: PromotionCodeCustomer) -> some View {
    switch customer {
    case .string(let id):
      Field("Customer", id)
    case .customer(let customer):
      Field("Customer", customer.id)
    case .deletedCustomer(let deleted):
      Field("Customer", "\(deleted.id) (deleted)")
    case .other:
      EmptyView()
    }
  }

  @ViewBuilder
  private func metadataSection(_ promo: PromotionCode) -> some View {
    if let metadata = promo.metadata.valueOrNil, !metadata.isEmpty {
      Section("Metadata") {
        ForEach(metadata.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
          Field(key, value)
        }
      }
    }
  }
}

