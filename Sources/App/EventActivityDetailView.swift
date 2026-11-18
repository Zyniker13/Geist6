import GeistData
import SwiftUI

/// The detail screen for an event opened from the home activity feed.
///
/// Fetches the event by ID through the universal open-by-ID service
/// and shows it with the generic key/value viewer.
struct EventActivityDetailView: View {
  let eventID: String
  let backend: any StripeDataBackend

  @State private var phase: Phase = .loading

  enum Phase {
    case loading
    case loaded(StripeJSON)
    case failed(String)
  }

  var body: some View {
    Group {
      switch phase {
      case .loading:
        ProgressView()
      case .failed(let message):
        ContentUnavailableView {
          Label("Event unavailable", systemImage: "waveform.slash")
        } description: {
          Text(message)
        }
      case .loaded(let json):
        ObjectDetailView(json: json, title: "Event")
      }
    }
    .navigationTitle(eventID)
    .navigationBarTitleDisplayMode(.inline)
    .task(id: eventID) {
      await load()
    }
  }

  @MainActor
  private func load() async {
    phase = .loading
    do {
      let resolved = try await ObjectByIDService(backend: backend).fetch(eventID)
      phase = .loaded(resolved.json)
    } catch {
      phase = .failed(DashboardModel.message(of: error))
    }
  }
}
