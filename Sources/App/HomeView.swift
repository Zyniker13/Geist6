import Charts
import GeistData
import GeistMetrics
import StripeClient
import SwiftUI

/// Pushes from the home dashboard onto the shell's navigation stack.
/// Value-based so the stack path owns the pushed content's identity
/// (decision 0016).
enum HomeRoute: Hashable {
  case payments
  case customers
  case event(String)
}

/// The home dashboard of one Stripe account: balances, period figures,
/// daily volume, payouts, and recent activity (decision 0011).
struct HomeView: View {
  let account: Account
  /// The shell's navigation path. Value-based pushes keep the pushed
  /// view's identity tied to the path entry instead of a closure that
  /// ancestor re-renders can re-evaluate (decision 0016).
  @Binding var path: NavigationPath

  @Environment(AccountStore.self) private var accountStore
  @State private var model: DashboardModel
  @State private var period: HomePeriod = .last30Days
  @State private var currency = "usd"
  @State private var paymentsClient: StripeClient
  @State private var writer: PaymentsWriteService?
  @State private var customersWriter: CustomersWriteService?

  private static let currencies = ["usd", "eur", "gbp", "cad", "aud", "jpy"]

  init(account: Account, path: Binding<NavigationPath>) {
    self.account = account
    _path = path
    // Built in init, not in .task: destination closures must be
    // unconditional from the first render (decision 0018) — a closure
    // that flips branches as @State settles makes SwiftUI rebuild the
    // pushed view and reset its state.
    let client = StripeClient(
      apiKey: account.apiKey,
      mode: account.dashboardLock ? .dashboard : .management,
      baseURL: AppConfig.effectiveBaseURL
    )
    _paymentsClient = State(initialValue: client)
    _model = State(initialValue: DashboardModel(backend: client))
  }

  private var reloadKey: String {
    "\(account.id.uuidString)|\(period.rawValue)|\(currency)"
  }

