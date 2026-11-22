import GeistData
import StripeModels
import SwiftUI

/// One payment list row: amount, status pill, and a caption line.
/// Internal so the balances screens (M7) reuse the same row shape.
struct PaymentRowCore<Caption: View>: View {
  let title: String
  let status: String
  @ViewBuilder let caption: Caption

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      HStack(alignment: .firstTextBaseline) {
        Text(title)
          .font(.subheadline.weight(.semibold))
        Spacer(minLength: 8)
        PaymentStatusBadge(text: status)
      }
      caption
    }
    .padding(.vertical, 2)
  }
}

/// A caption line with a leading glyph and secondary text.
/// Internal so the balances screens (M7) reuse the same caption shape.
struct PaymentRowCaption: View {
  let symbol: String
  let text: String

  var body: some View {
    Label(text, systemImage: symbol)
      .font(.caption)
      .foregroundStyle(.secondary)
      .lineLimit(1)
  }
}

/// A payment-intent list row.
struct PaymentIntentRow: View {
  let intent: PaymentIntent

  var body: some View {
    PaymentRowCore(
      title: MoneyFormat.amount(intent.amount, currency: intent.currency), status: intent.status.rawValue
    ) {
      let created = intent.created.date.formatted(date: .abbreviated, time: .omitted)
      PaymentRowCaption(symbol: "clock", text: "\(created) · \(intent.id)")
    }
    .accessibilityIdentifier("payments.row.\(intent.id)")
  }
}

/// A charge list row.
struct ChargeRow: View {
  let charge: Charge

  var body: some View {
    PaymentRowCore(
      title: MoneyFormat.amount(charge.amount, currency: charge.currency), status: charge.status.rawValue
    ) {
      PaymentRowCaption(symbol: "creditcard", text: cardCaption)
    }
    .accessibilityIdentifier("payments.row.\(charge.id)")
  }

  private var cardCaption: String {
    if let card = charge.paymentMethodDetails.valueOrNil?.card {
      return "\(card.brand.valueOrNil ?? "card") •••• \(card.last4.valueOrNil ?? "")"
    }
    return "\(charge.created.date.formatted(date: .abbreviated, time: .omitted))"
  }
}

/// A refund list row.
struct RefundRow: View {
  let refund: Refund

  var body: some View {
    PaymentRowCore(
      title: MoneyFormat.amount(refund.amount, currency: refund.currency),
      status: refund.status.valueOrNil ?? "pending"
    ) {
      PaymentRowCaption(
        symbol: "arrowshape.turn.up.left",
        text: refund.reason.valueOrNil?.rawValue ?? "no reason given"
      )
    }
    .accessibilityIdentifier("payments.row.\(refund.id)")
  }
}

/// A setup-intent list row.
struct SetupIntentRow: View {
  let intent: SetupIntent

  var body: some View {
    PaymentRowCore(title: intent.status.rawValue, status: intent.status.rawValue) {
      let created = intent.created.date.formatted(date: .abbreviated, time: .omitted)
      PaymentRowCaption(symbol: "clock", text: "\(created) · \(intent.usage)")
    }
    .accessibilityIdentifier("payments.row.\(intent.id)")
  }
}

/// A payment-method list row.
struct PaymentMethodRow: View {
  let method: PaymentMethod

  var body: some View {
    PaymentRowCore(title: method.type.rawValue, status: "saved") {
      PaymentRowCaption(symbol: "creditcard", text: cardCaption)
    }
    .accessibilityIdentifier("payments.row.\(method.id)")
  }

  private var cardCaption: String {
    if let card = method.card {
      return "\(card.brand) •••• \(card.last4)"
    }
    return "\(method.created.date.formatted(date: .abbreviated, time: .omitted))"
  }
}

/// A payment-link list row.
struct PaymentLinkRow: View {
  let link: PaymentLink

  var body: some View {
    PaymentRowCore(title: link.active ? "Active" : "Inactive", status: link.active ? "complete" : "canceled") {
      PaymentRowCaption(symbol: "link", text: link.url)
    }
    .accessibilityIdentifier("payments.row.\(link.id)")
  }
}

/// A checkout-session list row.
struct CheckoutSessionRow: View {
  let session: CheckoutSession

  var body: some View {
    PaymentRowCore(title: title, status: session.status.valueOrNil?.rawValue ?? "unknown") {
      PaymentRowCaption(symbol: "cart", text: caption)
    }
    .accessibilityIdentifier("payments.row.\(session.id)")
  }

  private var title: String {
    if let amount = session.amountTotal.valueOrNil, let currency = session.currency.valueOrNil {
      return MoneyFormat.amount(amount, currency: currency)
    }
    return session.mode.rawValue
  }

  private var caption: String {
    let email = session.customerDetails.valueOrNil?.email.valueOrNil
      ?? session.customerEmail.valueOrNil
    if let email, !email.isEmpty { return email }
    return session.created.date.formatted(date: .abbreviated, time: .omitted)
  }
}

/// One payouts-list row: amount, status, arrival date.
struct PayoutRow: View {
  let payout: Payout

  var body: some View {
    PaymentRowCore(title: MoneyFormat.amount(payout.amount, currency: payout.currency), status: payout.status) {
      PaymentRowCaption(symbol: "banknote", text: caption)
    }
    .accessibilityIdentifier("payments.row.\(payout.id)")
  }

  private var caption: String {
    let arrival = payout.arrivalDate.date.formatted(date: .abbreviated, time: .omitted)
    return "Arrives \(arrival)"
  }
}
