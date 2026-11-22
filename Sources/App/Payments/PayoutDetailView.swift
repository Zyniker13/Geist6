import GeistData
import StripeModels
import SwiftUI

/// The detail screen for one payout. Shows the amount, status, arrival
/// date, and destination facts. Writes live behind the management-mode
/// gate: cancel (in-transit payouts), reverse (paid instant payouts), and
/// metadata editing.
struct PayoutDetailView: View {
  enum Phase: Equatable {
    case loading
    case loaded(Payout)
    case failed(String)
  }

  let payoutID: String
  let backend: any PaymentsBackend
  /// Nil for dashboard-locked accounts: no write controls are shown.
  let writer: PaymentsWriteService?

  @State private var phase: Phase = .loading
  @State private var cancelPresented = false
  @State private var reversePresented = false
  @State private var editPresented = false
  @State private var writeResult: WriteResult?
  @State private var transactions: [BalanceTransaction]?

  var body: some View {
    Group {
      switch phase {
      case .loading:
        ProgressView()
      case .failed(let message):
        ContentUnavailableView(
          "Couldn't load payout",
          systemImage: "exclamationmark.triangle",
          description: Text(message)
        )
      case .loaded(let payout):
        details(payout)
      }
    }
    .navigationTitle("Payout")
    .navigationBarTitleDisplayMode(.inline)
    .task(id: payoutID) { await load() }
    .toolbar { actionsToolbar }
    .sheet(isPresented: $editPresented) {
      if case .loaded(let payout) = phase, let writer {
        EditPayoutMetadataSheet(
          payout: payout, writer: writer, onFinished: handleWriteFinished)
      }
    }
    .confirmationDialog(
      "Cancel this payout? The funds return to your balance.",
      isPresented: $cancelPresented, titleVisibility: .visible
    ) {
      Button("Cancel payout", role: .destructive) {
        Task { await runCancel() }
      }
      .accessibilityIdentifier("payments.payoutDetail.cancelRun")
      Button("Keep payout", role: .cancel) {}
    }
    .confirmationDialog(
      "Reverse this payout? The funds return to your balance.",
      isPresented: $reversePresented, titleVisibility: .visible
    ) {
      Button("Reverse payout", role: .destructive) {
        Task { await runReverse() }
      }
      .accessibilityIdentifier("payments.payoutDetail.reverseRun")
      Button("Keep payout", role: .cancel) {}
    }
    .writeResultAlert($writeResult)
  }

  @ToolbarContentBuilder
  private var actionsToolbar: some ToolbarContent {
    ToolbarItem(placement: .primaryAction) {
      if let writer, case .loaded(let payout) = phase {
        Menu {
          Button("Edit metadata…") { editPresented = true }
            .accessibilityIdentifier("payments.payoutDetail.edit")
          if payout.status == "in_transit" || payout.status == "pending" {
            Button("Cancel payout…", role: .destructive) { cancelPresented = true }
              .accessibilityIdentifier("payments.payoutDetail.cancel")
          }
          if payout.status == "paid" {
            Button("Reverse payout…", role: .destructive) { reversePresented = true }
              .accessibilityIdentifier("payments.payoutDetail.reverse")
          }
        } label: {
          Label("Actions", systemImage: "ellipsis.circle")
        }
        .accessibilityIdentifier("payments.payoutDetail.actions")
      }
    }
  }

  private func handleWriteFinished(_ result: WriteResult) {
    editPresented = false
    writeResult = result
    Task { await load() }
  }

  private func runCancel() async {
    guard let writer, case .loaded(let payout) = phase else { return }
    do {
      _ = try await writer.cancelPayout(
        id: payout.id, summary: "Cancel payout \(payout.id)")
      // Reload first, then surface the result: setting writeResult before
      // the phase swap cancels the pending alert presentation.
      await load()
      writeResult = WriteResult(
        title: "Payout canceled",
        message: "Payout \(payout.id) is now canceled; the funds are back on your balance.")
    } catch {
      writeResult = WriteResult(title: "Write failed", message: writeErrorMessage(error))
    }
  }

  private func runReverse() async {
    guard let writer, case .loaded(let payout) = phase else { return }
    do {
      _ = try await writer.reversePayout(
        id: payout.id, summary: "Reverse payout \(payout.id)")
      await load()
      writeResult = WriteResult(
        title: "Payout reversed",
        message: "Payout \(payout.id) is reversing; the funds are back on your balance.")
    } catch {
      writeResult = WriteResult(title: "Write failed", message: writeErrorMessage(error))
    }
  }

