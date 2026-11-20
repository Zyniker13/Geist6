import GeistData
import StripeModels
import SwiftUI

/// The detail screen for one customer: profile facts, metadata, discount,
/// and the payment-method, balance-transaction, cash-balance, tax-ID and
/// source lists, plus the customer money verbs (balance-transaction create,
/// funding instructions, fund cash balance). Read-only fetches through the
/// backend; writes only when a writer was passed.
struct CustomerDetailScreen: View {
  enum Phase: Equatable {
    case loading
    case loaded(Customer)
    case failed(String)
  }

  let customerID: String
  let backend: any CustomersBackend
  /// Nil for dashboard-locked accounts: no write controls are shown.
  let writer: CustomersWriteService?

  @State private var phase: Phase = .loading
  @State private var paymentMethods: [PaymentMethod] = []
  @State private var paymentMethodsFailed = false
  @State private var balanceTransactions: [CustomerBalanceTransaction] = []
  @State private var balanceTransactionsFailed = false
  @State private var taxIDs: [TaxId] = []
  @State private var taxIDsFailed = false
  @State private var sources: [PaymentSource] = []
  @State private var sourcesFailed = false
  @State private var discount: Discount?
  @State private var editPresented = false
  @State private var balanceTxPresented = false
  @State private var addTaxIDPresented = false
  @State private var fundingPresented = false
  @State private var fundCashPresented = false
  @State private var deleteDiscountPresented = false
  @State private var deletePresented = false
  @State private var editingTransaction: EditableTransaction?
  @State private var deletingTaxID: TaxId?
  @State private var writeResult: WriteResult?

  var body: some View {
    Group {
      switch phase {
      case .loading:
        ProgressView()
      case .failed(let message):
        ContentUnavailableView(
          "Couldn't load customer",
          systemImage: "exclamationmark.triangle",
          description: Text(message)
        )
      case .loaded(let customer):
        details(customer)
      }
    }
    .navigationTitle("Customer")
    .navigationBarTitleDisplayMode(.inline)
    .task(id: customerID) { await load() }
    .toolbar { actionsToolbar }
    .sheet(isPresented: $editPresented) {
      if case .loaded(let customer) = phase, let writer {
        EditCustomerSheet(customer: customer, writer: writer, onFinished: handleWriteFinished)
      }
    }
    .sheet(isPresented: $balanceTxPresented) {
      if let writer {
        CreateBalanceTransactionSheet(
          customerID: customerID, writer: writer, onFinished: handleWriteFinished)
      }
    }
    .sheet(isPresented: $addTaxIDPresented) {
      if let writer {
        AddTaxIDSheet(
          writer: writer, customerID: customerID, onFinished: handleWriteFinished)
      }
    }
    .sheet(isPresented: $fundingPresented) {
      if let writer {
        FundingInstructionsSheet(
          customerID: customerID, writer: writer, onFinished: handleWriteFinished)
      }
    }
    .sheet(isPresented: $fundCashPresented) {
      if let writer {
        FundCashBalanceSheet(
          customerID: customerID, writer: writer, onFinished: handleWriteFinished)
      }
    }
    .sheet(item: $editingTransaction) { edit in
      if let writer {
        EditBalanceTransactionSheet(
          transaction: edit.transaction, writer: writer,
          onFinished: handleWriteFinished)
      }
    }
    .confirmationDialog(
      "Delete the customer discount?",
      isPresented: $deleteDiscountPresented, titleVisibility: .visible
    ) {
      Button("Delete discount", role: .destructive) {
        Task { await runDeleteDiscount() }
      }
      Button("Cancel", role: .cancel) {}
    }
    .confirmationDialog(
      "Delete this customer? This cannot be undone.",
      isPresented: $deletePresented, titleVisibility: .visible
    ) {
      Button("Delete customer", role: .destructive) {
        Task { await runDeleteCustomer() }
      }
      Button("Cancel", role: .cancel) {}
    }
    .confirmationDialog(
      taxIDDeletePrompt,
      isPresented: Binding(
        get: { deletingTaxID != nil },
        set: { if !$0 { deletingTaxID = nil } }
      ), titleVisibility: .visible
    ) {
      Button("Delete tax ID", role: .destructive) {
        if let taxID = deletingTaxID {
          Task { await runDeleteTaxID(taxID) }
        }
      }
      Button("Cancel", role: .cancel) {}
    }
    .writeResultAlert($writeResult)
  }

