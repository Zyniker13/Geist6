import SwiftUI

/// The main home screen. Empty placeholder for M3 features.
struct HomeView: View {
  @Environment(AccountStore.self) private var accountStore
  @State private var activeAccount: Account?

  var body: some View {
    NavigationStack {
      if let account = activeAccount {
        VStack(spacing: 16) {
          HStack {
            Circle()
              .fill(Color(account.color))
              .frame(width: 20, height: 20)
            Text(account.name)
              .font(.headline)
            Text(account.live ? " (Live)" : " (Test)")
              .font(.caption)
              .foregroundStyle(.secondary)
          }

          Spacer()

          Text("Dashboard coming soon")
            .font(.title2)
            .foregroundStyle(.secondary)

          Text("Add an account to get started")
            .font(.caption)
            .foregroundStyle(.secondary)

          Spacer()
        }
        .padding()
      } else {
        ContentUnavailableView(
          "No account",
          systemImage: "creditcard",
          description: Text("Add a Stripe account from the Accounts screen.")
        )
      }
    }
    .task {
      activeAccount = await accountStore.active()
    }
  }
}
