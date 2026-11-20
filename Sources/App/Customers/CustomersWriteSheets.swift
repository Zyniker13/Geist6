import GeistData
import StripeModels
import SwiftUI

// MARK: - Create customer sheet

/// Creates a new customer with an optional email, name, description and
/// metadata.
struct CreateCustomerSheet: View {
  let writer: CustomersWriteService
  let onFinished: (WriteResult) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var emailText = ""
  @State private var nameText = ""
  @State private var descriptionText = ""
  @State private var metadataText = ""
  @State private var running = false
  @State private var failureText: String?

  var body: some View {
    NavigationStack {
      Form {
        Section("New customer") {
          TextField("Email", text: $emailText)
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .accessibilityIdentifier("customers.create.email")
          TextField("Name", text: $nameText)
            .accessibilityIdentifier("customers.create.name")
          TextField("Description", text: $descriptionText)
            .accessibilityIdentifier("customers.create.description")
        }
        metadataEditor($metadataText, id: "customers.create.metadata")
        if let failureText {
          failureSection(failureText, id: "customers.write.error")
        }
      }
      .navigationTitle("New customer")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Create") { run() }
            .disabled(running || trimmedEmail.isEmpty)
            .accessibilityIdentifier("customers.create.submit")
        }
      }
    }
  }

  private var trimmedEmail: String { emailText.trimmingCharacters(in: .whitespaces) }

  private func run() {
    running = true
    failureText = nil
    Task {
      do {
        let metadata = try MetadataLines.parse(metadataText)
        let customer = try await writer.createCustomer(
          email: trimmedEmail.isEmpty ? nil : trimmedEmail,
          name: nameText.trimmingCharacters(in: .whitespaces).isEmpty
            ? nil : nameText.trimmingCharacters(in: .whitespaces),
          description: descriptionText.trimmingCharacters(in: .whitespaces).isEmpty
            ? nil : descriptionText.trimmingCharacters(in: .whitespaces),
          metadata: metadata.isEmpty ? nil : metadata,
          summary: "Create customer")
        await MainActor.run {
          onFinished(
            WriteResult(title: "Customer created", message: "\(customer.id) created."))
        }
      } catch {
        await MainActor.run {
          running = false
          failureText = writeErrorMessage(error)
        }
      }
    }
  }
}

// MARK: - Edit customer sheet

/// Edits a customer's email, name, description and metadata. Blank contact
/// fields are left untouched by the service; the metadata box replaces
/// metadata wholesale.
struct EditCustomerSheet: View {
  let customer: Customer
  let writer: CustomersWriteService
  let onFinished: (WriteResult) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var emailText: String
  @State private var nameText: String
  @State private var descriptionText: String
  @State private var metadataText: String
  @State private var running = false
  @State private var failureText: String?

  init(
    customer: Customer, writer: CustomersWriteService,
    onFinished: @escaping (WriteResult) -> Void
  ) {
    self.customer = customer
    self.writer = writer
    self.onFinished = onFinished
    _emailText = State(initialValue: customer.email.valueOrNil ?? "")
    _nameText = State(initialValue: customer.name?.valueOrNil ?? "")
    _descriptionText = State(initialValue: customer.description.valueOrNil ?? "")
    _metadataText = State(initialValue: formatMetadataLines(customer.metadata ?? [:]))
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Edit customer") {
          LabeledContent("Customer", value: customer.id)
          TextField("Email", text: $emailText)
            .keyboardType(.emailAddress)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .accessibilityIdentifier("customers.edit.email")
          TextField("Name", text: $nameText)
            .accessibilityIdentifier("customers.edit.name")
          TextField("Description", text: $descriptionText)
            .accessibilityIdentifier("customers.edit.description")
        }
        metadataEditor($metadataText, id: "customers.edit.metadata")
        if let failureText {
          failureSection(failureText, id: "customers.write.error")
        }
      }
      .navigationTitle("Edit customer")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") { run() }
            .disabled(running)
            .accessibilityIdentifier("customers.edit.submit")
        }
      }
    }
  }

  private func run() {
    running = true
    failureText = nil
    Task {
      do {
        let metadata = try MetadataLines.parse(metadataText)
        let email = emailText.trimmingCharacters(in: .whitespaces)
        let name = nameText.trimmingCharacters(in: .whitespaces)
        let description = descriptionText.trimmingCharacters(in: .whitespaces)
        let saved = try await writer.updateCustomer(
          id: customer.id,
          email: email.isEmpty ? nil : email,
          name: name.isEmpty ? nil : name,
          description: description.isEmpty ? nil : description,
          metadata: metadata,
          summary: "Update customer \(customer.id)")
        await MainActor.run {
          onFinished(
            WriteResult(title: "Customer updated", message: "\(saved.id) saved."))
        }
      } catch {
        await MainActor.run {
          running = false
          failureText = writeErrorMessage(error)
        }
      }
    }
  }
}

