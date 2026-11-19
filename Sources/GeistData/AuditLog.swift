// AuditLog.swift — Sources/GeistData
// Local audit trail for every write the app performs. An entry records what
// was done, when, against which account, the idempotency key that made the
// request safe to retry, and the outcome. Entries never contain API keys;
// the summary is user-written text, not raw request payloads.

import Foundation

/// One recorded write attempt (successful, failed, or refused).
public struct AuditEntry: Codable, Sendable, Identifiable, Equatable {
  public var id: UUID
  public var date: Date
  public var accountID: String
  public var accountName: String
  public var summary: String
  public var method: String
  public var path: String
  public var idempotencyKey: String
  public var requestID: String?
  public var outcome: String

  public init(
    id: UUID = UUID(),
    date: Date = Date(),
    accountID: String,
    accountName: String,
    summary: String,
    method: String,
    path: String,
    idempotencyKey: String,
    requestID: String? = nil,
    outcome: String
  ) {
    self.id = id
    self.date = date
    self.accountID = accountID
    self.accountName = accountName
    self.summary = summary
    self.method = method
    self.path = path
    self.idempotencyKey = idempotencyKey
    self.requestID = requestID
    self.outcome = outcome
  }
}

/// Storage for audit entries. Actors: recording and reading are serialized.
public protocol AuditStore: Sendable {
  func record(_ entry: AuditEntry) async
  func entries(limit: Int) async -> [AuditEntry]
}

/// In-memory store for tests and previews.
public actor InMemoryAuditStore: AuditStore {
  private var entries: [AuditEntry] = []

  public init() {}

  public func record(_ entry: AuditEntry) async {
    entries.append(entry)
  }

  public func entries(limit: Int) async -> [AuditEntry] {
    Array(entries.suffix(limit).reversed())
  }
}

/// JSON-lines file store. Default location is
/// `Application Support/Geist6/audit.jsonl`.
public actor FileAuditStore: AuditStore {
  private let url: URL
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder

  public init(directory: URL? = nil) {
    let base =
      directory
      ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("Geist6", isDirectory: true)
    try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    url = base.appendingPathComponent("audit.jsonl")
    encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
  }

  public func record(_ entry: AuditEntry) async {
    guard let data = try? encoder.encode(entry) else { return }
    let line = data + Data("\n".utf8)
    if let handle = try? FileHandle(forWritingTo: url) {
      defer { try? handle.close() }
      _ = try? handle.seekToEnd()
      try? handle.write(contentsOf: line)
    } else {
      try? line.write(to: url, options: .atomic)
    }
  }

  /// Newest first, capped at `limit`.
  public func entries(limit: Int) async -> [AuditEntry] {
    guard let data = try? Data(contentsOf: url) else { return [] }
    var result: [AuditEntry] = []
    for line in data.split(separator: 0x0A).reversed() {
      if result.count >= limit { break }
      guard !line.isEmpty, let entry = try? decoder.decode(AuditEntry.self, from: Data(line))
      else { continue }
      result.append(entry)
    }
    return result
  }
}
