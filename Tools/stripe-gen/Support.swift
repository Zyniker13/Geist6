import Foundation

// Shared model of the parts of Stripe's OpenAPI definition that the
// generator consumes. Parsing is tolerant: anything the generator does not
// understand degrades to a raw JSON value field rather than failing the
// whole run.

struct RawSchema {
  let key: String
  let value: [String: Any]
}

enum SpecParse {

  static func schemas(from spec: [String: Any]) throws -> [String: [String: Any]] {
    guard let components = spec["components"] as? [String: Any],
      let schemas = components["schemas"] as? [String: [String: Any]]
    else {
      throw GenError.unexpectedShape("components.schemas")
    }
    return schemas
  }

  static func paths(from spec: [String: Any]) throws -> [String: [String: Any]] {
    guard let paths = spec["paths"] as? [String: [String: Any]] else {
      throw GenError.unexpectedShape("paths")
    }
    return paths
  }

  static func string(_ dict: [String: Any], _ key: String) -> String? {
    dict[key] as? String
  }

  static func dict(_ value: Any?) -> [String: Any]? {
    value as? [String: Any]
  }

  static func stringList(_ value: Any?) -> [String] {
    (value as? [Any])?.compactMap { $0 as? String } ?? []
  }
}

enum GenError: Error, CustomStringConvertible {
  case unexpectedShape(String)

  var description: String {
    switch self {
    case .unexpectedShape(let detail):
      return "unexpected spec shape: \(detail)"
    }
  }
}

// MARK: - Swift identifier helpers

enum Naming {

  /// Separators and characters that never appear in a Swift identifier.
  private static let separators = CharacterSet(charactersIn: "_-. /:,{}[]()@#$&+?!'\"\\<>|*~^%=")

  /// Converts a schema key, JSON field, or class name into PascalCase.
  static func pascal(_ raw: String) -> String {
    var parts = raw.components(separatedBy: separators).filter { !$0.isEmpty }
    // Split camelCase boundaries so "chargeList" becomes "ChargeList".
    parts = parts.flatMap(splitCamel)
    let joined = parts.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
    var name = joined.isEmpty ? "Anonymous" : joined
    if let first = name.first, first.isNumber {
      name = "N" + name
    }
    if swiftKeywords.contains(name.lowercased()) {
      name = "S\(name)"
    }
    return name
  }

  /// Converts a JSON field name into a lowerCamelCase Swift property name.
  static func camel(_ raw: String) -> String {
    let pascalName = pascal(raw)
    guard let first = pascalName.first else { return "field" }
    let lowered = first.lowercased() + pascalName.dropFirst()
    if swiftKeywords.contains(lowered) {
      return "`\(lowered)`"
    }
    return lowered
  }

  private static func splitCamel(_ word: String) -> [String] {
    var out: [String] = []
    var current = ""
    var previousWasUpper = false
    for ch in word {
      if ch.isUppercase, !current.isEmpty, !previousWasUpper {
        out.append(current)
        current = String(ch)
      } else {
        current.append(ch)
      }
      previousWasUpper = ch.isUppercase
    }
    if !current.isEmpty { out.append(current) }
    return out
  }

  /// Swift keywords that cannot be bare identifiers.
  private static let swiftKeywords: Set<String> = [
    "class", "deinit", "enum", "extension", "func", "import", "init", "inout",
    "internal", "let", "operator", "private", "protocol", "public", "static",
    "struct", "subscript", "typealias", "var", "break", "case", "continue",
    "default", "defer", "do", "else", "fallthrough", "for", "guard", "if",
    "in", "repeat", "return", "switch", "where", "while", "as", "catch",
    "false", "is", "nil", "rethrows", "super", "self", "throw", "throws",
    "true", "try", "await", "async", "some", "each", "Type", "Self"
  ]
}

/// hands out collision-free Swift type names.
final class NameRegistry {
  private var used = Set<String>()
  private var assignments: [String: String] = [:]

  /// Returns a stable, unique Swift type name for `base`.
  func unique(_ base: String) -> String {
    if let assigned = assignments[base] { return assigned }
    var candidate = base
    var counter = 2
    while used.contains(candidate) {
      candidate = base + "\(counter)"
      counter += 1
    }
    used.insert(candidate)
    assignments[base] = candidate
    return candidate
  }

  func has(_ name: String) -> Bool { used.contains(name) }
}
