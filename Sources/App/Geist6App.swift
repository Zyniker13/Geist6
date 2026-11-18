import SwiftUI

@main
struct Geist6App: App {
  @State private var accountStore: AccountStore = {
    // UI tests launch with --uitest-reset so every test starts with an
    // empty store regardless of what earlier runs left in the simulator
    // keychain. The wipe runs synchronously before any view exists.
    if CommandLine.arguments.contains("--uitest-reset") {
      KeychainStore.wipeAccountsSync()
    }
    return AccountStore()
  }()

  var body: some Scene {
    WindowGroup {
      AppShellView()
        .environment(accountStore)
    }

    // A window opened for a specific account, for example through
    // "Open in New Window" in the sidebar (decision 0011).
    WindowGroup("Geist6", for: UUID.self) { $seedAccountID in
      AppShellView(seedAccountID: seedAccountID)
        .environment(accountStore)
    }
  }
}
