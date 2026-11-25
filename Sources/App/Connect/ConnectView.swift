import GeistData
import StripeModels
import SwiftUI

// The app's local `Account` (Keychain-stored Stripe account) shadows
// Stripe's generated `Account` (a connected account) in this module, so
// the Stripe type is aliased explicitly.
typealias ConnectStripeAccount = StripeModels.Account

/// Pushes from the Connect screens onto the shell's navigation stack.
enum ConnectRoute: Hashable {
  case account(String)
  case fee(String)
}

/// The Connect screen of one platform account: the connected accounts
/// (list, detail with capabilities/persons/external accounts) and the
/// application fees the platform earned (M8, decision 0032).
///
/// The active connected account (the one a platform key's `Stripe-Account`
/// header targets) is always visible in a banner under the navigation bar.
struct ConnectView: View {
  let account: Account  // the app's local account (Keychain-stored)
  let backend: any ConnectBackend
  /// Nil for dashboard-locked accounts: no write controls are shown.
  let writer: ConnectWriteService?

  @State private var model: ConnectModel?
  @State private var path = NavigationPath()

  var body: some View {
    Group {
      if let model {
        content(model)
      } else {
        ProgressView()
      }
    }
    .navigationTitle("Connect")
    .navigationDestination(for: ConnectRoute.self) { route in
      switch route {
      case .account(let id):
        ConnectedAccountDetailView(accountID: id, backend: backend, writer: writer)
      case .fee(let id):
        ApplicationFeeDetailView(feeID: id, backend: backend, writer: writer)
      }
    }
    .task {
      if model == nil {
        model = ConnectModel(backend: backend)
      }
      await model?.load()
    }
    .refreshable {
      await model?.load()
    }
  }

  @ViewBuilder
  private func content(_ model: ConnectModel) -> some View {
    VStack(spacing: 0) {
      if model.keyIsNotPlatform {
        ContentUnavailableView(
          "Not a platform key",
          systemImage: "key.slash",
          description: Text(
            "This key cannot list connected accounts. Connect features need"
              + " a platform (Connect) key. Everything else still works.")
        )
      } else {
        list(model)
      }
    }
  }

  @ViewBuilder
  private func list(_ model: ConnectModel) -> some View {
    List {
      // The always-visible banner for the account this screen acts on
      // (M8 done-when). The connected accounts listed below belong to
      // this platform account.
      Section {
        HStack(spacing: 10) {
          Circle()
            .fill(AccountColor.color(for: account.color))
            .frame(width: 10, height: 10)
          VStack(alignment: .leading, spacing: 2) {
            Text(account.name)
              .lineLimit(1)
            Text(account.live ? "Live platform" : "Test platform")
              .font(.caption2)
              .foregroundStyle(account.live ? Color.red : Color.secondary)
          }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("connect.banner")
        .accessibilityLabel("Acting on \(account.name)")
      }

      Section("Connected accounts") {
        if let error = model.accountsError {
          Label(error, systemImage: "exclamationmark.triangle")
            .font(.caption)
            .foregroundStyle(.orange)
        } else if model.accounts.isEmpty {
          if model.phase == .loading {
            ProgressView()
          } else {
            Text("No connected accounts yet.")
              .foregroundStyle(.secondary)
          }
        } else {
          ForEach(model.accounts, id: \.id) { connected in
            NavigationLink(value: ConnectRoute.account(connected.id)) {
              ConnectedAccountRow(account: connected)
            }
          }
        }
      }

      Section("Application fees") {
        if let error = model.feesError {
          Label(error, systemImage: "exclamationmark.triangle")
            .font(.caption)
            .foregroundStyle(.orange)
        } else if model.fees.isEmpty {
          if model.phase == .loading {
            ProgressView()
          } else {
            Text("No application fees earned yet.")
              .foregroundStyle(.secondary)
          }
        } else {
          ForEach(model.fees, id: \.id) { fee in
            NavigationLink(value: ConnectRoute.fee(fee.id)) {
              ApplicationFeeRow(fee: fee)
            }
          }
        }
      }
    }
    .searchable(text: searchBinding(model), prompt: "Filter by ID, email, or business name")
  }

  private func searchBinding(_ model: ConnectModel) -> Binding<String> {
    Binding(
      get: { model.searchQuery },
      set: { model.setSearch($0) }
    )
  }
}

/// One connected account in the list.
struct ConnectedAccountRow: View {
  let account: ConnectStripeAccount

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      HStack {
        Text(Self.title(account))
          .lineLimit(1)
        Spacer()
        if account.chargesEnabled == true {
          Text("Charges")
            .font(.caption2.weight(.medium))
            .foregroundStyle(.green)
        }
        if account.payoutsEnabled == true {
          Text("Payouts")
            .font(.caption2.weight(.medium))
            .foregroundStyle(.green)
        }
      }
      Text(account.id)
        .font(.caption2)
        .foregroundStyle(.secondary)
      if let requirements = account.requirements,
        let disabled = requirements.disabledReason.valueOrNil
      {
        Text("Restricted: \(disabled.rawValue)")
          .font(.caption2)
          .foregroundStyle(.red)
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("connect.row.\(account.id)")
  }