  private var taxIDDeletePrompt: String {
    if let taxID = deletingTaxID {
      return "Delete tax ID \(taxID.type.rawValue) for this customer?"
    }
    return "Delete tax ID?"
  }

  @ToolbarContentBuilder
  private var actionsToolbar: some ToolbarContent {
    ToolbarItem(placement: .primaryAction) {
      if let writer, case .loaded = phase {
        Menu {
          Button("Edit customer…") { editPresented = true }
            .accessibilityIdentifier("customers.detail.edit")
          Button("Create balance transaction…") { balanceTxPresented = true }
            .accessibilityIdentifier("customers.detail.balanceTx")
          Button("Add tax ID…") { addTaxIDPresented = true }
            .accessibilityIdentifier("customers.detail.addTaxID")
          Button("Create funding instructions…") { fundingPresented = true }
            .accessibilityIdentifier("customers.detail.funding")
          Button("Fund cash balance…") { fundCashPresented = true }
            .accessibilityIdentifier("customers.detail.fundCash")
          if discount != nil {
            Button("Delete discount…", role: .destructive) {
              deleteDiscountPresented = true
            }
            .accessibilityIdentifier("customers.detail.deleteDiscount")
          }
          Button("Delete customer…", role: .destructive) { deletePresented = true }
            .accessibilityIdentifier("customers.detail.delete")
        } label: {
          Label("Actions", systemImage: "ellipsis.circle")
        }
        .accessibilityIdentifier("customers.detail.actions")
      }
    }
  }

  private func load() async {
    phase = .loading
    do {
      let customer = try await backend.retrieveCustomer(id: customerID)
      phase = .loaded(customer)
      discount = customer.discount?.valueOrNil
    } catch {
      phase = .failed(String(describing: error))
      return
    }
    await loadSections()
  }

  /// Loads the per-customer sub-lists after the customer itself. A failure
  /// in one section marks just that section failed, so the rest still show.
  private func loadSections() async {
    do {
      paymentMethods = try await backend.customerPaymentMethods(customer: customerID, type: nil)
      paymentMethodsFailed = false
    } catch {
      paymentMethodsFailed = true
    }
    do {
      balanceTransactions = try await backend.customerBalanceTransactions(customer: customerID)
      balanceTransactionsFailed = false
    } catch {
      balanceTransactionsFailed = true
    }
    do {
      taxIDs = try await backend.taxIDs(customer: customerID)
      taxIDsFailed = false
    } catch {
      taxIDsFailed = true
    }
    do {
      sources = try await backend.customerPaymentSources(customer: customerID)
      sourcesFailed = false
    } catch {
      sourcesFailed = true
    }
  }

  private func handleWriteFinished(_ result: WriteResult) {
    editPresented = false
    balanceTxPresented = false
    addTaxIDPresented = false
    fundingPresented = false
    fundCashPresented = false
    editingTransaction = nil
    writeResult = result
    Task { await load() }
  }

  private func runDeleteCustomer() async {
    guard let writer else { return }
    do {
      _ = try await writer.deleteCustomer(id: customerID, summary: "Delete \(customerID)")
      writeResult = WriteResult(
        title: "Customer deleted", message: "Delete request sent for \(customerID).")
      await load()
    } catch {
      writeResult = WriteResult(title: "Write failed", message: writeErrorMessage(error))
    }
  }

  private func runDeleteDiscount() async {
    guard let writer else { return }
    do {
      _ = try await writer.deleteDiscount(customer: customerID, summary: "Delete discount")
      writeResult = WriteResult(
        title: "Discount deleted", message: "Delete request sent for the discount.")
      await load()
    } catch {
      writeResult = WriteResult(title: "Write failed", message: writeErrorMessage(error))
    }
  }

  private func runDeleteTaxID(_ taxID: TaxId) async {
    guard let writer else { return }
    do {
      _ = try await writer.deleteTaxID(
        customer: customerID, id: taxID.id, summary: "Delete \(taxID.id)")
      writeResult = WriteResult(
        title: "Tax ID deleted", message: "Delete request sent for \(taxID.id).")
      await load()
    } catch {
      writeResult = WriteResult(title: "Write failed", message: writeErrorMessage(error))
    }
  }

