import GeistData
import SwiftUI

/// The payments filter editor (M4c-5, decision 0019). Shows only the
/// dimensions that mean something for the active segment; confirming hands
/// the draft back to the view, which re-loads through the model. Empty
/// fields are ignored. Date and customer narrow server-side; the rest trim
/// the fetched page.
struct PaymentsFilterSheet: View {
  let segment: PaymentsFilter.Segment
  let current: PaymentsFilter
  let onApply: (PaymentsFilter) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var draft: PaymentsFilter

  init(
    segment: PaymentsFilter.Segment,
    current: PaymentsFilter,
    onApply: @escaping (PaymentsFilter) -> Void
  ) {
    self.segment = segment
    self.current = current
    self.onApply = onApply
    _draft = State(initialValue: current)
  }

  var body: some View {
    NavigationStack {
      Form {
        filterSections
        Section {
          Text("Empty fields are ignored.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      }
      .navigationTitle("Filter")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
            .accessibilityIdentifier("payments.filter.cancel")
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Apply") {
            onApply(draft)
            dismiss()
          }
          .accessibilityIdentifier("payments.filter.apply")
        }
      }
      .safeAreaInset(edge: .bottom) {
        Button(role: .destructive) {
          draft = .none
        } label: {
          Text("Clear all")
            .frame(maxWidth: .infinity)
        }
        .disabled(draft.isEmpty)
        .accessibilityIdentifier("payments.filter.clear")
        .padding(.bottom, 8)
      }
    }
    .accessibilityIdentifier("payments.filter.sheet")
  }

  @ViewBuilder
  private var filterSections: some View {
    let fields = PaymentsFilter.fields(for: segment)

    if fields.contains(.dateRange) {
      createdSection
    }
    if fields.contains(.customer) {
      customerSection
    }
    if fields.contains(.status) {
      statusSection
    }
    if fields.contains(.amount) {
      amountSection
    }
    if fields.contains(.methodType) {
      methodTypeSection
    }
    if fields.contains(.linkActive) {
      activeSection
    }
  }

  private var createdSection: some View {
    Section("Created") {
      Toggle(
        "From",
        isOn: Binding(
          get: { draft.dateStart != nil },
          set: { draft.dateStart = $0 ? Self.defaultStart : nil }
        )
      )
      .accessibilityIdentifier("payments.filter.from")
      if draft.dateStart != nil {
        DatePicker(
          "Start", selection: Binding(
            get: { draft.dateStart ?? Self.defaultStart },
            set: { draft.dateStart = $0 }
          ),
          displayedComponents: .date
        )
      }
      Toggle(
        "Until",
        isOn: Binding(
          get: { draft.dateEnd != nil },
          set: { draft.dateEnd = $0 ? Self.defaultEnd : nil }
        )
      )
      .accessibilityIdentifier("payments.filter.until")
      if draft.dateEnd != nil {
        DatePicker(
          "End", selection: Binding(
            get: { draft.dateEnd ?? Self.defaultEnd },
            set: { draft.dateEnd = $0 }
          ),
          displayedComponents: .date
        )
      }
    }
  }

  private var customerSection: some View {
    Section("Customer") {
      TextField(
        "Customer ID",
        text: Binding(
          get: { draft.customer ?? "" },
          set: { draft.customer = $0.isEmpty ? nil : $0 }
        )
      )
      .textInputAutocapitalization(.never)
      .autocorrectionDisabled()
      .accessibilityIdentifier("payments.filter.customer")
    }
  }

  private var statusSection: some View {
    Section("Status") {
      Picker(
        "Status",
        selection: Binding(
          get: { draft.status ?? "" },
          set: { draft.status = $0.isEmpty ? nil : $0 }
        )
      ) {
        Text("Any").tag("")
        ForEach(statusOptions, id: \.self) { option in
          Text(option).tag(option)
        }
      }
      .accessibilityIdentifier("payments.filter.status")
    }
  }

  private var amountSection: some View {
    Section("Amount (smallest currency unit)") {
      TextField("Minimum", text: amountBinding(\.amountMin))
        .keyboardType(.numberPad)
        .accessibilityIdentifier("payments.filter.amountMin")
      TextField("Maximum", text: amountBinding(\.amountMax))
        .keyboardType(.numberPad)
        .accessibilityIdentifier("payments.filter.amountMax")
    }
  }

  private var methodTypeSection: some View {
    Section("Method type") {
      Picker(
        "Method type",
        selection: Binding(
          get: { draft.methodType ?? "" },
          set: { draft.methodType = $0.isEmpty ? nil : $0 }
        )
      ) {
        Text("Any").tag("")
        ForEach(Self.methodTypeOptions, id: \.self) { option in
          Text(option).tag(option)
        }
      }
      .accessibilityIdentifier("payments.filter.methodType")
    }
  }

  private var activeSection: some View {
    Section("Payment link") {
      Picker("Active", selection: activeBinding) {
        Text("Any").tag(ActiveChoice.any)
        Text("Active").tag(ActiveChoice.active)
        Text("Inactive").tag(ActiveChoice.inactive)
      }
      .accessibilityIdentifier("payments.filter.active")
    }
  }

  // MARK: - Options and bindings

  private enum ActiveChoice: Hashable {
    case any, active, inactive
  }

  private var activeBinding: Binding<ActiveChoice> {
    Binding(
      get: {
        switch draft.linkActive {
        case .some(true): return .active
        case .some(false): return .inactive
        case .none: return .any
        }
      },
      set: {
        switch $0 {
        case .active: draft.linkActive = true
        case .inactive: draft.linkActive = false
        case .any: draft.linkActive = nil
        }
      }
    )
  }

  private func amountBinding(_ keyPath: WritableKeyPath<PaymentsFilter, Int?>) -> Binding<String> {
    Binding(
      get: { draft[keyPath: keyPath].map(String.init) ?? "" },
      set: { draft[keyPath: keyPath] = Int($0) }
    )
  }

  /// Status raw values that exist in Stripe's API for each segment; empty
  /// when the segment's list has no status field.
  private var statusOptions: [String] {
    switch segment {
    case .paymentIntents:
      return [
        "succeeded", "processing", "requires_payment_method",
        "requires_confirmation", "requires_action", "requires_capture", "canceled",
      ]
    case .charges:
      return ["succeeded", "pending", "failed"]
    case .refunds:
      return ["pending", "requires_action", "succeeded", "canceled", "failed"]
    case .setupIntents:
      return [
        "requires_payment_method", "requires_confirmation", "requires_action",
        "processing", "succeeded", "canceled",
      ]
    case .paymentMethods, .paymentLinks:
      return []
    case .checkoutSessions:
      return ["open", "complete", "expired"]
    case .payouts:
      return ["paid", "pending", "in_transit", "canceled", "failed"]
    case .transfers:
      return []
    case .topups:
      return ["succeeded", "pending", "reversed", "failed"]
    case .reports:
      return ["succeeded", "pending", "failed"]
    }
  }

  private static let methodTypeOptions = [
    "card", "sepa_debit", "us_bank_account", "link", "ideal", "ach_debit",
  ]

  private static let defaultStart = Calendar.current.date(
    byAdding: .day, value: -30, to: Date()
  ) ?? Date()

  private static let defaultEnd = Calendar.current.date(
    byAdding: .day, value: 1, to: Date()
  ) ?? Date()
}