// MARK: - Balance transaction sheets

/// Creates a balance transaction on a customer: a signed amount in minor
/// units (positive credits the customer balance, negative debits it), a
/// three-letter currency, an optional description and metadata.
struct CreateBalanceTransactionSheet: View {
  let customerID: String
  let writer: CustomersWriteService
  let onFinished: (WriteResult) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var amountText = ""
  @State private var currencyText = ""
  @State private var descriptionText = ""
  @State private var metadataText = ""
  @State private var running = false
  @State private var failureText: String?

  private var signedMinor: Int? { Int(amountText) }
  private var currency: String { currencyText.trimmingCharacters(in: .whitespaces).lowercased() }
  private var inputIsValid: Bool {
    guard let amount = signedMinor, amount != 0 else { return false }
    return currency.count == 3
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("New balance transaction") {
          LabeledContent("Customer", value: customerID)
          TextField("Amount in cents (negative to debit)", text: $amountText)
            .keyboardType(.numbersAndPunctuation)
            .accessibilityIdentifier("customers.balanceTxCreate.amount")
          TextField("Currency (for example usd)", text: $currencyText)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .accessibilityIdentifier("customers.balanceTxCreate.currency")
          TextField("Description", text: $descriptionText)
            .accessibilityIdentifier("customers.balanceTxCreate.description")
        }
        metadataEditor($metadataText, id: "customers.balanceTxCreate.metadata")
        if let failureText {
          failureSection(failureText, id: "customers.write.error")
        }
      }
      .navigationTitle("Balance transaction")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Create") { run() }
            .disabled(running || !inputIsValid)
            .accessibilityIdentifier("customers.balanceTxCreate.submit")
        }
      }
    }
  }

  private func run() {
    running = true
    failureText = nil
    Task {
      do {
        let metadata = try MetadataLines.parse(metadataText)
        let description = descriptionText.trimmingCharacters(in: .whitespaces)
        let transaction = try await writer.createBalanceTransaction(
          customer: customerID, amount: signedMinor ?? 0, currency: currency,
          description: description.isEmpty ? nil : description,
          metadata: metadata.isEmpty ? nil : metadata,
          summary: "Create \(customerID) balance transaction")
        await MainActor.run {
          onFinished(
            WriteResult(title: "Transaction created", message: "\(transaction.id) created."))
        }
      } catch {
        await MainActor.run {
          running = false
          failureText = writeErrorMessage(error)
        }
      }
    }
  }
}

/// Edits a balance transaction's description and metadata.
struct EditBalanceTransactionSheet: View {
  let transaction: CustomerBalanceTransaction
  let writer: CustomersWriteService
  let onFinished: (WriteResult) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var descriptionText: String
  @State private var metadataText: String
  @State private var running = false
  @State private var failureText: String?