  static func title(_ account: ConnectStripeAccount) -> String {
    let business = account.businessProfile?.valueOrNil?.name.valueOrNil
    let email = account.email?.valueOrNil
    return business ?? email ?? account.id
  }
}

/// The detail screen of one connected account: identity, capabilities,
/// persons, external accounts, and current requirements.
struct ConnectedAccountDetailView: View {
  let accountID: String
  let backend: any ConnectBackend
  /// Nil for dashboard-locked accounts: no write controls are shown.
  let writer: ConnectWriteService?

  @State private var account: ConnectStripeAccount?
  @State private var capabilities: [Capability] = []
  @State private var persons: [Person] = []
  @State private var banks: [BankAccount] = []
  @State private var accountError: String?
  @State private var capabilitiesError: String?
  @State private var personsError: String?
  @State private var banksError: String?
  @State private var phase: LoadPhase = .loading
  @State private var linkPresented = false
  @State private var linkResult: String?
  @State private var loginLinkPresented = false
  @State private var sessionPresented = false
  @State private var personPendingDelete: Person?
  @State private var bankPendingDelete: BankAccount?
  @State private var capabilityPendingToggle: Capability?
  @State private var writeResult: WriteResult?

  enum LoadPhase {
    case loading
    case loaded
  }

  var body: some View {
    List {
      if let error = accountError {
        Section {
          Label(error, systemImage: "exclamationmark.triangle")
            .font(.caption)
            .foregroundStyle(.orange)
        }
      } else if let account {
        identitySection(account)
        capabilitiesSection
        personsSection
        externalAccountsSection
        requirementsSection(account)
      }
    }
    .navigationTitle(Self.title)
    .navigationBarTitleDisplayMode(.inline)
    .task {
      await load()
    }
    .refreshable {
      await load()
    }
    .toolbar { actionsToolbar }
    .sheet(isPresented: $linkPresented) {
      if let writer {
        CreateAccountLinkSheet(accountID: accountID, writer: writer) { result in
          linkPresented = false
          writeResult = result
        }
      }
    }
    .sheet(isPresented: $loginLinkPresented) {
      if let writer {
        CreateLoginLinkSheet(accountID: accountID, writer: writer) { result in
          loginLinkPresented = false
          writeResult = result
        }
      }
    }
    .sheet(isPresented: $sessionPresented) {
      if let writer {
        CreateAccountSessionSheet(accountID: accountID, writer: writer) { result in
          sessionPresented = false
          writeResult = result
        }
      }
    }
    .confirmationDialog(
      "Remove this bank account from the connected account?",
      isPresented: Binding(
        get: { bankPendingDelete != nil },
        set: { if !$0 { bankPendingDelete = nil } }),
      titleVisibility: .visible
    ) {
      Button("Remove bank account", role: .destructive) {
        if let bank = bankPendingDelete { Task { await runDeleteBank(bank) } }
        bankPendingDelete = nil
      }
      .accessibilityIdentifier("connect.detail.deleteBank.run")
      Button("Keep bank account", role: .cancel) { bankPendingDelete = nil }
    }
    .confirmationDialog(
      "Delete this person from the connected account?",
      isPresented: Binding(
        get: { personPendingDelete != nil },
        set: { if !$0 { personPendingDelete = nil } }),
      titleVisibility: .visible
    ) {
      Button("Delete person", role: .destructive) {
        if let person = personPendingDelete { Task { await runDeletePerson(person) } }
        personPendingDelete = nil
      }
      .accessibilityIdentifier("connect.detail.deletePerson.run")
      Button("Keep person", role: .cancel) { personPendingDelete = nil }
    }
    .confirmationDialog(
      capabilityPendingToggle.map { capabilityTogglePrompt($0) } ?? "",
      isPresented: Binding(
        get: { capabilityPendingToggle != nil },
        set: { if !$0 { capabilityPendingToggle = nil } }),
      titleVisibility: .visible
    ) {
      Button(
        capabilityPendingToggle?.requested == true ? "Unrequest" : "Request",
        role: .destructive
      ) {
        if let capability = capabilityPendingToggle {
          Task { await runToggleCapability(capability) }
        }
        capabilityPendingToggle = nil
      }
      .accessibilityIdentifier("connect.detail.capability.run")
      Button("Keep as is", role: .cancel) { capabilityPendingToggle = nil }
    }
    .writeResultAlert($writeResult)
  }

