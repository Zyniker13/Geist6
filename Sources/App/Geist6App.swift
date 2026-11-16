import SwiftUI

/// The Geist6 app entry point. The iPad shell (sidebar, account switcher,
/// home dashboard) arrives in M2 and M3; this target stays thin while the
/// portable package carries the logic.
@main
struct Geist6App: App {
  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}
