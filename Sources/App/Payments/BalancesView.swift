import GeistData
import StripeModels
import SwiftUI

/// The balances screens (M7 tier 1): the account's balance by currency and
/// the balance-transaction ledger behind it.
///
/// The matrix marks BalanceTransaction list/retrieve tier 1 at M7 with
/// "balances screens (M7)"; `retrieveBalance()` was already tier 1 for the
/// home card (docs/metrics.md rule 4: balances are shown as Stripe reports
/// them, per currency, never recomputed). The backend is `PaymentsBackend`
/// only because the ledger detail needs `retrieveBalanceTransaction(id:)`;
/// every method used here is a read — no write reaches Stripe from this
/// screen tree, and the dashboard-mode guarantee is enforced by the shell.
struct BalancesView: View {
  let backend: any PaymentsBackend

  var body: some View {
    BalanceTransactionsView(backend: backend)
      .navigationTitle("Balances")
  }
}

/// Pushed from the balances list onto the stack the view lives in.
enum BalanceRoute: Hashable {
  case transaction(String)
}

/// The balances list: one line per currency from `GET /v1/balance`, then the
/// ledger from `GET /v1/balance_transactions`.
struct BalanceTransactionsView: View {
  let backend: any PaymentsBackend

  enum Phase: Equatable {
    case loading
    case loaded
    case failed(String)
  }

  @State private var phase: Phase = .loading
  @State private var balance: Balance?
  @State private var transactions: [BalanceTransaction] = []

  var body: some View {
    Group {
      switch phase {
      case .loading:
        ProgressView()
      case .failed(let message):
        ContentUnavailableView(
          "Couldn't load balances",
          systemImage: "exclamationmark.triangle",
          description: Text(message))
      case .loaded:
        list
      }
    }
    .navigationTitle("Balances")
    .navigationBarTitleDisplayMode(.inline)
    .navigationDestination(for: BalanceRoute.self) { route in
      switch route {
      case .transaction(let id):
        BalanceTransactionDetailView(transactionID: id, backend: backend)
      }
    }
    .refreshable { await load() }
    .task { await load() }
  }

  @ViewBuilder
  private var list: some View {
    List {
      if let balance {
        Section("Balance") {
          // Stripe reports balance lines per currency; show every currency
          // it returns, in the order it returns them (docs/metrics.md rule 5).
          ForEach(balance.available, id: \.currency) { amount in
            BalanceLineRow(
              currency: amount.currency,
              available: amount.amount,
              pending: pendingAmount(balance, currency: amount.currency))
          }
        }
      }
      Section("Ledger") {
        if transactions.isEmpty {
          Text("No balance transactions yet.")
            .foregroundStyle(.secondary)
        }
        ForEach(transactions, id: \.id) { transaction in
          NavigationLink(value: BalanceRoute.transaction(transaction.id)) {
            BalanceTransactionRow(transaction: transaction)
          }
        }
      }
    }
  }

  private func load() async {
    do {
      async let fetchedBalance = backend.retrieveBalance()
      async let fetchedTransactions = backend.balanceTransactions(
        created: nil, currency: nil)
      (balance, transactions) = try await (fetchedBalance, fetchedTransactions)
      phase = .loaded
    } catch {
      phase = .failed(DashboardModel.message(of: error))
    }
  }

  private func pendingAmount(_ balance: Balance, currency: String) -> Int {
    balance.pending.first { $0.currency == currency }?.amount ?? 0
  }
}

/// One currency line: available and pending, as Stripe reports them.
private struct BalanceLineRow: View {
  let currency: String
  let available: Int
  let pending: Int

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      Text(currency.uppercased())
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.secondary)
      Spacer(minLength: 12)
      VStack(alignment: .trailing, spacing: 2) {
        Text(MoneyFormat.amount(available, currency: currency))
          .font(.title3.weight(.semibold))
          .monospacedDigit()
        Text("Pending \(MoneyFormat.amount(pending, currency: currency))")
          .font(.caption)
          .foregroundStyle(.secondary)
          .monospacedDigit()
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("balances.line.\(currency)")
    .accessibilityLabel(
      "\(currency.uppercased()): available \(MoneyFormat.amount(available, currency: currency)), "
        + "pending \(MoneyFormat.amount(pending, currency: currency))")
  }
}