  private func capabilityTogglePrompt(_ capability: Capability) -> String {
    capability.requested
      ? "Stop requesting \(capability.id) on this account?"
      : "Request the \(capability.id) capability on this account?"
  }

  @ToolbarContentBuilder
  private var actionsToolbar: some ToolbarContent {
    ToolbarItem(placement: .primaryAction) {
      if let writer, account != nil {
        Menu {
          Button("Create onboarding link…") { linkPresented = true }
            .accessibilityIdentifier("connect.detail.link")
          if let capability = capabilities.first(where: { $0.status != .active }) {
            Button(
              capability.requested ? "Unrequest \(capability.id)…" : "Request \(capability.id)…"
            ) {
              capabilityPendingToggle = capability
            }
            .accessibilityIdentifier("connect.detail.capability")
          }
          Button("Create login link…") { loginLinkPresented = true }
            .accessibilityIdentifier("connect.detail.loginLink")
          Button("Create account session…") { sessionPresented = true }
            .accessibilityIdentifier("connect.detail.session")
          if let person = persons.first {
            Button("Delete person…", role: .destructive) { personPendingDelete = person }
              .accessibilityIdentifier("connect.detail.deletePerson")
          }
          if let bank = banks.first {
            Button("Remove bank account…", role: .destructive) { bankPendingDelete = bank }
              .accessibilityIdentifier("connect.detail.deleteBank")
          }
        } label: {
          Label("Actions", systemImage: "ellipsis.circle")
        }
        .accessibilityIdentifier("connect.detail.actions")
      }
    }
  }

  private func runToggleCapability(_ capability: Capability) async {
    guard let writer else { return }
    do {
      _ = try await writer.updateCapability(
        account: accountID, capability: capability.id,
        requested: !capability.requested,
        summary: "\(capability.requested ? "Unrequest" : "Request") capability \(capability.id)")
      await loadCapabilities()
      writeResult = WriteResult(
        title: capability.requested ? "Capability unrequested" : "Capability requested",
        message: "\(capability.id) is now \(capability.requested ? "unrequested" : "requested").")
    } catch {
      writeResult = WriteResult(title: "Write failed", message: writeErrorMessage(error))
    }
  }

