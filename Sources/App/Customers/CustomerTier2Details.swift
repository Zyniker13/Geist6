import GeistData
import StripeModels
import SwiftUI

/// The customers filter editor (decision 0026, mirroring the payments
/// filter of decision 0019): a created range and an exact email match.
/// The range narrows server-side; the email trims the fetched page.
struct CustomersFilterSheet: View {
  let current: CustomersFilter
  let onApply: (CustomersFilter) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var draft: CustomersFilter

  init(current: CustomersFilter, onApply: @escaping (CustomersFilter) -> Void) {
    self.current = current
    self.onApply = onApply
    _draft = State(initialValue: current)
  }

  var body: some View {
    NavigationStack {
      Form {
        createdSection
        emailSection
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
            .accessibilityIdentifier("customers.filter.cancel")
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Apply") {
            onApply(draft)
            dismiss()
          }
          .accessibilityIdentifier("customers.filter.apply")
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
        .accessibilityIdentifier("customers.filter.clear")
        .padding(.bottom, 8)
      }
    }
    .accessibilityIdentifier("customers.filter.sheet")
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
      .accessibilityIdentifier("customers.filter.from")
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
      .accessibilityIdentifier("customers.filter.until")
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

  private var emailSection: some View {
    Section("Email") {
      TextField(
        "Exact address",
        text: Binding(
          get: { draft.email ?? "" },
          set: { draft.email = $0.isEmpty ? nil : $0 }
        )
      )
      .textInputAutocapitalization(.never)
      .autocorrectionDisabled()
      .accessibilityIdentifier("customers.filter.email")
    }
  }

  private static let defaultStart = Calendar.current.date(
    byAdding: .day, value: -30, to: Date()
  ) ?? Date()

  private static let defaultEnd = Calendar.current.date(
    byAdding: .day, value: 1, to: Date()
  ) ?? Date()
}

/// The detail screen for one tax ID, reached from the account-wide tax-ID
/// segment. Stripe's API updates tax IDs only indirectly (delete and
/// re-create), so the only write here is delete, behind the writer gate.
struct TaxIDDetailScreen: View {
  enum Phase: Equatable {
    case loading
    case loaded(TaxId)
    case failed(String)
  }

  let taxIDID: String
  let backend: any CustomersBackend
  let writer: CustomersWriteService?

  @State private var phase: Phase = .loading
  @State private var writeResult: WriteResult?
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    Group {
      switch phase {
      case .loading:
        ProgressView()
      case .failed(let message):
        ContentUnavailableView(
          "Couldn't load tax ID",
          systemImage: "exclamationmark.triangle",
          description: Text(message)
        )
      case .loaded(let taxID):
        details(taxID)
      }
    }
    .navigationTitle("Tax ID")
    .navigationBarTitleDisplayMode(.inline)
    .task(id: taxIDID) { await load() }
    .writeResultAlert($writeResult)
  }

  private func load() async {
    phase = .loading
    do {
      phase = .loaded(try await backend.retrieveTaxID(customer: nil, id: taxIDID))
    } catch {
      phase = .failed(String(describing: error))
    }
  }

  @ViewBuilder
  private func details(_ taxID: TaxId) -> some View {
    List {
      Section {
        HStack(alignment: .firstTextBaseline) {
          Text(taxID.type.rawValue)
            .font(.title3.weight(.semibold))
          Spacer(minLength: 8)
          if let writer {
            Button(role: .destructive) {
              Task {
                do {
                  let owner = taxID.owner.valueOrNil?.customer?.idOrNil ?? ""
                  _ = try await writer.deleteTaxID(
                    customer: owner, id: taxID.id, summary: "Deleted from detail screen"
                  )
                  writeResult = WriteResult(
                    title: "Tax ID deleted", message: "\(taxID.id) deleted.")
                  dismiss()
                } catch {
                  writeResult = WriteResult(
                    title: "Delete failed", message: writeErrorMessage(error))
                }
              }
            } label: {
              Label("Delete", systemImage: "trash")
            }
            .accessibilityIdentifier("customers.taxID.delete")
          }
        }
        .padding(.vertical, 4)
      }

      Section("Details") {
        PaymentFactRow(label: "ID", value: taxID.id)
        if !taxID.value.isEmpty {
          PaymentFactRow(label: "Value", value: taxID.value)
        }
        if let country = taxID.country.valueOrNil {
          PaymentFactRow(label: "Country", value: country)
        }
        PaymentFactRow(
          label: "Created",
          value: taxID.created.date.formatted(date: .abbreviated, time: .omitted))
        if let owner = taxID.owner.valueOrNil?.customer?.idOrNil {
          PaymentFactRow(label: "Customer", value: owner)
        }
      }
    }
  }
}
