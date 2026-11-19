import GeistData
import StripeModels
import SwiftUI

/// The detail screen for one setup intent, with its write actions.
struct SetupIntentDetailView: View {
  enum Phase: Equatable {
    case loading
    case loaded(SetupIntent)
    case failed(String)
  }

  let intentID: String
  let backend: any PaymentsBackend
  /// Nil for dashboard-locked accounts: no write controls are shown.
  let writer: PaymentsWriteService?

  @State private var phase: Phase = .loading
  @State private var confirmPresented = false
  @State private var cancelPresented = false
  @State private var updatePresented = false
  @State private var verifyDepositsPresented = false
  @State private var writeResult: WriteResult?

  var body: some View {
    Group {
      switch phase {
      case .loading:
        ProgressView()
      case .failed(let message):
        ContentUnavailableView(
          "Couldn't load setup intent",
          systemImage: "exclamationmark.triangle",
          description: Text(message)
        )
      case .loaded(let intent):
        details(intent)
      }
    }
    .navigationTitle("Setup Intent")
    .navigationBarTitleDisplayMode(.inline)
    .task(id: intentID) { await load() }
    .toolbar { actionsToolbar }
    .sheet(isPresented: $confirmPresented) {
      if case .loaded(let intent) = phase, let writer {
        ConfirmSetupIntentSheet(intent: intent, writer: writer, onFinished: handleWriteFinished)
      }
    }
    .sheet(isPresented: $cancelPresented) {
      if case .loaded(let intent) = phase, let writer {
        CancelSetupIntentSheet(intent: intent, writer: writer, onFinished: handleWriteFinished)
      }
    }
    .sheet(isPresented: $updatePresented) {
      if case .loaded(let intent) = phase, let writer {
        UpdateSetupIntentSheet(intent: intent, writer: writer, onFinished: handleWriteFinished)
      }
    }
    .sheet(isPresented: $verifyDepositsPresented) {
      if case .loaded(let intent) = phase, let writer {
        VerifyMicrodepositsSheet(
          target: .setupIntent(intent), writer: writer, onFinished: handleWriteFinished)
      }
    }
    .writeResultAlert($writeResult)
  }

  @ToolbarContentBuilder
  private var actionsToolbar: some ToolbarContent {
    ToolbarItem(placement: .primaryAction) {
      if let writer, case .loaded(let intent) = phase {
        Menu {
          if isConfirmable(intent.status) {
            Button("Confirm…") { confirmPresented = true }
              .accessibilityIdentifier("payments.setupIntent.confirm")
          }
          if isEditable(intent.status) {
            Button("Edit description…") { updatePresented = true }
              .accessibilityIdentifier("payments.setupIntent.edit")
          }
          if isVerifiable(intent) {
            Button("Verify microdeposits…") { verifyDepositsPresented = true }
              .accessibilityIdentifier("payments.setupIntent.verifyDeposits")
          }
          if isCancellable(intent.status) {
            Button("Cancel intent…", role: .destructive) { cancelPresented = true }
              .accessibilityIdentifier("payments.setupIntent.cancel")
          }
        } label: {
          Label("Actions", systemImage: "ellipsis.circle")
        }
        .accessibilityIdentifier("payments.setupIntent.actions")
      }
    }
  }

  /// Stripe confirms setup intents in these (interactive) statuses.
  private func isConfirmable(_ status: SetupIntentStatus) -> Bool {
    switch status {
    case .requiresPaymentMethod, .requiresConfirmation, .requiresAction:
      return true
    case .processing, .canceled, .succeeded, .undocumented:
      return false
    }
  }

  /// Stripe cancels setup intents in these statuses.
  private func isCancellable(_ status: SetupIntentStatus) -> Bool {
    switch status {
    case .requiresPaymentMethod, .requiresConfirmation, .requiresAction, .processing:
      return true
    case .canceled, .succeeded, .undocumented:
      return false
    }
  }

  /// Completed intents no longer accept edits.
  private func isEditable(_ status: SetupIntentStatus) -> Bool {
    switch status {
    case .canceled, .succeeded:
      return false
    case .processing, .requiresAction, .requiresConfirmation, .requiresPaymentMethod,
      .undocumented:
      return true
    }
  }

  /// Microdeposit verification applies to bank-debit intents awaiting
  /// customer verification.
  private func isVerifiable(_ intent: SetupIntent) -> Bool {
    intent.paymentMethodTypes.contains("us_bank_account")
      && (intent.status == .requiresAction || intent.status == .processing)
  }