  @ViewBuilder
  private func details(_ customer: Customer) -> some View {
    List {
      header(customer)
      factsSection(customer)
      MetadataSection(metadata: customer.metadata ?? [:])
      discountSection(customer)
      paymentMethodsSection
      balanceTransactionsSection
      cashBalanceSection
      taxIDsSection
      sourcesSection
    }
  }

  @ViewBuilder
  private func header(_ customer: Customer) -> some View {
    Section {
      VStack(alignment: .leading, spacing: 4) {
        Text(
          customer.name?.valueOrNil
            ?? customer.email.valueOrNil
            ?? customer.id
        )
        .font(.title2.weight(.bold))
        if customer.name?.valueOrNil != nil || customer.email.valueOrNil != nil {
          Text(customer.id)
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .textSelection(.enabled)
        }
      }
      .padding(.vertical, 4)
      .accessibilityIdentifier("customers.detail.name")
    }
  }

  @ViewBuilder
  private func factsSection(_ customer: Customer) -> some View {
    Section("Details") {
      PaymentFactRow(
        label: "Created",
        value: "\(customer.created.date.formatted(date: .abbreviated, time: .omitted))")
      if let email = customer.email.valueOrNil, !email.isEmpty {
        PaymentFactRow(label: "Email", value: email)
      }
      if let phone = customer.phone?.valueOrNil, !phone.isEmpty {
        PaymentFactRow(label: "Phone", value: phone)
      }
      if let description = customer.description.valueOrNil, !description.isEmpty {
        PaymentFactRow(label: "Description", value: description)
      }
      if let balance = customer.balance, balance != 0 {
        PaymentFactRow(label: "Balance", value: "\(balance)")
      }
      if let currency = customer.currency?.valueOrNil, !currency.isEmpty {
        PaymentFactRow(label: "Currency", value: currency)
      }
      PaymentFactRow(label: "Mode", value: customer.livemode ? "Live" : "Test")
    }
  }