  init(
    transaction: CustomerBalanceTransaction, writer: CustomersWriteService,
    onFinished: @escaping (WriteResult) -> Void
  ) {
    self.transaction = transaction
    self.writer = writer
    self.onFinished = onFinished
    _descriptionText = State(initialValue: transaction.description.valueOrNil ?? "")
    _metadataText = State(initialValue: formatMetadataLines(transaction.metadata.valueOrNil ?? [:]))
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Edit transaction") {
          LabeledContent("Transaction", value: transaction.id)
          TextField("Description", text: $descriptionText)
            .accessibilityIdentifier("customers.balanceTxEdit.description")
        }
        metadataEditor($metadataText, id: "customers.balanceTxEdit.metadata")
        if let failureText {
          failureSection(failureText, id: "customers.write.error")
        }
      }
      .navigationTitle("Edit transaction")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") { run() }
            .disabled(running)
            .accessibilityIdentifier("customers.balanceTxEdit.submit")
        }
      }
    }
  }

  private func run() {
    running = true
    failureText = nil
    Task {
      let metadata: [String: String]
      do {
        metadata = try MetadataLines.parse(metadataText)
      } catch {
        await MainActor.run {
          running = false
          failureText = writeErrorMessage(error)
        }
        return
      }
      let description = descriptionText.trimmingCharacters(in: .whitespaces)
      guard let owner = transaction.customer.idOrNil else {
        await MainActor.run {
          running = false
          failureText = "The transaction's customer could not be identified."
        }
        return
      }
      do {
        let saved = try await writer.updateBalanceTransaction(
          customer: owner, transaction: transaction.id,
          description: description.isEmpty ? nil : description,
          metadata: metadata,
          summary: "Update balance transaction \(transaction.id)")
        await MainActor.run {
          onFinished(
            WriteResult(title: "Transaction updated", message: "\(saved.id) saved."))
        }
      } catch {
        await MainActor.run {
          running = false
          failureText = writeErrorMessage(error)
        }
      }
    }
  }
}

// MARK: - Tax ID sheet

/// Adds a tax ID to a customer from a fixed list of Stripe tax ID types.
struct AddTaxIDSheet: View {
  /// The Stripe tax ID types the sheet offers. Covers the common VAT and
  /// business-tax types; a full list lives in Stripe's tax ID docs.
  static let types: [String] = [
    "eu_vat", "us_ein", "gb_vat", "de_vat", "fr_vat", "ie_vat", "es_vat", "it_vat",
    "nl_vat", "au_abn", "nz_gst", "ca_bn", "ch_vat", "in_gst", "no_vat",
  ]

  let writer: CustomersWriteService
  let customerID: String
  let onFinished: (WriteResult) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var type = AddTaxIDSheet.types[0]
  @State private var valueText = ""
  @State private var running = false
  @State private var failureText: String?

  var body: some View {
    NavigationStack {
      Form {
        Section("Add tax ID") {
          Picker("Type", selection: $type) {
            ForEach(Self.types, id: \.self) { option in
              Text(option).tag(option)
            }
          }
          .accessibilityIdentifier("customers.taxIDAdd.type")
          TextField("Value", text: $valueText)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .accessibilityIdentifier("customers.taxIDAdd.value")
        }
        if let failureText {
          failureSection(failureText, id: "customers.write.error")
        }
      }
      .navigationTitle("Add tax ID")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Add") { run() }
            .disabled(running || valueText.trimmingCharacters(in: .whitespaces).isEmpty)
            .accessibilityIdentifier("customers.taxIDAdd.submit")
        }
      }
    }
  }

  private func run() {
    running = true
    failureText = nil
    Task {
      do {
        let value = valueText.trimmingCharacters(in: .whitespaces)
        let taxID = try await writer.createTaxID(
          customer: customerID, type: type, value: value,
          summary: "Add tax ID to \(customerID)")
        await MainActor.run {
          onFinished(
            WriteResult(title: "Tax ID added", message: "\(taxID.id) added."))
        }
      } catch {
        await MainActor.run {
          running = false
          failureText = writeErrorMessage(error)
        }
      }
    }
  }
}

// MARK: - Cash-balance funding sheets