  private func handleWriteFinished(_ result: WriteResult) {
    confirmPresented = false
    cancelPresented = false
    updatePresented = false
    verifyDepositsPresented = false
    writeResult = result
    Task { await load() }
  }

  @ViewBuilder
  private func details(_ intent: SetupIntent) -> some View {
    List {
      Section {
        HStack(alignment: .firstTextBaseline) {
          Text(intent.status.rawValue)
            .font(.title3.weight(.semibold))
          Spacer(minLength: 8)
          PaymentStatusBadge(text: intent.status.rawValue)
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("payments.setupIntent.status")
      }

      Section("Details") {
        PaymentFactRow(label: "Usage", value: intent.usage)
        PaymentFactRow(label: "Created", value: "\(intent.created.date.formatted(date: .abbreviated, time: .omitted))")
        if let customer = intent.customer.valueOrNil {
          PaymentFactRow(label: "Customer", value: paymentCustomerID(customer))
        }
        if let description = intent.description.valueOrNil {
          PaymentFactRow(label: "Description", value: description)
        }
      }

      if let mandateID = intent.mandate.valueOrNil?.idOrNil {
        Section("Mandate") {
          NavigationLink {
            MandateDetailView(mandateID: mandateID, backend: backend)
          } label: {
            Label("View mandate", systemImage: "signature")
          }
          .accessibilityIdentifier("payments.setupIntent.mandateLink")
        }
      }
    }
  }

  private func load() async {
    phase = .loading
    do {
      phase = .loaded(try await backend.retrieveSetupIntent(id: intentID))
    } catch {
      phase = .failed(String(describing: error))
    }
  }
}

/// The detail screen for one payment method.
struct PaymentMethodDetailView: View {
  enum Phase: Equatable {
    case loading
    case loaded(PaymentMethod)
    case failed(String)
  }

  let methodID: String
  let backend: any PaymentsBackend
  /// Nil for dashboard-locked accounts: no write controls are shown.
  let writer: PaymentsWriteService?

  @State private var phase: Phase = .loading
  @State private var attachPresented = false
  @State private var updatePresented = false
  @State private var detachConfirmed = false
  @State private var writeResult: WriteResult?

  var body: some View {
    Group {
      switch phase {
      case .loading:
        ProgressView()
      case .failed(let message):
        ContentUnavailableView(
          "Couldn't load payment method",
          systemImage: "exclamationmark.triangle",
          description: Text(message)
        )
      case .loaded(let method):
        details(method)
      }
    }
    .navigationTitle("Payment Method")
    .navigationBarTitleDisplayMode(.inline)
    .task(id: methodID) { await load() }
    .toolbar { actionsToolbar }
    .sheet(isPresented: $attachPresented) {
      if case .loaded(let method) = phase, let writer {
        AttachPaymentMethodSheet(
          method: method, writer: writer, onFinished: handleWriteFinished)
      }
    }
    .sheet(isPresented: $updatePresented) {
      if case .loaded(let method) = phase, let writer {
        UpdatePaymentMethodSheet(
          method: method, writer: writer, onFinished: handleWriteFinished)
      }
    }
    .confirmationDialog(
      "Detach this payment method from its customer? Future payments "
        + "will need a new method.",
      isPresented: $detachConfirmed, titleVisibility: .visible
    ) {
      Button("Detach", role: .destructive) {
        Task { await runDetach() }
      }
      .accessibilityIdentifier("payments.methodDetach.confirm")
      Button("Cancel", role: .cancel) {}
    }
    .writeResultAlert($writeResult)
  }

  @ToolbarContentBuilder
  private var actionsToolbar: some ToolbarContent {
    ToolbarItem(placement: .primaryAction) {
      if let writer, case .loaded(let method) = phase {
        Menu {
          if method.customer.valueOrNil == nil {
            Button("Attach to customer…") { attachPresented = true }
              .accessibilityIdentifier("payments.method.attach")
          } else {
            Button("Detach from customer…", role: .destructive) { detachConfirmed = true }
              .accessibilityIdentifier("payments.method.detach")
          }
          Button("Edit billing details…") { updatePresented = true }
            .accessibilityIdentifier("payments.method.edit")
        } label: {
          Label("Actions", systemImage: "ellipsis.circle")
        }
        .accessibilityIdentifier("payments.method.actions")
      }
    }
  }

  private func handleWriteFinished(_ result: WriteResult) {
    attachPresented = false
    updatePresented = false
    writeResult = result
    Task { await load() }
  }

