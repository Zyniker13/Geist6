import GeistData
import GeistMetrics
import StripeClient
import StripeModels
import SwiftUI

/// Runs searches for one account (decision 0013: Search API first,
/// list-filter fallback when it is unavailable).
@MainActor
@Observable
final class SearchModel {
  enum Phase: Equatable {
    case idle
    case searching
    case loaded(SearchResultSet)
    case failed(String)
  }

  var query: String
  private(set) var phase: Phase = .idle
  private let service: SearchService

  init(backend: any StripeDataBackend, initialQuery: String) {
    service = SearchService(backend: backend)
    query = initialQuery
  }

  func search() async {
    let trimmed = query.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else {
      phase = .idle
      return
    }
    phase = .searching
    do {
      phase = .loaded(try await service.search(trimmed))
    } catch {
      phase = .failed(DashboardModel.message(of: error))
    }
  }
}

/// The search screen for one account: results from the Search API, the
/// list-filter fallback, and universal open-by-ID (decision 0012).
struct SearchView: View {
  let account: Account
  let initialQuery: String

  @State private var model: SearchModel?
  @State private var selectedHit: SearchHit?

  var body: some View {
    Group {
      if let model {
        content(model)
          .navigationDestination(item: $selectedHit) { hit in
            SearchHitView(hit: hit)
          }
      } else {
        ProgressView()
      }
    }
    .navigationTitle("Search")
    .navigationBarTitleDisplayMode(.inline)
    // The sidebar's search field is the input (decision 0011); this view
    // re-runs the search whenever the submitted query changes.
    .task(id: initialQuery) {
      if model == nil {
        let client = StripeClient(
          apiKey: account.apiKey,
          mode: .management,
          baseURL: AppConfig.effectiveBaseURL
        )
        model = SearchModel(backend: client, initialQuery: initialQuery)
      } else if model?.query != initialQuery {
        model?.query = initialQuery
      }
      await model?.search()
    }
  }

  @ViewBuilder
  private func content(_ model: SearchModel) -> some View {
    switch model.phase {
    case .idle:
      ContentUnavailableView.search
    case .searching:
      ProgressView()
        .padding(.top, 60)
    case .failed(let message):
      ContentUnavailableView {
        Label("Search failed", systemImage: "magnifyingglass")
      } description: {
        Text(message)
      }
    case .loaded(let results):
      if results.hits.isEmpty {
        ContentUnavailableView.search(text: model.query)
      } else {
        List(results.hits) { hit in
          Button {
            selectedHit = hit
          } label: {
            SearchHitRow(hit: hit)
          }
          .accessibilityIdentifier("search.hit.\(hit.id)")
        }
        .listStyle(.insetGrouped)
      }
    }
  }
}

/// Search result rows.
extension SearchHit {
  /// The secondary line under the title: the kind plus the fields that
  /// explain why the hit matched — amount and state for a charge, email
  /// for a named customer. Keeps a row self-explanatory, especially for
  /// amount searches.
  var caption: String {
    switch self {
    case .charge(let charge):
      let money = MoneyFormat.string(Money(amount: charge.amount, currency: charge.currency))
      return "Charge · \(money) · \(charge.status.rawValue)"
    case .customer(let customer) where customer.name?.valueOrNil != nil:
      return customer.email.valueOrNil.map { "Customer · \($0)" } ?? "Customer"
    case .customer:
      return "Customer"
    case .object(let kind, _, _):
      return kind.label
    }
  }
}

/// One search result row.
struct SearchHitRow: View {
  let hit: SearchHit

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: Self.icon(hit))
        .foregroundStyle(.secondary)
        .frame(width: 24)
      VStack(alignment: .leading, spacing: 2) {
        Text(hit.title)
          .lineLimit(1)
          .foregroundStyle(.primary)
        Text(hit.caption)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
    }
    .accessibilityElement(children: .combine)
  }

  static func icon(_ hit: SearchHit) -> String {
    switch hit.objectKind {
    case .charge, .paymentIntent, .setupIntent: "creditcard"
    case .customer: "person"
    case .payout: "banknote"
    case .event: "waveform"
    default: "doc"
    }
  }
}

/// The detail screen for a search hit: typed models show their core fields,
/// raw objects show the full key/value list.
struct SearchHitView: View {
  let hit: SearchHit

  var body: some View {
    switch hit {
    case .charge(let charge):
      ObjectDetailView(fields: Self.chargeFields(charge), title: "Charge")
    case .customer(let customer):
      ObjectDetailView(
        fields: [
          ("id", customer.id),
          ("name", customer.name?.valueOrNil ?? "—"),
          ("email", customer.email.valueOrNil ?? "—"),
          ("created", Self.dateFormatter.string(from: customer.created.date))
        ],
        title: "Customer"
      )
    case .object(let kind, _, let json):
      // Kinds without a typed detail view (payouts, events, invoices,
      // everything else) show the full object as key/value pairs.
      ObjectDetailView(json: json, title: kind.label)
    }
  }

  private static func chargeFields(_ charge: Charge) -> [(String, String)] {
    var fields: [(String, String)] = [
      ("id", charge.id),
      ("status", charge.status.rawValue),
      ("amount", HomeView.money(Money(amount: charge.amount, currency: charge.currency))),
      ("created", dateFormatter.string(from: charge.created.date))
    ]
    if let description = charge.description.valueOrNil {
      fields.append(("description", description))
    }
    if let customer = customerID(of: charge) {
      fields.append(("customer", customer))
    }
    return fields
  }

  private static func customerID(of charge: Charge) -> String? {
    switch charge.customer.valueOrNil {
    case .string(let id): return id
    case .customer(let customer): return customer.id
    default: return nil
    }
  }

  private static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
  }()
}