  private func runDeletePerson(_ person: Person) async {
    guard let writer else { return }
    do {
      _ = try await writer.deletePerson(
        account: accountID, person: person.id, summary: "Delete person \(person.id)")
      await loadPersons()
      writeResult = WriteResult(
        title: "Person deleted",
        message: "\(Self.personName(person)) was removed from the account.")
    } catch {
      writeResult = WriteResult(title: "Write failed", message: writeErrorMessage(error))
    }
  }

  private func runDeleteBank(_ bank: BankAccount) async {
    guard let writer else { return }
    do {
      _ = try await writer.deleteExternalAccount(
        account: accountID, id: bank.id, summary: "Remove bank account \(bank.id)")
      await loadBanks()
      writeResult = WriteResult(
        title: "Bank account removed",
        message: "\(bank.bankName.valueOrNil ?? "Bank account") ··\(bank.last4) was removed.")
    } catch {
      writeResult = WriteResult(title: "Write failed", message: writeErrorMessage(error))
    }
  }

  private static var title: String { "Connected account" }

  private func load() async {
    async let accountSettled: Void = loadAccount()
    async let capabilitiesSettled: Void = loadCapabilities()
    async let personsSettled: Void = loadPersons()
    async let banksSettled: Void = loadBanks()
    _ = await (accountSettled, capabilitiesSettled, personsSettled, banksSettled)
    phase = .loaded
  }

  private func loadAccount() async {
    do {
      account = try await backend.retrieveConnectedAccount(id: accountID)
      accountError = nil
    } catch {
      accountError = String(describing: error)
    }
  }

  private func loadCapabilities() async {
    do {
      capabilities = try await backend.accountCapabilities(account: accountID)
      capabilitiesError = nil
    } catch {
      capabilitiesError = String(describing: error)
    }
  }

  private func loadPersons() async {
    do {
      persons = try await backend.accountPersons(account: accountID)
      personsError = nil
    } catch {
      personsError = String(describing: error)
    }
  }

  private func loadBanks() async {
    do {
      banks = try await backend.accountExternalAccounts(account: accountID)
      banksError = nil
    } catch {
      banksError = String(describing: error)
    }
  }

  @ViewBuilder
  private func identitySection(_ account: ConnectStripeAccount) -> some View {
    Section("Identity") {
      row("ID", account.id, id: "connect.detail.id")
      row("Name", ConnectedAccountRow.title(account))
      row("Email", account.email?.valueOrNil)
      row("Country", account.country)
      row("Currency", account.defaultCurrency?.uppercased())
      row("Business type", account.businessType?.valueOrNil?.rawValue)
      row("Created", Self.date(account.created))
      row("Details submitted", account.detailsSubmitted.map { $0 ? "Yes" : "No" })
      HStack {
        Text("Charges")
        Spacer()
        Text(account.chargesEnabled == true ? "Enabled" : "Disabled")
          .foregroundStyle(account.chargesEnabled == true ? .green : .orange)
          .accessibilityIdentifier("connect.detail.charges")
      }
      HStack {
        Text("Payouts")
        Spacer()
        Text(account.payoutsEnabled == true ? "Enabled" : "Disabled")
          .foregroundStyle(account.payoutsEnabled == true ? .green : .orange)
          .accessibilityIdentifier("connect.detail.payouts")
      }
    }
  }

  @ViewBuilder
  private var capabilitiesSection: some View {
    Section("Capabilities") {
      if let error = capabilitiesError {
        Label(error, systemImage: "exclamationmark.triangle")
          .font(.caption)
          .foregroundStyle(.orange)
      } else if capabilities.isEmpty {
        Text(phase == .loading ? "Loading…" : "No capabilities requested.")
          .foregroundStyle(.secondary)
      } else {
        ForEach(capabilities, id: \.id) { capability in
          HStack {
            Text(capability.id)
            Spacer()
            Text(capability.status.rawValue)
              .font(.caption.weight(.medium))
              .foregroundStyle(Self.statusColor(capability.status))
              .accessibilityIdentifier("connect.capability.\(capability.id)")
          }
        }
      }
    }
  }

