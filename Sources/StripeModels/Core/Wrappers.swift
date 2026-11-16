import Foundation

/// A raw JSON value: the universal fallback that keeps data the pinned spec
/// does not describe, so decoding never drops information.
public enum JSONValue: Sendable, Codable, Equatable, Hashable {
  case string(String)
  case int(Int)
  case double(Double)
  case bool(Bool)
  case null
  case array([JSONValue])
  case object([String: JSONValue])

  public var stringValue: String? {
    if case .string(let value) = self { return value }
    return nil
  }

  public var intValue: Int? {
    switch self {
    case .int(let value): return value
    case .double(let value): return Int(value)
    default: return nil
    }
  }

  public var boolValue: Bool? {
    if case .bool(let value) = self { return value }
    return nil
  }

  public var objectValue: [String: JSONValue]? {
    if case .object(let value) = self { return value }
    return nil
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      self = .null
    } else if let value = try? container.decode(Bool.self) {
      self = .bool(value)
    } else if let value = try? container.decode(Int.self) {
      self = .int(value)
    } else if let value = try? container.decode(Double.self) {
      self = .double(value)
    } else if let value = try? container.decode(String.self) {
      self = .string(value)
    } else if let value = try? container.decode([JSONValue].self) {
      self = .array(value)
    } else if let value = try? container.decode([String: JSONValue].self) {
      self = .object(value)
    } else {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "JSONValue could not decode this value"
      )
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .string(let value): try container.encode(value)
    case .int(let value): try container.encode(value)
    case .double(let value): try container.encode(value)
    case .bool(let value): try container.encode(value)
    case .null: try container.encodeNil()
    case .array(let value): try container.encode(value)
    case .object(let value): try container.encode(value)
    }
  }
}

/// Stripe timestamps arrive as integer seconds since the Unix epoch.
public struct StripeTimestamp: Sendable, Codable, Equatable, Hashable {
  public var seconds: Int

  public init(seconds: Int) {
    self.seconds = seconds
  }

  public init(_ date: Date) {
    self.seconds = Int(date.timeIntervalSince1970.rounded())
  }

  public var date: Date {
    Date(timeIntervalSince1970: TimeInterval(seconds))
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let seconds = try? container.decode(Int.self) {
      self.seconds = seconds
    } else if let seconds = try? container.decode(Double.self) {
      self.seconds = Int(seconds)
    } else {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "expected a Unix-epoch timestamp"
      )
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(seconds)
  }
}

/// Protocol implemented by every generated enum that keeps undocumented
/// values instead of dropping them.
public protocol LosslessEnum: Sendable, Equatable, Hashable, Codable {
  init(rawValue: String)
  var rawValue: String { get }
}

/// The four-state field shape the pinned spec's nullability rules produce:
/// absent (nil), present with a value, or explicitly null.
public indirect enum Nullable<Value: Codable & Sendable & Hashable>: Sendable, Codable, Equatable,
  Hashable
{
  case value(Value)
  case null

  public var valueOrNil: Value? {
    if case .value(let value) = self { return value }
    return nil
  }

  public init(_ value: Value?) {
    if let value = value {
      self = .value(value)
    } else {
      self = .null
    }
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      self = .null
    } else {
      self = .value(try container.decode(Value.self))
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .value(let value): try container.encode(value)
    case .null: try container.encodeNil()
    }
  }
}

/// An expandable reference: the API returns either an ID or, when expanded,
/// the full object.
public indirect enum Expandable<Value: Codable & Sendable & Hashable>: Sendable, Codable, Equatable,
  Hashable
{
  case id(String)
  case object(Value)

  public var idOrNil: String? {
    switch self {
    case .id(let id): return id
    case .object(let object): return nil
    }
  }

  public var objectOrNil: Value? {
    switch self {
    case .id: return nil
    case .object(let object): return object
    }
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let id = try? container.decode(String.self) {
      self = .id(id)
    } else {
      self = .object(try container.decode(Value.self))
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .id(let id): try container.encode(id)
    case .object(let object): try container.encode(object)
    }
  }
}

/// Request-side wrapper for Stripe's "pass an empty string to clear" fields.
public enum Clearable<Value: Codable & Sendable & Hashable>: Sendable, Codable, Hashable {
  case value(Value)
  case clear

  public init(_ value: Value?) {
    if let value = value {
      self = .value(value)
    } else {
      self = .clear
    }
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let empty = try? container.decode(String.self), empty.isEmpty {
      self = .clear
    } else {
      self = .value(try container.decode(Value.self))
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .value(let value): try container.encode(value)
    case .clear: try container.encode("")
    }
  }
}

// MARK: - Pagination protocols

/// An object with a Stripe ID (used to walk cursor-paginated lists).
public protocol StripeIdentified {
  var id: String { get }
}

/// A `/v1` list response.
public protocol StripeList: Sendable, Decodable {
  associatedtype Item
  var data: [Item] { get }
  var hasMore: Bool { get }
}

/// A `/v1` search response: a list that also carries a `next_page` cursor.
public protocol StripeSearchResult: StripeList {
  /// The cursor for the next page, unwrapped from the nullable field.
  var nextPageToken: String? { get }
}

/// A `/v2` page response, addressed by URL tokens.
public protocol V2Page: Sendable, Decodable {
  associatedtype Item
  var data: [Item] { get }
  /// The token for the next page, unwrapped from the nullable field.
  var nextPageUrlToken: String? { get }
  var previousPageUrlToken: String? { get }
}

/// The cursor fields `/v1` list parameter structs carry when the endpoint
/// paginates.
public protocol V1ListParams: Sendable, Encodable {
  var limit: Int? { get set }
  var startingAfter: String? { get set }
  var endingBefore: String? { get set }
}
