import SwiftUI

private enum MainTab: Hashable {
  case home
  case accounts
}

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

  // UI tests can start directly on the Accounts tab.
  @State private var selection: MainTab = CommandLine.arguments.contains("--uitest-tab-accounts")
    ? .accounts : .home

  var body: some Scene {
    WindowGroup {
      TabView(selection: $selection) {
        HomeView()
          .tabItem {
            Label("Home", systemImage: "house")
          }
          .tag(MainTab.home)
        AccountListView()
          .tabItem {
            Label("Accounts", systemImage: "creditcard")
          }
          .tag(MainTab.accounts)
      }
      .environment(accountStore)
    }
  }
}
