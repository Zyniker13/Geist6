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

// MARK: - Create coupon sheet

/// Creates a coupon: name, discount type (percent or amount), duration,
/// and optional metadata.
struct CreateCouponSheet: View {
  let writer: BillingWriteService
  let onFinished: (WriteResult) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var nameText = ""
  @State private var percentText = ""
  @State private var amountText = ""
  @State private var currencyText = "usd"
  @State private var discountTypeText = "percent"
  @State private var durationText = "forever"
  @State private var durationMonthsText = ""
  @State private var redeemByText = ""
  @State private var maxRedemptionsText = ""
  @State private var metadataText = ""
  @State private var running = false
  @State private var failureText: String?

  private var percentOff: Decimal? {
    guard !percentText.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
    return Decimal(string: percentText.trimmingCharacters(in: .whitespaces))
  }

  private var amountOff: Int? {
    Int(amountText.trimmingCharacters(in: .whitespaces))
  }

  private var currency: String {
    currencyText.trimmingCharacters(in: .whitespaces).lowercased()
  }

  private var durationInMonths: Int? {
    Int(durationMonthsText.trimmingCharacters(in: .whitespaces))
  }

  private var maxRedemptions: Int? {
    Int(maxRedemptionsText.trimmingCharacters(in: .whitespaces))
  }

  /// A coupon needs exactly one discount value: a percent or an amount
  /// with a currency.
  private var discountComplete: Bool {
    if discountTypeText == "percent" {
      return percentOff != nil
    }
    return amountOff != nil && !currency.isEmpty
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("New coupon") {
          TextField("Name", text: $nameText)
            .accessibilityIdentifier("billing.coupon.create.name")
        }
        Section("Discount") {
          Picker("Type", selection: $discountTypeText) {
            Text("Percent off").tag("percent")
            Text("Amount off").tag("amount")
          }
          .pickerStyle(.segmented)
          .accessibilityIdentifier("billing.coupon.create.type")
          if discountTypeText == "percent" {
            TextField("Percent off", text: $percentText)
              .keyboardType(.decimalPad)
              .accessibilityIdentifier("billing.coupon.create.percentOff")
          } else {
            TextField("Amount (minor units)", text: $amountText)
              .keyboardType(.numberPad)
              .accessibilityIdentifier("billing.coupon.create.amount")
            TextField("Currency", text: $currencyText)
              .autocorrectionDisabled()
              .textInputAutocapitalization(.never)
              .accessibilityIdentifier("billing.coupon.create.currency")
          }
        }
        Section("Duration") {
          Picker("Duration", selection: $durationText) {
            Text("Forever").tag("forever")
            Text("Repeating").tag("repeating")
            Text("Once").tag("once")
          }
          .accessibilityIdentifier("billing.coupon.create.duration")
          if durationText == "repeating" {
            TextField("Months", text: $durationMonthsText)
              .keyboardType(.numberPad)
              .accessibilityIdentifier("billing.coupon.create.durationMonths")
          }
          TextField("Redeem by (YYYY-MM-DD)", text: $redeemByText)
            .keyboardType(.asciiCapable)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .accessibilityIdentifier("billing.coupon.create.redeemBy")
          TextField("Max redemptions", text: $maxRedemptionsText)
            .keyboardType(.numberPad)
            .accessibilityIdentifier("billing.coupon.create.maxRedemptions")
        }
        metadataEditor($metadataText, id: "billing.coupon.create.metadata")
        if let failureText {
          failureSection(failureText, id: "billing.write.error")
        }
      }
      .navigationTitle("New coupon")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Create") { run() }
            .disabled(running || !discountComplete)
            .accessibilityIdentifier("billing.coupon.create.submit")
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
        let draft = BillingWriteService.CouponDraft(
          name: nameText.trimmingCharacters(in: .whitespaces).isEmpty
            ? nil : nameText.trimmingCharacters(in: .whitespaces),
          percentOff: discountTypeText == "percent" ? percentOff : nil,
          amountOff: discountTypeText == "amount" ? amountOff : nil,
          currency: discountTypeText == "amount" ? currency : nil,
          duration: durationText,
          durationInMonths: durationText == "repeating" ? durationInMonths : nil,
          redeemBy: parseDate(redeemByText),
          maxRedemptions: maxRedemptions,
          metadata: metadata.isEmpty ? nil : metadata
        )
        let coupon = try await writer.createCoupon(draft: draft, summary: "Create coupon")
        await MainActor.run {
          onFinished(
            WriteResult(title: "Coupon created", message: "\(coupon.id) created."))
        }
      } catch {
        await MainActor.run {
          running = false
          failureText = writeErrorMessage(error)
        }
      }
    }
  }

  private func parseDate(_ text: String) -> Date? {
    let trimmed = text.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return nil }
    // Fixed calendar and zone: the field is a plain ISO date, not
    // locale-formatted, and Stripe stores it as a UTC timestamp.
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "UTC")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.date(from: trimmed)
  }
}

