import GeistData
import StripeModels
import SwiftUI

/// Detail view for a single coupon. Shows all fields and provides edit
/// and delete actions when the account allows writes.
struct CouponDetailView: View {
  let couponID: String
  let backend: any BillingBackend
  let writer: BillingWriteService?

  @State private var coupon: Coupon?
  @State private var editPresented = false
  @State private var deleteConfirm = false
  @State private var writeResult: WriteResult?
  @State private var loadingError: String?

  var body: some View {
    Group {
      if let coupon {
        couponView(coupon)
      } else if let error = loadingError {
        ContentUnavailableView(
          "Couldn't load coupon",
          systemImage: "exclamationmark.triangle",
          description: Text(error)
        )
      } else {
        ProgressView()
      }
    }
    .navigationTitle("Coupon")
    .task { await loadCoupon() }
    .toolbar {
      if writer != nil {
        ToolbarItem(placement: .primaryAction) {
          Button("Edit") { editPresented = true }
            .accessibilityIdentifier("coupon.edit")
        }
        ToolbarItem(placement: .destructiveAction) {
          Button("Delete", role: .destructive) { deleteConfirm = true }
            .accessibilityIdentifier("coupon.delete")
        }
      }
    }
    .alert("Delete coupon?", isPresented: $deleteConfirm) {
      Button("Delete", role: .destructive) {
        Task { await deleteCoupon() }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("This action cannot be undone.")
    }
    .sheet(isPresented: $editPresented) {
      if let coupon, let writer {
        EditCouponSheet(coupon: coupon, writer: writer, onFinished: handleWriteFinished)
      }
    }
    .writeResultAlert($writeResult)
  }

  private func loadCoupon() async {
    do {
      coupon = try await backend.retrieveCoupon(id: couponID)
    } catch {
      loadingError = writeErrorMessage(error)
    }
  }

  private func deleteCoupon() async {
    guard let writer else { return }
    do {
      _ = try await writer.deleteCoupon(id: couponID, summary: "Delete coupon \(couponID)")
      writeResult = WriteResult(title: "Coupon deleted", message: "\(couponID) was deleted.")
    } catch {
      writeResult = WriteResult(
        title: "Delete failed", message: writeErrorMessage(error))
    }
  }

  private func handleWriteFinished(_ result: WriteResult) {
    editPresented = false
    writeResult = nil
    Task {
      do {
        coupon = try await backend.retrieveCoupon(id: couponID)
      } catch {
        writeResult = WriteResult(
          title: "Refresh failed", message: writeErrorMessage(error))
      }
    }
  }

  @ViewBuilder
  private func couponView(_ coupon: Coupon) -> some View {
    Form {
      Section("Details") {
        if let name = coupon.name.valueOrNil {
          Field("Name", name)
        }
        Field("ID", coupon.id)
      }

      Section("Discount") {
        if let percentOff = coupon.percentOff.valueOrNil {
          Field("Percent off", "\(percentOff)%")
        }
        if let amountOff = coupon.amountOff.valueOrNil {
          Field("Amount off", "\(amountOff)")
          if let currency = coupon.currency.valueOrNil {
            Field("Currency", currency.uppercased())
          }
        }
      }

      Section("Duration") {
        Field("Duration", coupon.duration.displayString)
        if coupon.duration == .repeating, let months = coupon.durationInMonths.valueOrNil {
          Field("Months", "\(months)")
        }
        if let redeemBy = coupon.redeemBy.valueOrNil {
          Field("Redeem by", redeemBy.date.formatted(date: .abbreviated, time: .omitted))
        }
        if let maxRedemptions = coupon.maxRedemptions.valueOrNil {
          Field("Max redemptions", "\(maxRedemptions)")
        }
      }

      Section("Status") {
        Field("Valid", coupon.valid ? "Yes" : "No")
        Field("Times redeemed", "\(coupon.timesRedeemed)")
      }

      if let metadata = coupon.metadata.valueOrNil, !metadata.isEmpty {
        Section("Metadata") {
          ForEach(metadata.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
            Field(key, value)
          }
        }
      }
    }
  }
}

/// One label/value row shared by the billing detail views.
struct Field: View {
  let label: String
  let value: String

  init(_ label: String, _ value: String) {
    self.label = label
    self.value = value
  }

  var body: some View {
    HStack {
      Text(label)
        .foregroundStyle(.secondary)
      Spacer()
      Text(value)
    }
  }
}
