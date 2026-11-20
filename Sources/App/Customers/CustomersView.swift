import GeistData
import StripeModels
import SwiftUI

/// A tapped row's destination: detail screens fetch by ID.
enum CustomerRoute: Hashable {
  case customer(String)
  case taxID(String)
}

/// The customers tab: the account's customers and their tax IDs. Writes
/// live behind the management-mode gate: create from the toolbar, edit and
/// delete on each detail screen.
struct CustomersView: View {
  let account: Account
  let backend: any CustomersBackend
  /// Nil for dashboard-locked accounts: no write UI exists at all.
  let writer: CustomersWriteService?

  @State private var model: CustomersModel?
  @State private var segment: CustomersModel.Segment = .customers
  @State private var createPresented = false
  @State private var filterPresented = false
  @State private var writeResult: WriteResult?
  @State private var searchText = ""

  var body: some View {
    Group {
      if let model {
        content(model)
      } else {
        ProgressView()
      }
    }
    .navigationTitle("Customers")
    .task(id: segment) {
      if model == nil {
        model = CustomersModel(backend: backend)
      }
      await model?.load(segment)
    }
    .toolbar {
      // Two separate items: a single .primaryAction ToolbarItem renders only
      // one of its children on iPadOS, which hid the create buttons.
      ToolbarItem(placement: .primaryAction) {
        Button {
          filterPresented = true
        } label: {
          Label(
            "Filter",
            systemImage: model?.filter.isEmpty == false
              ? "line.3.horizontal.decrease.circle.fill"
              : "line.3.horizontal.decrease.circle"
          )
        }
        .accessibilityIdentifier("customers.filter")
        .disabled(segment != .customers)
      }
      ToolbarItem(placement: .primaryAction) {
        if writer != nil, segment == .customers {
          Button {
            createPresented = true
          } label: {
            Label("New customer", systemImage: "plus")
          }
          .accessibilityIdentifier("customers.newCustomer")
        }
      }
    }
    .sheet(isPresented: $createPresented) {
      if let writer {
        CreateCustomerSheet(writer: writer, onFinished: handleWriteFinished)
      }
    }
    .sheet(isPresented: $filterPresented) {
      CustomersFilterSheet(current: model?.filter ?? .none) { applied in
        Task { await model?.apply(applied) }
      }
    }
    .writeResultAlert($writeResult)
  }

  private func handleWriteFinished(_ result: WriteResult) {
    createPresented = false
    writeResult = result
    Task { await model?.load(segment) }
  }

  @ViewBuilder
  private func content(_ model: CustomersModel) -> some View {
    VStack(spacing: 0) {
      Picker("Segment", selection: $segment) {
        ForEach(CustomersModel.Segment.allCases) { item in
          Text(item.label).tag(item)
        }
      }
      .pickerStyle(.segmented)
      .padding(.horizontal)
      .padding(.top, 8)
      .accessibilityIdentifier("customers.segment.\(segment.rawValue)")

      switch model.phase {
      case .failed(let message):
        ContentUnavailableView(
          "Couldn't load customers",
          systemImage: "exclamationmark.triangle",
          description: Text(message)
        )
      default:
        list(model)
      }
    }
  }

  @ViewBuilder
  private func list(_ model: CustomersModel) -> some View {
    if empty(model) {
      if model.phase == .loading {
        ProgressView()
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        ContentUnavailableView(
          "No \(segment.label)",
          systemImage: "person.crop.circle",
          description: Text(emptyDescription(model))
        )
      }
    } else {
      rows(model)
    }
  }

  @ViewBuilder
  private func rows(_ model: CustomersModel) -> some View {
    let list = List {
      switch segment {
      case .customers:
        ForEach(model.customers, id: \.id) { customer in
          NavigationLink(value: CustomerRoute.customer(customer.id)) {
            CustomerRow(customer: customer)
          }
          .accessibilityIdentifier("customers.row.\(customer.id)")
        }
      case .taxIDs:
        ForEach(model.taxIDs, id: \.id) { taxID in
          NavigationLink(value: CustomerRoute.taxID(taxID.id)) {
            TaxIDRow(taxID: taxID)
          }
          .accessibilityIdentifier("customers.taxRow.\(taxID.id)")
        }
      }
    }
    .overlay(alignment: .top) {
      if model.phase == .loading { ProgressView().padding(.top, 4) }
    }
    .navigationDestination(for: CustomerRoute.self) { route in
      CustomerDetailView(route: route, backend: backend, writer: writer)
    }

    if segment == .customers {
      list
        .searchable(
          text: $searchText,
          placement: .navigationBarDrawer(displayMode: .automatic),
          prompt: "Search customers"
        )
        .onSubmit(of: .search) {
          Task { await model.search(searchText) }
        }
    } else {
      list
    }
  }

  private func empty(_ model: CustomersModel) -> Bool {
    switch segment {
    case .customers: return model.customers.isEmpty
    case .taxIDs: return model.taxIDs.isEmpty
    }
  }

  /// Distinguishes "nothing exists yet" from "the filter narrowed it away".
  private func emptyDescription(_ model: CustomersModel) -> String {
    if !model.filter.isEmpty, segment == .customers {
      return "No results match the filter."
    }
    return "Nothing has been created yet."
  }
}

/// One customers-list row: name or email, with the balance when nonzero.
struct CustomerRow: View {
  let customer: Customer

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title)
        .font(.body)
      if let email = customer.email.valueOrNil, !email.isEmpty, email != title {
        Text(email)
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
      if let balance = customer.balance, balance != 0 {
        Text("Balance \(balance)")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(.vertical, 2)
  }

  private var title: String {
    if let name = customer.name?.valueOrNil, !name.isEmpty { return name }
    if let email = customer.email.valueOrNil, !email.isEmpty { return email }
    return customer.id
  }
}

/// One tax-ID row: type and value, with the owning customer when known.
struct TaxIDRow: View {
  let taxID: TaxId

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(taxID.type.rawValue)
        .font(.body)
      if !taxID.value.isEmpty {
        Text(taxID.value)
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    }
    .padding(.vertical, 2)
  }
}

/// Routes a tapped row to the right detail screen, fetching by ID.
struct CustomerDetailView: View {
  let route: CustomerRoute
  let backend: any CustomersBackend
  let writer: CustomersWriteService?

  var body: some View {
    switch route {
    case .customer(let id):
      CustomerDetailScreen(customerID: id, backend: backend, writer: writer)
    case .taxID(let id):
      TaxIDDetailScreen(taxIDID: id, backend: backend, writer: writer)
    }
  }
}