/// Creates funding instructions (bank transfer details) for a customer's
/// cash balance in a chosen currency.
struct FundingInstructionsSheet: View {
  let customerID: String
  let writer: CustomersWriteService
  let onFinished: (WriteResult) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var currencyText = ""
  @State private var running = false
  @State private var failureText: String?

  private var currency: String { currencyText.trimmingCharacters(in: .whitespaces).lowercased() }
  private var inputIsValid: Bool { currency.count == 3 }

  var body: some View {
    NavigationStack {
      Form {
        Section("Funding instructions") {
          LabeledContent("Customer", value: customerID)
          TextField("Currency (for example eur)", text: $currencyText)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .accessibilityIdentifier("customers.funding.currency")
        }
        if let failureText {
          failureSection(failureText, id: "customers.write.error")
        }
      }
      .navigationTitle("Funding instructions")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Create") { run() }
            .disabled(running || !inputIsValid)
            .accessibilityIdentifier("customers.funding.submit")
        }
      }
    }
  }

  private func run() {
    running = true
    failureText = nil
    Task {
      do {
        _ = try await writer.createFundingInstructions(
          customer: customerID, currency: currency,
          summary: "Create funding instructions for \(customerID)")
        await MainActor.run {
          onFinished(
            WriteResult(
              title: "Funding instructions created",
              message: "Bank transfer details for \(customerID) created."))
        }
      } catch {
        await MainActor.run {
          running = false
          failureText = writeErrorMessage(error)
        }
      }
    }
  }
}

/// Adds test funds to a customer's cash balance through the test-helper
/// endpoint. Only meaningful in test mode.
struct FundCashBalanceSheet: View {
  let customerID: String
  let writer: CustomersWriteService
  let onFinished: (WriteResult) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var amountText = ""
  @State private var currencyText = ""
  @State private var running = false
  @State private var failureText: String?

  private var amountMinor: Int? { Int(amountText) }
  private var currency: String { currencyText.trimmingCharacters(in: .whitespaces).lowercased() }
  private var inputIsValid: Bool {
    guard let amount = amountMinor, amount > 0 else { return false }
    return currency.count == 3
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Fund cash balance") {
          LabeledContent("Customer", value: customerID)
          TextField("Amount in cents", text: $amountText)
            .keyboardType(.numberPad)
            .accessibilityIdentifier("customers.fundCash.amount")
          TextField("Currency (for example usd)", text: $currencyText)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .accessibilityIdentifier("customers.fundCash.currency")
        }
        if let failureText {
          failureSection(failureText, id: "customers.write.error")
        }
      }
      .navigationTitle("Fund cash balance")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Fund") { run() }
            .disabled(running || !inputIsValid)
            .accessibilityIdentifier("customers.fundCash.submit")
        }
      }
    }
  }

  private func run() {
    running = true
    failureText = nil
    Task {
      do {
        let transaction = try await writer.fundCashBalance(
          customer: customerID, amount: amountMinor ?? 0, currency: currency,
          summary: "Fund \(customerID) cash balance")
        await MainActor.run {
          onFinished(
            WriteResult(title: "Cash funded", message: "\(transaction.id) recorded."))
        }
      } catch {
        await MainActor.run {
          running = false
          failureText = writeErrorMessage(error)
        }
      }
    }
  }
}

// MARK: - Shared bits

extension View {
  /// The metadata key=value editor shared by the customer sheets: one pair
  /// per line; saving replaces all metadata, an empty field clears every key.
  func metadataEditor(_ text: Binding<String>, id: String) -> some View {
    Section {
      TextEditor(text: text)
        .font(.system(.footnote, design: .monospaced))
        .frame(minHeight: 88)
        .accessibilityIdentifier(id)
    } header: {
      Text("Metadata")
    } footer: {
      Text(
        "One pair per line: key=value. Saving replaces all metadata; "
          + "an empty field clears every key.")
    }
  }
}

/// A red error line shown inside a write sheet.
private func failureSection(_ text: String, id: String) -> some View {
  Section {
    Text(text)
      .font(.footnote)
      .foregroundStyle(.red)
      .accessibilityIdentifier(id)
  }
}
