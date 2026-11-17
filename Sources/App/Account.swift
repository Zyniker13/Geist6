import Foundation

/// A Stripe account known to the app.
public struct Account: Identifiable, Codable, Sendable, Hashable {
  public var id: UUID
  public var name: String
  public var color: String
  public var dashboardLock: Bool
  public var apiKey: String
  public var live: Bool
  public var connectedAccounts: [ConnectedAccount]

  public init(
    id: UUID = UUID(),
    name: String,
    color: String,
    dashboardLock: Bool,
    apiKey: String,
    live: Bool,
    connectedAccounts: [ConnectedAccount] = []
  ) {
    self.id = id
    self.name = name
    self.color = color
    self.dashboardLock = dashboardLock
    self.apiKey = apiKey
    self.live = live
    self.connectedAccounts = connectedAccounts
  }

  public static func == (lhs: Account, rhs: Account) -> Bool {
    lhs.id == rhs.id
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}

/// A connected account that can be acted on via `Stripe-Account`.
public struct ConnectedAccount: Codable, Sendable, Hashable, Identifiable {
  public var id: String
  public var displayName: String?
  public var email: String?
  public var type: ConnectedAccountType

  public enum ConnectedAccountType: String, Codable, Sendable {
    case standard
    case express
    case custom
    case none
  }
}
