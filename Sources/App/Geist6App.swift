import SwiftUI

@main
struct Geist6App: App {
  @State private var accountStore = AccountStore()

  var body: some Scene {
    WindowGroup {
      TabView {
        HomeView()
          .tabItem {
            Label("Home", systemImage: "house")
          }
        AccountListView()
          .tabItem {
            Label("Accounts", systemImage: "creditcard")
          }
      }
      .environment(accountStore)
    }
  }
}
