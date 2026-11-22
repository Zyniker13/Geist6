import GeistData
import StripeModels
import SwiftUI

/// The detail screen for one transfer: money moved to a connected account.
/// Transfers are read-only here (reversals are an M8 Connect write), so the
/// screen shows facts plus the reversal list.
struct TransferDetailView: View {
  enum Phase: Equatable {
    case loading
    case loaded(Transfer)
    case failed(String)
  }

  let transferID: String
  let backend: any PaymentsBackend

  @State private var phase: Phase = .loading
  @State private var reversals: [TransferReversal]?

  var body: some View {
    Group {
      switch phase {
      case .loading:
        ProgressView()
      case .failed(let message):
        ContentUnavailableView(
          "Couldn't load transfer",
          systemImage: "exclamationmark.triangle",
          description: Text(message)
        )
      case .loaded(let transfer):
        details(transfer)
      }
    }
    .navigationTitle("Transfer")
    .navigationBarTitleDisplayMode(.inline)
    .task(id: transferID) { await load() }
  }

  @ViewBuilder
  private func details(_ transfer: Transfer) -> some View {
    List {
      Section {
        HStack(alignment: .firstTextBaseline) {
          Text(MoneyFormat.amount(transfer.amount, currency: transfer.currency))
            .font(.largeTitle.weight(.bold))
          Spacer(minLength: 8)
          if transfer.reversed {
            PaymentStatusBadge(text: "reversed")
          }
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("payments.transfer.amount")
      }

      MetadataSection(metadata: transfer.metadata.valueOrNil ?? [:])
      Section("Details") {
        PaymentFactRow(label: "Destination", value: destinationID(transfer.destination))
        PaymentFactRow(
          label: "Created",
          value: transfer.created.date.formatted(date: .abbreviated, time: .omitted))
        PaymentFactRow(label: "Amount reversed", value: "\(transfer.amountReversed)")
        if transfer.reversed {
          PaymentFactRow(label: "Fully reversed", value: "Yes")
        }
        if let source = transfer.sourceTransaction.valueOrNil {
          PaymentFactRow(label: "Source transaction", value: source.idOrNil ?? "(expanded)")
        }
        if let group = transfer.transferGroup.valueOrNil {
          PaymentFactRow(label: "Transfer group", value: group)
        }
      }

      // Reversals are the transfers ledger: each one returns part of the
      // amount to the platform balance. Secondary load, like the payout's
      // transactions section.
      Section("Reversals") {
        switch reversals {
        case nil:
          Text("Loading…").foregroundStyle(.secondary)
        case .some([]):
          Text("No reversals on this transfer.")
            .foregroundStyle(.secondary)
        case .some(let rows):
          ForEach(rows, id: \.id) { reversal in
            TransferReversalRow(reversal: reversal)
          }
        }
      }
    }
  }

  private func load() async {
    phase = .loading
    reversals = nil
    do {
      let transfer = try await backend.retrieveTransfer(id: transferID)
      phase = .loaded(transfer)
      do {
        reversals = try await backend.transferReversals(transfer: transferID)
      } catch {
        // The reversal list is secondary detail; the facts stay visible.
        reversals = []
      }
    } catch {
      phase = .failed(String(describing: error))
    }
  }

  /// The destination as a plain ID (or "—" when absent).
  private func destinationID(_ destination: Nullable<Expandable<Account>>) -> String {
    switch destination.valueOrNil {
    case .id(let id): return id
    case .object(let account): return account.id
    }
  }
}

/// The detail screen for one top-up: money added to the Stripe balance.
/// Top-ups are read-only here; creation is an M10-tier action.
struct TopupDetailView: View {
  enum Phase: Equatable {
    case loading
    case loaded(Topup)
    case failed(String)
  }

  let topupID: String
  let backend: any PaymentsBackend

  @State private var phase: Phase = .loading

  var body: some View {
    Group {
      switch phase {
      case .loading:
        ProgressView()
      case .failed(let message):
        ContentUnavailableView(
          "Couldn't load top-up",
          systemImage: "exclamationmark.triangle",
          description: Text(message)
        )
      case .loaded(let topup):
        details(topup)
      }
    }
    .navigationTitle("Top-up")
    .navigationBarTitleDisplayMode(.inline)
    .task(id: topupID) { await load() }
  }

  @ViewBuilder
  private func details(_ topup: Topup) -> some View {
    List {
      Section {
        HStack(alignment: .firstTextBaseline) {
          Text(MoneyFormat.amount(topup.amount, currency: topup.currency))
            .font(.largeTitle.weight(.bold))
          Spacer(minLength: 8)
          PaymentStatusBadge(text: topup.status.rawValue)
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("payments.topup.amount")
      }

      MetadataSection(metadata: topup.metadata.valueOrNil ?? [:])
      Section("Details") {
        PaymentFactRow(
          label: "Created",
          value: topup.created.date.formatted(date: .abbreviated, time: .omitted))
        if let availability = topup.expectedAvailabilityDate.valueOrNil {
          PaymentFactRow(
            label: "Arrival",
            value: Date(timeIntervalSince1970: TimeInterval(availability)).formatted(
              date: .abbreviated, time: .omitted))
        }
        if let description = topup.description.valueOrNil {
          PaymentFactRow(label: "Description", value: description)
        }
        if let statement = topup.statementDescriptor.valueOrNil {
          PaymentFactRow(label: "Statement descriptor", value: statement)
        }
      }
    }
  }

  private func load() async {
    phase = .loading
    do {
      phase = .loaded(try await backend.retrieveTopup(id: topupID))
    } catch {
      phase = .failed(String(describing: error))
    }
  }
}