  var body: some View {
    Group {
      content(model)
    }
    .navigationTitle(account.name)
    .navigationBarTitleDisplayMode(.inline)
    .navigationDestination(for: HomeRoute.self) { route in
      switch route {
      case .payments:
        PaymentsView(account: account, backend: paymentsClient, writer: writer)
      case .customers:
        CustomersView(account: account, backend: paymentsClient, writer: customersWriter)
      case .event(let eventID):
        EventActivityDetailView(eventID: eventID, backend: model.backend)
      }
    }
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          path.append(HomeRoute.payments)
        } label: {
          Label("Payments", systemImage: "creditcard")
        }
        .accessibilityIdentifier("home.payments")
      }
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          path.append(HomeRoute.customers)
        } label: {
          Label("Customers", systemImage: "person.2")
        }
        .accessibilityIdentifier("home.customers")
      }
      ToolbarItem(placement: .topBarTrailing) {
        Picker("Period", selection: $period) {
          ForEach(HomePeriod.allCases) { option in
            Text(option.shortLabel).tag(option)
          }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("home.period")
      }
      ToolbarItem(placement: .topBarTrailing) {
        Menu {
          ForEach(Self.currencies, id: \.self) { code in
            Button {
              currency = code
            } label: {
              if currency == code {
                Label(code.uppercased(), systemImage: "checkmark")
              } else {
                Text(code.uppercased())
              }
            }
          }
        } label: {
          Text(currency.uppercased())
        }
        .accessibilityIdentifier("home.currency")
      }
    }
    .task(id: reloadKey) {
      // Gate 1: a writer exists only for accounts that are not
      // dashboard-locked. Locked accounts build no write path at all.
      if writer == nil, !account.dashboardLock {
        let auditDirectory = FileManager.default.urls(
          for: .applicationSupportDirectory, in: .userDomainMask
        ).first!.appendingPathComponent("Geist6/Audit", isDirectory: true)
        let storeBox = AccountStore.WeakStoreBox(accountStore)
        writer = PaymentsWriteService(
          client: paymentsClient, accountID: account.id.uuidString,
          accountName: account.name,
          audit: FileAuditStore(directory: auditDirectory),
          dashboardLocked: { [storeBox] in
            storeBox.store?.cached(id: account.id)?.dashboardLock ?? false
          })
        customersWriter = CustomersWriteService(
          client: paymentsClient, accountID: account.id.uuidString,
          accountName: account.name,
          audit: FileAuditStore(directory: auditDirectory),
          dashboardLocked: { [storeBox] in
            storeBox.store?.cached(id: account.id)?.dashboardLock ?? false
          })
      }
      await model.load(period: period, currency: currency)
    }
    .refreshable {
      await model.load(period: period, currency: currency)
    }
  }

  @ViewBuilder
  private func content(_ model: DashboardModel) -> some View {
    if let snapshot = model.snapshot {
      dashboard(snapshot, model: model)
    } else {
      switch model.phase {
      case .failed(let message):
        errorView(message, model: model)
      default:
        ProgressView()
          .padding(.top, 80)
      }
    }
  }

  private func dashboard(_ snapshot: HomeSnapshot, model: DashboardModel) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        if case .failed(let message) = model.phase {
          Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(.orange)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        balancesSection(snapshot.balances)
        figuresSection(snapshot.figures)
        volumeSection(snapshot.figures.dailyVolume)
        payoutsSection(snapshot.figures)
        activitySection(snapshot.figures.recentActivity)
      }
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private func balancesSection(_ balances: [HomeSnapshot.CurrencyBalance]) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Balances")
        .font(.title3)
        .fontWeight(.semibold)
      if balances.isEmpty {
        Text("No balance data.")
          .foregroundStyle(.secondary)
      }
      ForEach(balances) { balance in
        HStack(alignment: .firstTextBaseline) {
          Text(balance.currency.uppercased())
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
          Spacer()
          VStack(alignment: .trailing, spacing: 2) {
            Text(Self.money(balance.available))
              .font(.title3)
              .fontWeight(.semibold)
              .monospacedDigit()
            Text("Pending \(Self.money(balance.pending))")
              .font(.caption)
              .foregroundStyle(.secondary)
              .monospacedDigit()
          }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
          "\(balance.currency.uppercased()): available \(Self.money(balance.available)), "
            + "pending \(Self.money(balance.pending))"
        )
      }
    }
    .card()
  }

  private func figuresSection(_ figures: HomeFigures) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Period figures")
        .font(.title3)
        .fontWeight(.semibold)
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
        figure("Volume", Self.money(figures.volume))
        figure("Net", Self.money(figures.net))
        figure("Fees", Self.money(figures.fees))
        figure("Refunds", Self.money(figures.refunds))
        figure("Disputes", Self.money(figures.disputes))
        figure("Successful payments", "\(figures.successfulPayments)")
        figure("Failed payments", "\(figures.failedPayments)")
        figure("New customers", "\(figures.newCustomers)")
      }
    }
    .card()
  }

  private func figure(_ name: String, _ value: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(name)
        .font(.caption)
        .foregroundStyle(.secondary)
      Text(value)
        .font(.title3)
        .fontWeight(.semibold)
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(name): \(value)")
  }

  private func volumeSection(_ points: [DailyVolume]) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Daily volume")
        .font(.title3)
        .fontWeight(.semibold)
      if points.isEmpty {
        Text("No transactions in this period.")
          .foregroundStyle(.secondary)
      } else {
        Chart(points, id: \.day) { point in
          BarMark(
            x: .value("Day", point.day, unit: .day),
            y: .value("Volume", point.amount.majorUnits)
          )
        }
        .chartYAxis {
          AxisMarks(position: .leading)
        }
        .frame(height: 200)
        .accessibilityLabel("Daily volume chart, \(points.count) days")
      }
    }
    .card()
  }

  private func payoutsSection(_ figures: HomeFigures) -> some View {
    let rows = figures.upcomingPayouts + figures.inTransitPayouts
    return VStack(alignment: .leading, spacing: 8) {
      Text("Payouts")
        .font(.title3)
        .fontWeight(.semibold)
      if rows.isEmpty {
        Text("No upcoming or in-transit payouts.")
          .foregroundStyle(.secondary)
      }
      ForEach(rows, id: \.id) { payout in
        HStack {
          Text(payout.status == "pending" ? "Scheduled" : "In transit")
            .font(.subheadline)
            .foregroundStyle(.secondary)
          Spacer()
          Text(Self.money(payout.amount))
            .monospacedDigit()
          Text(payout.arrivalDate, style: .date)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
      }
    }
    .card()
  }

  private func activitySection(_ items: [ActivityItem]) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Recent activity")
        .font(.title3)
        .fontWeight(.semibold)
      if items.isEmpty {
        Text("No recent events.")
          .foregroundStyle(.secondary)
      }
      ForEach(items, id: \.self) { item in
        NavigationLink(value: HomeRoute.event(item.eventID)) {
          HStack(alignment: .firstTextBaseline) {
            Text(item.type)
              .font(.subheadline)
            Text(item.object)
              .font(.caption)
              .foregroundStyle(.secondary)
            Spacer()
            Text(item.created, format: .relative(presentation: .named))
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.activity.\(item.eventID)")
      }
    }
    .card()
  }

  private func errorView(_ message: String, model: DashboardModel) -> some View {
    ContentUnavailableView {
      Label("Could not load dashboard", systemImage: "wifi.exclamationmark")
    } description: {
      Text(message)
    } actions: {
      Button("Try again") {
        Task {
          await model.load(period: period, currency: currency)
        }
      }
    }
    .padding(.top, 60)
  }

  /// Formats money for display, honoring zero-decimal currencies.
  static func money(_ value: Money) -> String {
    MoneyFormat.string(value)
  }
}

private extension HomePeriod {
  var shortLabel: String {
    switch self {
    case .last7Days: "7D"
    case .last30Days: "30D"
    case .last90Days: "90D"
    case .last12Months: "12M"
    }
  }
}

extension View {
  /// The card background used by dashboard sections.
  func card() -> some View {
    padding(16)
      .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
  }
}