  private func runDetach() async {
    guard let writer, case .loaded(let method) = phase else { return }
    do {
      _ = try await writer.detachPaymentMethod(
        id: method.id, summary: "Detach " + method.id)
      writeResult = WriteResult(
        title: "Method detached", message: method.id + " has no customer now.")
      await load()
    } catch {
      writeResult = WriteResult(
        title: "Write failed", message: writeErrorMessage(error))
    }
  }

  @ViewBuilder
  private func details(_ method: PaymentMethod) -> some View {
    List {
      Section {
        HStack(alignment: .firstTextBaseline) {
          Text(method.type.rawValue)
            .font(.title3.weight(.semibold))
          Spacer(minLength: 8)
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("payments.method.type")
      }

      Section("Details") {
        PaymentFactRow(label: "Created", value: "\(method.created.date.formatted(date: .abbreviated, time: .omitted))")
        if let card = method.card {
          PaymentFactRow(label: "Card", value: "\(card.brand) •••• \(card.last4)")
        }
        if let customer = method.customer.valueOrNil?.idOrNil {
          PaymentFactRow(label: "Customer", value: customer)
        }
        if let name = method.billingDetails.name.valueOrNil {
          PaymentFactRow(label: "Name", value: name)
        }
        if let email = method.billingDetails.email.valueOrNil {
          PaymentFactRow(label: "Email", value: email)
        }
      }
    }
  }

  private func load() async {
    phase = .loading
    do {
      phase = .loaded(try await backend.retrievePaymentMethod(id: methodID))
    } catch {
      phase = .failed(String(describing: error))
    }
  }
}

/// The detail screen for one payment link, including its line items.
struct PaymentLinkDetailView: View {
  enum Phase: Equatable {
    case loading
    case loaded(PaymentLink)
    case failed(String)
  }

  let linkID: String
  let backend: any PaymentsBackend
  /// Nil for dashboard-locked accounts: no write controls are shown.
  let writer: PaymentsWriteService?

  @State private var phase: Phase = .loading
  @State private var lineItems: [Item]?
  @State private var itemsFailed = false
  @State private var editPresented = false
  @State private var writeResult: WriteResult?

  var body: some View {
    Group {
      switch phase {
      case .loading:
        ProgressView()
      case .failed(let message):
        ContentUnavailableView(
          "Couldn't load payment link",
          systemImage: "exclamationmark.triangle",
          description: Text(message)
        )
      case .loaded(let link):
        details(link)
      }
    }
    .navigationTitle("Payment Link")
    .navigationBarTitleDisplayMode(.inline)
    .task(id: linkID) { await load() }
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        if writer != nil, case .loaded = phase {
          Button("Edit…") { editPresented = true }
            .accessibilityIdentifier("payments.link.edit")
        }
      }
    }
    .sheet(isPresented: $editPresented) {
      if case .loaded(let link) = phase, let writer {
        EditPaymentLinkSheet(link: link, writer: writer, onFinished: handleWriteFinished)
      }
    }
    .writeResultAlert($writeResult)
  }

  private func handleWriteFinished(_ result: WriteResult) {
    editPresented = false
    writeResult = result
    Task { await load() }
  }

  @ViewBuilder
  private func details(_ link: PaymentLink) -> some View {
    List {
      Section {
        HStack(alignment: .firstTextBaseline) {
          Text(link.active ? "Active" : "Inactive")
            .font(.title3.weight(.semibold))
          Spacer(minLength: 8)
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("payments.link.status")
      }

      Section("URL") {
        Text(link.url)
          .font(.footnote.monospaced())
          .textSelection(.enabled)
      }

      MetadataSection(metadata: link.metadata)
      Section("Line Items") {
        if let lineItems {
          ForEach(Array(lineItems.enumerated()), id: \.offset) { _, item in
            HStack(alignment: .firstTextBaseline) {
              Text(item.description.valueOrNil ?? "Item")
                .font(.subheadline)
              Spacer(minLength: 8)
              Text(MoneyFormat.amount(item.amountTotal, currency: item.currency))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
          }
        } else if itemsFailed {
          Text("Couldn't load line items.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        } else {
          ProgressView()
        }
      }
    }
  }

  private func load() async {
    phase = .loading
    lineItems = nil
    itemsFailed = false
    do {
      let link = try await backend.retrievePaymentLink(id: linkID)
      phase = .loaded(link)
      do {
        lineItems = try await backend.paymentLinkLineItems(id: link.id)
      } catch {
        itemsFailed = true
      }
    } catch {
      phase = .failed(String(describing: error))
    }
  }
}