  @ViewBuilder
  private func details(_ payout: Payout) -> some View {
    List {
      Section {
        HStack(alignment: .firstTextBaseline) {
          Text(MoneyFormat.amount(payout.amount, currency: payout.currency))
            .font(.largeTitle.weight(.bold))
          Spacer(minLength: 8)
          PaymentStatusBadge(text: payout.status)
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("payments.payout.amount")
      }

      MetadataSection(metadata: payout.metadata.valueOrNil ?? [:])
      Section("Details") {
        PaymentFactRow(
          label: "Arrival",
          value: payout.arrivalDate.date.formatted(date: .abbreviated, time: .omitted))
        PaymentFactRow(
          label: "Created",
          value: payout.created.date.formatted(date: .abbreviated, time: .omitted))
        PaymentFactRow(label: "Type", value: payout.type.rawValue)
        PaymentFactRow(label: "Method", value: payout.method)
        PaymentFactRow(label: "Destination", value: destinationID(payout.destination))
        PaymentFactRow(
          label: "Statement descriptor",
          value: payout.statementDescriptor.valueOrNil ?? "—")
        if let failureMessage = payout.failureMessage.valueOrNil {
          PaymentFactRow(label: "Failure", value: failureMessage)
        }
      }

      // The ledger entries behind this payout: the same balance transactions
      // Stripe's payout report reconciles against the payout amount. Fetched
      // with the `payout` list filter, so the list is Stripe's, not ours.
      Section("Transactions") {
        switch transactions {
        case nil:
          Text("Loading…").foregroundStyle(.secondary)
        case .some([]):
          Text("No balance transactions on this payout.")
            .foregroundStyle(.secondary)
        case .some(let rows):
          ForEach(rows, id: \.id) { transaction in
            BalanceTransactionRow(transaction: transaction)
          }
        }
      }
    }
  }

  private func load() async {
    phase = .loading
    transactions = nil
    do {
      let payout = try await backend.retrievePayout(id: payoutID)
      phase = .loaded(payout)
      do {
        transactions = try await backend.balanceTransactions(payout: payoutID)
      } catch {
        // The ledger is secondary detail; the payout facts stay visible.
        transactions = []
      }
    } catch {
      phase = .failed(String(describing: error))
    }
  }

  /// The destination as a plain ID (or "—" when absent).
  private func destinationID(_ destination: Nullable<PayoutDestination>) -> String {
    switch destination.valueOrNil {
    case .string(let id): return id
    case .externalAccount, .deletedExternalAccount: return "bank account"
    case .none, .other: return "—"
    }
  }
}

/// Edits a payout's metadata. Payouts carry no other mutable fields.
struct EditPayoutMetadataSheet: View {
  let payout: Payout
  let writer: PaymentsWriteService
  let onFinished: (WriteResult) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var metadataText: String
  @State private var confirmPresented = false
  @State private var running = false
  @State private var failureText: String?

  init(
    payout: Payout, writer: PaymentsWriteService,
    onFinished: @escaping (WriteResult) -> Void
  ) {
    self.payout = payout
    self.writer = writer
    self.onFinished = onFinished
    _metadataText = State(initialValue: formatMetadataLines(payout.metadata.valueOrNil ?? [:]))
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Edit payout") {
          LabeledContent("Payout", value: payout.id)
        }
        Section {
          TextEditor(text: $metadataText)
            .font(.system(.footnote, design: .monospaced))
            .frame(minHeight: 88)
            .accessibilityIdentifier("payments.payoutEdit.metadata")
        } header: {
          Text("Metadata")
        } footer: {
          Text(
            "One pair per line: key=value. Saving replaces all metadata; "
              + "an empty field clears every key."
          )
        }
        if let failureText {
          Section {
            Text(failureText)
              .font(.footnote)
              .foregroundStyle(.red)
              .accessibilityIdentifier("payments.write.error")
          }
        }
      }
      .navigationTitle("Edit")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            failureText = nil
            confirmPresented = true
          }
          .disabled(running)
          .accessibilityIdentifier("payments.payoutEdit.submit")
        }
      }
      .confirmationDialog(
        "Update " + payout.id + "?", isPresented: $confirmPresented,
        titleVisibility: .visible
      ) {
        Button("Save changes") {
          Task { await run() }
        }
        .accessibilityIdentifier("payments.payoutEdit.confirm")
        Button("Cancel", role: .cancel) {}
      }
    }
  }

  private func run() async {
    running = true
    failureText = nil
    do {
      let metadata = try MetadataLines.parse(metadataText)
      _ = try await writer.updatePayout(
        id: payout.id,
        metadata: metadata,
        summary: "Update payout " + payout.id)
      onFinished(WriteResult(title: "Payout updated", message: payout.id + " saved."))
    } catch {
      running = false
      failureText = writeErrorMessage(error)
    }
  }
}