  @ViewBuilder
  private var personsSection: some View {
    Section("Persons") {
      if let error = personsError {
        Label(error, systemImage: "exclamationmark.triangle")
          .font(.caption)
          .foregroundStyle(.orange)
      } else if persons.isEmpty {
        Text(phase == .loading ? "Loading…" : "No persons on this account.")
          .foregroundStyle(.secondary)
      } else {
        ForEach(persons, id: \.id) { person in
          VStack(alignment: .leading, spacing: 2) {
            Text(Self.personName(person))
            Text(person.id)
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
        }
      }
    }
  }

  @ViewBuilder
  private var externalAccountsSection: some View {
    Section("External accounts") {
      if let error = banksError {
        Label(error, systemImage: "exclamationmark.triangle")
          .font(.caption)
          .foregroundStyle(.orange)
      } else if banks.isEmpty {
        Text(phase == .loading ? "Loading…" : "No external accounts.")
          .foregroundStyle(.secondary)
      } else {
        ForEach(banks, id: \.id) { bank in
          VStack(alignment: .leading, spacing: 2) {
            Text("\(bank.bankName.valueOrNil ?? "Bank account") ··\(bank.last4)")
            Text("\(bank.country) · \(bank.currency.uppercased())")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
        }
      }
    }
  }

  @ViewBuilder
  private func requirementsSection(_ account: ConnectStripeAccount) -> some View {
    Section("Requirements") {
      if let requirements = account.requirements {
        if let deadline = requirements.currentDeadline.valueOrNil {
          row("Current deadline", Self.date(deadline))
        }
        requirementList("Currently due", requirements.currentlyDue.valueOrNil)
        requirementList("Eventually due", requirements.eventuallyDue.valueOrNil)
        requirementList("Past due", requirements.pastDue.valueOrNil)
        requirementList("Pending verification", requirements.pendingVerification.valueOrNil)
        if let disabled = requirements.disabledReason.valueOrNil {
          row("Restricted", disabled.rawValue)
        }
      } else {
        Text("No requirements outstanding.")
          .foregroundStyle(.secondary)
      }
    }
  }

  @ViewBuilder
  private func requirementList(_ label: String, _ items: [String]?) -> some View {
    if let items, !items.isEmpty {
      VStack(alignment: .leading, spacing: 2) {
        Text(label)
          .font(.caption)
          .foregroundStyle(.secondary)
        ForEach(items, id: \.self) { item in
          Text(item)
            .font(.footnote)
            .monospaced()
        }
      }
      .accessibilityIdentifier(
        "connect.requirement.\(label.replacingOccurrences(of: " ", with: "-"))")
    }
  }

  private func row(_ label: String, _ value: String?, id: String? = nil) -> some View {
    HStack(alignment: .firstTextBaseline) {
      Text(label)
        .foregroundStyle(.secondary)
      Spacer()
      Text(value ?? "—")
        .multilineTextAlignment(.trailing)
        .accessibilityIdentifier(id ?? "")
    }
  }

  private static func personName(_ person: Person) -> String {
    let first = person.firstName?.valueOrNil ?? ""
    let last = person.lastName?.valueOrNil ?? ""
    let joined = "\(first) \(last)".trimmingCharacters(in: .whitespaces)
    return joined.isEmpty ? person.id : joined
  }

  private static func date(_ timestamp: StripeTimestamp?) -> String {
    guard let timestamp else { return "—" }
    return timestamp.date.formatted(date: .abbreviated, time: .omitted)
  }

  private static func statusColor(_ status: CapabilityStatus) -> Color {
    switch status {
    case .active: return .green
    case .pending, .inactive, .unrequested, .undocumented: return .orange
    }
  }
}

/// One application fee in the Connect screen's fee list.
struct ApplicationFeeRow: View {
  let fee: ApplicationFee

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(MoneyFormat.amount(fee.amount, currency: fee.currency))
        .monospacedDigit()
      Text(fee.id)
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("connect.fee.\(fee.id)")
  }
}

/// The detail screen of one application fee. Write: refund the fee
/// (management mode only; refused in dashboard mode by the service).
struct ApplicationFeeDetailView: View {
  let feeID: String
  let backend: any ConnectBackend
  /// Nil for dashboard-locked accounts: no write controls are shown.
  let writer: ConnectWriteService?

