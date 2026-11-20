import GeistData
import StripeModels
import SwiftUI

// MARK: - Create product sheet

/// Creates a product with a name, optional description, active flag and
/// metadata.
struct CreateProductSheet: View {
  let writer: BillingWriteService
  let onFinished: (WriteResult) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var nameText = ""
  @State private var descriptionText = ""
  @State private var active = true
  @State private var metadataText = ""
  @State private var running = false
  @State private var failureText: String?

  var body: some View {
    NavigationStack {
      Form {
        Section("New product") {
          TextField("Name", text: $nameText)
            .accessibilityIdentifier("billing.create.name")
          TextField("Description", text: $descriptionText)
            .accessibilityIdentifier("billing.create.description")
          Toggle("Active", isOn: $active)
            .accessibilityIdentifier("billing.create.active")
        }
        metadataEditor($metadataText, id: "billing.create.metadata")
        if let failureText {
          failureSection(failureText, id: "billing.write.error")
        }
      }
      .navigationTitle("New product")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Create") { run() }
            .disabled(running || trimmedName.isEmpty)
            .accessibilityIdentifier("billing.create.submit")
        }
      }
    }
  }

  private var trimmedName: String { nameText.trimmingCharacters(in: .whitespaces) }

  private func run() {
    running = true
    failureText = nil
    Task {
      do {
        let metadata = try MetadataLines.parse(metadataText)
        let description = descriptionText.trimmingCharacters(in: .whitespaces)
        let product = try await writer.createProduct(
          name: trimmedName,
          description: description.isEmpty ? nil : description,
          active: active,
          metadata: metadata.isEmpty ? nil : metadata,
          summary: "Create product")
        await MainActor.run {
          onFinished(
            WriteResult(title: "Product created", message: "\(product.id) created."))
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

// MARK: - Edit product sheet

/// Edits a product's name, description, active flag and metadata. Blank
/// text fields are left untouched by the service; the metadata box replaces
/// metadata wholesale.
struct EditProductSheet: View {
  let product: Product
  let writer: BillingWriteService
  let onFinished: (WriteResult) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var nameText: String
  @State private var descriptionText: String
  @State private var active: Bool
  @State private var metadataText: String
  @State private var running = false
  @State private var failureText: String?

  init(product: Product, writer: BillingWriteService, onFinished: @escaping (WriteResult) -> Void) {
    self.product = product
    self.writer = writer
    self.onFinished = onFinished
    _nameText = State(initialValue: product.name)
    _descriptionText = State(initialValue: product.description.valueOrNil ?? "")
    _active = State(initialValue: product.active)
    _metadataText = State(initialValue: formatMetadataLines(product.metadata ?? [:]))
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Edit product") {
          LabeledContent("Product", value: product.id)
          TextField("Name", text: $nameText)
            .accessibilityIdentifier("billing.edit.name")
          TextField("Description", text: $descriptionText)
            .accessibilityIdentifier("billing.edit.description")
          Toggle("Active", isOn: $active)
            .accessibilityIdentifier("billing.edit.active")
        }
        metadataEditor($metadataText, id: "billing.edit.metadata")
        if let failureText {
          failureSection(failureText, id: "billing.write.error")
        }
      }
      .navigationTitle("Edit product")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") { run() }
            .disabled(running)
            .accessibilityIdentifier("billing.edit.submit")
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
        let name = nameText.trimmingCharacters(in: .whitespaces)
        let description = descriptionText.trimmingCharacters(in: .whitespaces)
        let saved = try await writer.updateProduct(
          id: product.id,
          update: .init(
            name: name.isEmpty ? nil : name,
            description: description.isEmpty ? nil : description,
            active: active,
            metadata: metadata),
          summary: "Update product \(product.id)")
        await MainActor.run {
          onFinished(
            WriteResult(title: "Product updated", message: "\(saved.id) saved."))
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

// MARK: - Create price sheet

/// Creates a price for a product: currency, unit amount in minor units,
/// optional nickname, and either a one-time price or a recurring one with
/// an interval and optional interval count.
struct CreatePriceSheet: View {
  let writer: BillingWriteService
  let presetProductID: String?
  let onFinished: (WriteResult) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var productText: String
  @State private var currencyText = "usd"
  @State private var amountText = ""
  @State private var nicknameText = ""
  @State private var recurring = false
  @State private var intervalText = "month"
  @State private var intervalCountText = ""
  @State private var metadataText = ""
  @State private var running = false
  @State private var failureText: String?

  init(
    writer: BillingWriteService, presetProductID: String?,
    onFinished: @escaping (WriteResult) -> Void
  ) {
    self.writer = writer
    self.presetProductID = presetProductID
    self.onFinished = onFinished
    _productText = State(initialValue: presetProductID ?? "")
  }

  private var product: String { productText.trimmingCharacters(in: .whitespaces) }
  private var currency: String { currencyText.trimmingCharacters(in: .whitespaces).lowercased() }
  private var unitAmount: Int? { Int(amountText.trimmingCharacters(in: .whitespaces)) }
  private var intervalCount: Int? {
    Int(intervalCountText.trimmingCharacters(in: .whitespaces))
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("New price") {
          TextField("Product ID", text: $productText)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .accessibilityIdentifier("billing.price.create.product")
          TextField("Currency", text: $currencyText)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .accessibilityIdentifier("billing.price.create.currency")
          TextField("Unit amount (minor units)", text: $amountText)
            .keyboardType(.numberPad)
            .accessibilityIdentifier("billing.price.create.amount")
          TextField("Nickname", text: $nicknameText)
            .accessibilityIdentifier("billing.price.create.nickname")
        }
        Section("Billing schedule") {
          Picker("Type", selection: $recurring) {
            Text("One-time").tag(false)
            Text("Recurring").tag(true)
          }
          .pickerStyle(.segmented)
          .accessibilityIdentifier("billing.price.create.type")
          if recurring {
            Picker("Interval", selection: $intervalText) {
              ForEach(["day", "week", "month", "year"], id: \.self) { interval in
                Text(interval).tag(interval)
              }
            }
            .accessibilityIdentifier("billing.price.create.interval")
            TextField("Interval count", text: $intervalCountText)
              .keyboardType(.numberPad)
              .accessibilityIdentifier("billing.price.create.intervalCount")
          }
        }
        metadataEditor($metadataText, id: "billing.price.create.metadata")
        if let failureText {
          failureSection(failureText, id: "billing.write.error")
        }
      }
      .navigationTitle("New price")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Create") { run() }
            .disabled(running || product.isEmpty || currency.isEmpty || unitAmount == nil)
            .accessibilityIdentifier("billing.price.create.submit")
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
        let nickname = nicknameText.trimmingCharacters(in: .whitespaces)
        let price = try await writer.createPrice(
          draft: .init(
            product: product,
            currency: currency,
            unitAmount: unitAmount,
            nickname: nickname.isEmpty ? nil : nickname,
            recurringInterval: recurring ? intervalText : nil,
            recurringIntervalCount: recurring ? intervalCount : nil,
            active: true,
            metadata: metadata.isEmpty ? nil : metadata),
          summary: "Create price for \(product)")
        await MainActor.run {
          onFinished(
            WriteResult(title: "Price created", message: "\(price.id) created."))
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

// MARK: - Edit price sheet

/// Edits a price's nickname, active flag and metadata. Stripe does not
/// allow changing a price's amount or currency after creation, so those
/// fields are shown read-only.
struct EditPriceSheet: View {
  let price: Price
  let writer: BillingWriteService
  let onFinished: (WriteResult) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var nicknameText: String
  @State private var active: Bool
  @State private var metadataText: String
  @State private var running = false
  @State private var failureText: String?

  init(price: Price, writer: BillingWriteService, onFinished: @escaping (WriteResult) -> Void) {
    self.price = price
    self.writer = writer
    self.onFinished = onFinished
    _nicknameText = State(initialValue: price.nickname.valueOrNil ?? "")
    _active = State(initialValue: price.active)
    _metadataText = State(initialValue: formatMetadataLines(price.metadata ?? [:]))
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Edit price") {
          LabeledContent("Price", value: price.id)
          LabeledContent("Amount", value: PriceRow(price: price).amount)
          TextField("Nickname", text: $nicknameText)
            .accessibilityIdentifier("billing.price.edit.nickname")
          Toggle("Active", isOn: $active)
            .accessibilityIdentifier("billing.price.edit.active")
        }
        metadataEditor($metadataText, id: "billing.price.edit.metadata")
        if let failureText {
          failureSection(failureText, id: "billing.write.error")
        }
      }
      .navigationTitle("Edit price")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") { run() }
            .disabled(running)
            .accessibilityIdentifier("billing.price.edit.submit")
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
        let nickname = nicknameText.trimmingCharacters(in: .whitespaces)
        let saved = try await writer.updatePrice(
          id: price.id,
          nickname: nickname.isEmpty ? nil : nickname,
          active: active,
          metadata: metadata,
          summary: "Update price \(price.id)")
        await MainActor.run {
          onFinished(
            WriteResult(title: "Price updated", message: "\(saved.id) saved."))
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
