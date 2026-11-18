import GeistData
import StripeModels
import SwiftUI

/// A single status pill used across payments screens.
struct PaymentStatusBadge: View {
  let text: String

  var body: some View {
    Text(text)
      .font(.caption2.weight(.semibold))
      .padding(.horizontal, 7)
      .padding(.vertical, 2)
      .background(color.opacity(0.18), in: Capsule())
      .foregroundStyle(color)
  }

  private var color: Color {
    switch text {
    case "succeeded", "paid", "captured", "complete":
      return .green
    case "processing", "pending", "requires_capture", "unpaid":
      return .orange
    case "failed", "canceled", "requires_payment_method":
      return .red
    default:
      return .secondary
    }
  }
}

/// A dated line in the payment timeline.
struct PaymentTimelineRow: View {
  let entry: PaymentTimelineEntry

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: symbol)
        .foregroundStyle(color)
        .frame(width: 22)

      VStack(alignment: .leading, spacing: 2) {
        Text(entry.title)
          .font(.subheadline.weight(.medium))
        Text(entry.subtitle)
          .font(.caption)
          .foregroundStyle(.secondary)
        Text(entry.date, style: .date)
          .font(.caption2)
          .foregroundStyle(.tertiary)
      }
      Spacer(minLength: 0)
    }
    .accessibilityElement(children: .combine)
  }

  private var symbol: String {
    switch entry.kind {
    case .intent: return "bolt"
    case .charge: return "creditcard"
    case .refund: return "arrowshape.turn.up.left"
    case .dispute: return "exclamationmark.shield"
    case .balanceTransaction: return "chart.bar.doc.horizontal"
    }
  }

  private var color: Color {
    switch entry.kind {
    case .refund: return .orange
    case .dispute: return .red
    case .balanceTransaction: return .blue
    default: return .secondary
    }
  }
}

/// Builds the display strings for one timeline entry so the row stays thin.
private func timelineCopy(for entry: PaymentTimelineEntry) -> (String, String) {
  switch entry.kind {
  case .intent(let intent):
    return (
      "Payment intent \(intent.status.rawValue)",
      MoneyFormat.amount(intent.amount, currency: intent.currency)
    )
  case .charge(let charge):
    return (
      "Charge \(charge.status.rawValue)",
      MoneyFormat.amount(charge.amount, currency: charge.currency)
    )
  case .refund(let refund):
    return (
      "Refund \(refund.status.valueOrNil ?? "pending")",
      MoneyFormat.amount(refund.amount, currency: refund.currency)
    )
  case .dispute:
    return ("Dispute", "Opened against this charge")
  case .balanceTransaction(let btx):
    return (
      "Balance transaction",
      MoneyFormat.amount(btx.net, currency: btx.currency)
    )
  }
}

extension PaymentTimelineEntry {
  /// The row title, derived from the entry kind.
  var title: String { timelineCopy(for: self).0 }

  /// The row subtitle, usually an amount.
  var subtitle: String { timelineCopy(for: self).1 }
}