/// A balance-transaction ledger row.
struct BalanceTransactionRow: View {
  let transaction: BalanceTransaction

  var body: some View {
    PaymentRowCore(
      title: MoneyFormat.amount(transaction.net, currency: transaction.currency),
      status: transaction.status
    ) {
      PaymentRowCaption(symbol: "chart.bar.doc.horizontal", text: caption)
    }
    .accessibilityIdentifier("balances.row.\(transaction.id)")
  }

  private var caption: String {
    let date = transaction.created.date.formatted(date: .abbreviated, time: .omitted)
    let gross = MoneyFormat.amount(transaction.amount, currency: transaction.currency)
    let fee = MoneyFormat.amount(transaction.fee, currency: transaction.currency)
    if transaction.fee != 0 {
      return "\(date) · gross \(gross) · fee \(fee)"
    }
    return "\(date) · gross \(gross)"
  }
}

/// The detail screen for one balance transaction, fetched by ID. Every
/// balance transaction is a ledger fact about money, so it is read-only;
/// Stripe offers no writes on `/v1/balance_transactions/{id}`.
struct BalanceTransactionDetailView: View {
  enum Phase: Equatable {
    case loading
    case loaded(BalanceTransaction)
    case failed(String)
  }

  let transactionID: String
  let backend: any PaymentsBackend

  @State private var phase: Phase = .loading

  var body: some View {
    Group {
      switch phase {
      case .loading:
        ProgressView()
      case .failed(let message):
        ContentUnavailableView(
          "Couldn't load balance transaction",
          systemImage: "exclamationmark.triangle",
          description: Text(message))
      case .loaded(let transaction):
        details(transaction)
      }
    }
    .navigationTitle("Balance transaction")
    .navigationBarTitleDisplayMode(.inline)
    .task(id: transactionID) { await load() }
  }

  @ViewBuilder
  private func details(_ transaction: BalanceTransaction) -> some View {
    List {
      Section {
        HStack(alignment: .firstTextBaseline) {
          Text(MoneyFormat.amount(transaction.net, currency: transaction.currency))
            .font(.largeTitle.weight(.bold))
            .monospacedDigit()
          Spacer(minLength: 8)
          PaymentStatusBadge(text: transaction.status)
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("balances.detail.net")
      }

      Section("Ledger") {
        PaymentFactRow(label: "Gross", value: MoneyFormat.amount(transaction.amount, currency: transaction.currency))
        PaymentFactRow(label: "Fee", value: MoneyFormat.amount(transaction.fee, currency: transaction.currency))
        PaymentFactRow(label: "Type", value: transaction.type.rawValue)
        PaymentFactRow(label: "Status", value: transaction.status)
        PaymentFactRow(label: "Reporting category", value: transaction.reportingCategory)
        PaymentFactRow(label: "Available on", value: transaction.availableOn.date.formatted(date: .abbreviated, time: .omitted))
        PaymentFactRow(label: "Created", value: transaction.created.date.formatted(date: .abbreviated, time: .omitted))
        if let description = transaction.description.valueOrNil {
          PaymentFactRow(label: "Description", value: description)
        }
        if let source = transaction.source.valueOrNil?.idOrNil {
          PaymentFactRow(label: "Source", value: source)
        }
      }

    }
  }

  private func load() async {
    phase = .loading
    do {
      phase = .loaded(try await backend.retrieveBalanceTransaction(id: transactionID))
    } catch {
      phase = .failed(DashboardModel.message(of: error))
    }
  }
}