// MARK: - Edit coupon sheet

/// Edits a coupon's name and metadata. Stripe only allows these fields
/// to be changed after creation.
struct EditCouponSheet: View {
  let coupon: Coupon
  let writer: BillingWriteService
  let onFinished: (WriteResult) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var nameText: String
  @State private var metadataText: String
  @State private var running = false
  @State private var failureText: String?

  init(coupon: Coupon, writer: BillingWriteService, onFinished: @escaping (WriteResult) -> Void) {
    self.coupon = coupon
    self.writer = writer
    self.onFinished = onFinished
    _nameText = State(initialValue: coupon.name.valueOrNil ?? "")
    _metadataText = State(initialValue: formatMetadataLines(coupon.metadata.valueOrNil ?? [:]))
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Edit coupon") {
          LabeledContent("Coupon", value: coupon.id)
          TextField("Name", text: $nameText)
            .accessibilityIdentifier("billing.coupon.edit.name")
        }
        metadataEditor($metadataText, id: "billing.coupon.edit.metadata")
        if let failureText {
          failureSection(failureText, id: "billing.write.error")
        }
      }
      .navigationTitle("Edit coupon")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") { run() }
            .disabled(running)
            .accessibilityIdentifier("billing.coupon.edit.submit")
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
        let saved = try await writer.updateCoupon(
          id: coupon.id,
          update: .init(
            name: name.isEmpty ? nil : name,
            metadata: metadata
          ),
          summary: "Update coupon \(coupon.id)"
        )
        await MainActor.run {
          onFinished(
            WriteResult(title: "Coupon updated", message: "\(saved.id) saved."))
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

// MARK: - Create promotion code sheet

/// Creates a promotion code tied to an existing coupon. The user selects
/// a coupon from a picker, optionally sets a custom redemption code,
/// expiry, max redemptions, and metadata.
struct CreatePromotionCodeSheet: View {
  let writer: BillingWriteService
  let coupons: [Coupon]
  let onFinished: (WriteResult) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var selectedCouponIndex: Int = 0
  @State private var codeText = ""
  @State private var active = true
  @State private var expiresAtText = ""
  @State private var maxRedemptionsText = ""
  @State private var metadataText = ""
  @State private var running = false
  @State private var failureText: String?

  private var selectedCoupon: Coupon? {
    guard selectedCouponIndex >= 0, selectedCouponIndex < coupons.count else { return nil }
    return coupons[selectedCouponIndex]
  }

  private var maxRedemptions: Int? {
    Int(maxRedemptionsText.trimmingCharacters(in: .whitespaces))
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Coupon") {
          if coupons.isEmpty {
            Text("No coupons available")
              .foregroundStyle(.secondary)
          } else {
            Picker("Coupon", selection: $selectedCouponIndex) {
              ForEach(Array(coupons.enumerated()), id: \.element.id) { idx, coupon in
                Text(coupon.name.valueOrNil ?? coupon.id)
                  .tag(idx)
              }
            }
            .accessibilityIdentifier("billing.promo.create.coupon")
          }
        }
        Section("Promotion code") {
          TextField("Code (leave blank for auto-generated)", text: $codeText)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .accessibilityIdentifier("billing.promo.create.code")
          Toggle("Active", isOn: $active)
            .accessibilityIdentifier("billing.promo.create.active")
          TextField("Expires at (YYYY-MM-DD)", text: $expiresAtText)
            .keyboardType(.asciiCapable)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .accessibilityIdentifier("billing.promo.create.expiresAt")
          TextField("Max redemptions", text: $maxRedemptionsText)
            .keyboardType(.numberPad)
            .accessibilityIdentifier("billing.promo.create.maxRedemptions")
        }
        metadataEditor($metadataText, id: "billing.promo.create.metadata")
        if let failureText {
          failureSection(failureText, id: "billing.write.error")
        }
      }
      .navigationTitle("New promotion code")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Create") { run() }
            .disabled(running || coupons.isEmpty)
            .accessibilityIdentifier("billing.promo.create.submit")
        }
      }
    }
  }

  private func run() {
    guard let coupon = selectedCoupon else { return }
    running = true
    failureText = nil
    Task {
      do {
        let metadata = try MetadataLines.parse(metadataText)
        let draft = BillingWriteService.PromotionCodeDraft(
          coupon: coupon.id,
          code: codeText.trimmingCharacters(in: .whitespaces).isEmpty ? nil
            : codeText.trimmingCharacters(in: .whitespaces),
          active: active,
          expiresAt: parseDate(expiresAtText),
          maxRedemptions: maxRedemptions,
          customer: nil,
          metadata: metadata.isEmpty ? nil : metadata
        )
        let promo = try await writer.createPromotionCode(draft: draft, summary: "Create promotion code")
        await MainActor.run {
          onFinished(
            WriteResult(title: "Promotion code created", message: "\(promo.id) created."))
        }
      } catch {
        await MainActor.run {
          running = false
          failureText = writeErrorMessage(error)
        }
      }
    }
  }

  private func parseDate(_ text: String) -> Date? {
    let trimmed = text.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return nil }
    // Fixed calendar and zone: the field is a plain ISO date, not
    // locale-formatted, and Stripe stores it as a UTC timestamp.
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "UTC")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.date(from: trimmed)
  }
}

