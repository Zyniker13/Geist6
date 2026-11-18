import SwiftUI

/// Detail view for a single account. Pushed from the account list;
/// shows info and allows editing.
///
/// The account is read from the store's observable cache instead of
/// view-local `@State`: navigation and sheet re-creation can replace
/// this view's instance, and any state held locally is then lost
/// (edits stopped showing up). The store cache is shared by every
/// instance, so whichever one is on screen re-renders on a change.
struct AccountDetailView: View {
  let account: Account

  @Environment(AccountStore.self) private var accountStore
  @Environment(\.dismiss) private var dismiss
  @State private var isEditing = false

  /// Live value from the store, falling back to the pushed snapshot
  /// until the cache is warm. Only `account.id` is authoritative;
  /// the snapshot may be stale the moment this view is created.
  private var current: Account {
    accountStore.cached(id: account.id) ?? account
  }

  var body: some View {
    Form {
      Section("Account") {
        LabeledContent("Name", value: current.name)
        LabeledContent("Mode", value: current.live ? "Live" : "Test")
        LabeledContent("Dashboard lock", value: current.dashboardLock ? "On" : "Off")
      }

      Section("Connected accounts") {
        if current.connectedAccounts.isEmpty {
          Text("No connected accounts")
            .foregroundStyle(.secondary)
        } else {
          ForEach(current.connectedAccounts) { connected in
            LabeledContent(connected.displayName ?? connected.id, value: connected.type.rawValue.capitalized)
          }
        }
      }
    }
    .navigationTitle(current.name)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button("Edit") {
          isEditing = true
        }
        .accessibilityIdentifier("detail.edit")
      }
      ToolbarItem(placement: .confirmationAction) {
        Button("Done") {
          dismiss()
        }
        .accessibilityIdentifier("detail.done")
      }
    }
    .task(id: account.id) {
      // Warm the cache so the view shows fresh data even if it was
      // created from a stale snapshot.
      _ = await accountStore.get(id: account.id)
    }
    .sheet(isPresented: $isEditing, onDismiss: {
      Task { await accountStore.get(id: account.id) }
    }, content: {
      EditAccountView(account: current, accountStore: accountStore)
    })
  }
}