  @ViewBuilder
  private func discountSection(_ customer: Customer) -> some View {
    Section("Discount") {
      if let discount, let coupon = discount.source.coupon.valueOrNil?.objectOrNil {
        VStack(alignment: .leading, spacing: 2) {
          Text(coupon.id)
            .font(.subheadline.weight(.medium))
          if let name = coupon.name.valueOrNil, !name.isEmpty {
            Text(name)
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
          if let percentOff = coupon.percentOff.valueOrNil, percentOff > 0 {
            Text("\(percentOff)% off")
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
        }
        .accessibilityIdentifier("customers.detail.discount")
      } else {
        Text("None")
          .foregroundStyle(.secondary)
      }
    }
  }

  @ViewBuilder
  private var paymentMethodsSection: some View {
    Section("Payment methods") {
      if paymentMethodsFailed {
        Text("Couldn't load payment methods.")
          .foregroundStyle(.secondary)
      } else if paymentMethods.isEmpty {
        Text("None")
          .foregroundStyle(.secondary)
      } else {
        ForEach(paymentMethods, id: \.id) { method in
          VStack(alignment: .leading, spacing: 2) {
            Text(methodPreviewLabel(method))
              .font(.subheadline.weight(.medium))
            Text(method.id)
              .font(.caption)
              .foregroundStyle(.secondary)
              .textSelection(.enabled)
          }
        }
      }
    }
  }

  @ViewBuilder
  private var balanceTransactionsSection: some View {
    Section("Balance transactions") {
      if balanceTransactionsFailed {
        Text("Couldn't load balance transactions.")
          .foregroundStyle(.secondary)
      } else if balanceTransactions.isEmpty {
        Text("None")
          .foregroundStyle(.secondary)
      } else {
        ForEach(balanceTransactions, id: \.id) { transaction in
          HStack {
            VStack(alignment: .leading, spacing: 2) {
              Text(transaction.type.rawValue)
                .font(.subheadline.weight(.medium))
              Text("\(transaction.amount) \(transaction.currency)")
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            Spacer()
            if writer != nil {
              Button("Edit") { editingTransaction = EditableTransaction(id: transaction.id, transaction: transaction) }
                .font(.footnote)
                .accessibilityIdentifier("customers.detail.editBalanceTx")
            }
          }
        }
      }
    }
  }

  @ViewBuilder
  private var cashBalanceSection: some View {
    Section("Cash balance") {
      if case .loaded(let customer) = phase {
        if let cashBalance = customer.cashBalance?.valueOrNil {
          PaymentFactRow(label: "Available", value: availableText(cashBalance))
        } else {
          Text("None")
            .foregroundStyle(.secondary)
        }
      }
      if writer != nil {
        Button("Create funding instructions…") { fundingPresented = true }
          .accessibilityIdentifier("customers.detail.fundingInline")
        Button("Fund cash balance…") { fundCashPresented = true }
          .accessibilityIdentifier("customers.detail.fundCashInline")
      }
    }
  }

  /// The available amounts as "usd 123, eur 45", currency-sorted.
  private func availableText(_ cashBalance: CashBalance) -> String {
    guard let available = cashBalance.available.valueOrNil else { return "—" }
    return available.keys.sorted().map { key in
      "\(key) \(describe(available[key] ?? .null))"
    }.joined(separator: ", ")
  }

  /// A compact rendering of one JSON amount value.
  private func describe(_ value: JSONValue) -> String {
    switch value {
    case .int(let number): return String(number)
    case .double(let number): return String(number)
    case .string(let text): return text
    case .null: return "null"
    case .bool(let flag): return String(flag)
    case .array, .object: return "…"
    }
  }

  @ViewBuilder
  private var taxIDsSection: some View {
    Section("Tax IDs") {
      if taxIDsFailed {
        Text("Couldn't load tax IDs.")
          .foregroundStyle(.secondary)
      } else if taxIDs.isEmpty {
        Text("None")
          .foregroundStyle(.secondary)
      } else {
        ForEach(taxIDs, id: \.id) { taxID in
          HStack {
            VStack(alignment: .leading, spacing: 2) {
              Text(taxID.type.rawValue)
                .font(.subheadline.weight(.medium))
              if !taxID.value.isEmpty {
                Text(taxID.value)
                  .font(.footnote)
                  .foregroundStyle(.secondary)
              }
            }
            Spacer()
            if writer != nil {
              Button("Delete", role: .destructive) { deletingTaxID = taxID }
                .font(.footnote)
                .accessibilityIdentifier("customers.detail.deleteTaxID")
            }
          }
        }
      }
    }
  }

  @ViewBuilder
  private var sourcesSection: some View {
    Section("Payment sources") {
      if sourcesFailed {
        Text("Couldn't load payment sources.")
          .foregroundStyle(.secondary)
      } else if sources.isEmpty {
        Text("None")
          .foregroundStyle(.secondary)
      } else {
        ForEach(Array(sources.enumerated()), id: \.offset) { pair in
          sourceRow(pair.element)
        }
      }
    }
  }

  /// "brand •••• last4 · MM/YY" when the preview carries card details.
  private func methodPreviewLabel(_ method: PaymentMethod) -> String {
    if method.type == .card, let card = method.card {
      return card.brand + " •••• " + card.last4 + " · " + String(card.expMonth)
        + "/" + String(card.expYear % 100)
    }
    return method.type.rawValue
  }

  @ViewBuilder
  private func sourceRow(_ source: PaymentSource) -> some View {
    switch source {
    case .card(let card):
      VStack(alignment: .leading, spacing: 2) {
        Text("\(card.brand) •••• \(card.last4)")
          .font(.subheadline.weight(.medium))
        Text(card.id)
          .font(.caption)
          .foregroundStyle(.secondary)
          .textSelection(.enabled)
      }
    case .bankAccount(let bank):
      VStack(alignment: .leading, spacing: 2) {
        Text("Bank account •••• \(bank.last4)")
          .font(.subheadline.weight(.medium))
        if let name = bank.bankName.valueOrNil, !name.isEmpty {
          Text(name)
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      }
    case .account(let account):
      VStack(alignment: .leading, spacing: 2) {
        Text("Account")
          .font(.subheadline.weight(.medium))
        Text(account.id)
          .font(.caption)
          .foregroundStyle(.secondary)
          .textSelection(.enabled)
      }
    case .source(let source):
      Text(source.id)
        .font(.footnote)
        .textSelection(.enabled)
    case .other:
      Text("Source")
        .font(.footnote)
    }
  }
}

/// A small identifiable wrapper so the balance-transaction edit sheet can
/// use `sheet(item:)`; generated Stripe structs are not Identifiable.
private struct EditableTransaction: Identifiable {
  let id: String
  let transaction: CustomerBalanceTransaction
}