  @State private var fee: ApplicationFee?
  @State private var error: String?
  @State private var loaded = false
  @State private var refundPresented = false
  @State private var writeResult: WriteResult?

  private var fullyRefunded: Bool {
    guard let fee else { return false }
    return fee.refunded || fee.amountRefunded >= fee.amount
  }

  var body: some View {
    List {
      if let error {
        Section {
          Label(error, systemImage: "exclamationmark.triangle")
            .font(.caption)
            .foregroundStyle(.orange)
        }
      } else if let fee {
        Section("Fee") {
          row("ID", fee.id, id: "connect.feeDetail.id")
          row("Amount", MoneyFormat.amount(fee.amount, currency: fee.currency))
          row("Refunded", MoneyFormat.amount(fee.amountRefunded, currency: fee.currency))
          row("Created", fee.created.date.formatted(date: .abbreviated, time: .standard))
        }
        Section("Charge") {
          row("Charge", fee.charge.idOrNil)
        }
      }
    }
    .navigationTitle("Application fee")
    .navigationBarTitleDisplayMode(.inline)
    .task {
      do {
        fee = try await backend.retrieveApplicationFee(id: feeID)
        error = nil
      } catch {
        self.error = String(describing: error)
      }
      loaded = true
    }
    .toolbar { refundToolbar }
    .confirmationDialog(
      "Refund this application fee in full?",
      isPresented: $refundPresented, titleVisibility: .visible
    ) {
      Button("Refund fee", role: .destructive) {
        Task { await runRefund() }
      }
      .accessibilityIdentifier("connect.feeDetail.refundRun")
      Button("Keep fee", role: .cancel) {}
    }
    .writeResultAlert($writeResult)
  }

  @ToolbarContentBuilder
  private var refundToolbar: some ToolbarContent {
    ToolbarItem(placement: .primaryAction) {
      if let writer, let fee, !fullyRefunded {
        Button("Refund…", role: .destructive) { refundPresented = true }
          .accessibilityIdentifier("connect.feeDetail.refund")
      }
    }
  }

  private func runRefund() async {
    guard let writer, let fee else { return }
    do {
      let refund = try await writer.createFeeRefund(
        fee: fee.id, amount: nil, summary: "Refund application fee \(fee.id)")
      await reload()
      writeResult = WriteResult(
        title: "Fee refunded",
        message: "Refund \(refund.id) for "
          + MoneyFormat.amount(fee.amount, currency: fee.currency) + " is processing.")
    } catch {
      writeResult = WriteResult(title: "Write failed", message: writeErrorMessage(error))
    }
  }

  private func reload() async {
    do {
      fee = try await backend.retrieveApplicationFee(id: feeID)
      error = nil
    } catch {
      self.error = String(describing: error)
    }
    loaded = true
  }

  private func row(_ label: String, _ value: String?, id: String? = nil) -> some View {
    HStack(alignment: .firstTextBaseline) {
      Text(label)
        .foregroundStyle(.secondary)
      Spacer()
      Text(value ?? "—")
        .multilineTextAlignment(.trailing)
        .accessibilityIdentifier(id ?? "")
    }
  }
}