// MARK: - Edit promotion code sheet

/// Edits a promotion code's active flag and metadata.
struct EditPromotionCodeSheet: View {
  let promotionCode: PromotionCode
  let writer: BillingWriteService
  let onFinished: (WriteResult) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var active: Bool
  @State private var metadataText: String
  @State private var running = false
  @State private var failureText: String?

  init(promotionCode: PromotionCode, writer: BillingWriteService, onFinished: @escaping (WriteResult) -> Void) {
    self.promotionCode = promotionCode
    self.writer = writer
    self.onFinished = onFinished
    _active = State(initialValue: promotionCode.active)
    _metadataText = State(initialValue: formatMetadataLines(promotionCode.metadata.valueOrNil ?? [:]))
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Edit promotion code") {
          LabeledContent("Code", value: promotionCode.id)
          LabeledContent("Redemption code", value: promotionCode.code)
          Toggle("Active", isOn: $active)
            .accessibilityIdentifier("billing.promo.edit.active")
        }
        metadataEditor($metadataText, id: "billing.promo.edit.metadata")
        if let failureText {
          failureSection(failureText, id: "billing.write.error")
        }
      }
      .navigationTitle("Edit promotion code")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") { run() }
            .disabled(running)
            .accessibilityIdentifier("billing.promo.edit.submit")
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
        let saved = try await writer.updatePromotionCode(
          id: promotionCode.id,
          active: active,
          metadata: metadata,
          summary: "Update promotion code \(promotionCode.id)"
        )
        await MainActor.run {
          onFinished(
            WriteResult(title: "Promotion code updated", message: "\(saved.id) saved."))
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
