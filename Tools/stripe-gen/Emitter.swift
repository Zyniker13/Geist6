import Foundation

// Schema classification and Swift type emission for stripe-gen.

enum ParsedSchema {

  /// Field with its JSON name and schema.
  struct Field {
    let jsonName: String
    let schema: [String: Any]
    let required: Bool
  }

  static func classify(_ schema: [String: Any]) -> ParsedSchema {
    if let ref = schema["$ref"] as? String {
      // A bare ref behaves like the object it points to; the type
      // resolver handles refs before classification.
      _ = ref
    }
    if let anyOf = (schema["oneOf"] ?? schema["anyOf"]) as? [[String: Any]] {
      return .union(branches: anyOf)
    }
    if let allOf = schema["allOf"] as? [[String: Any]] {
      return .allOf(branches: allOf)
    }
    if let arrayItem = (schema["items"] as? [String: Any]) {
      return .array(item: arrayItem)
    }
    let type = schema["type"] as? String
    switch type {
    case "string":
      if let values = schema["enum"] as? [Any], !values.isEmpty {
        return .stringEnum(values: values.compactMap { $0 as? String })
      }
      return .string
    case "integer":
      return .integer
    case "number":
      return .number
    case "boolean":
      return .boolean
    case "object":
      let props = (schema["properties"] as? [String: [String: Any]]) ?? [:]
      let required = Set((schema["required"] as? [Any])?.compactMap { $0 as? String } ?? [])
      if props.isEmpty {
        let additional = schema["additionalProperties"]
        if additional is [String: Any] {
          return .freeObject
        }
        // Stripe uses empty marker objects in params (for example
        // `alipay: {}`); model them as empty structs so the field
        // keeps its name and type.
        return .emptyObject
      }
      let fields = props.keys.sorted().map { key in
        Field(jsonName: key, schema: props[key] ?? [:], required: required.contains(key))
      }
      return .object(fields: fields)
    default:
      return .unknown("type \(type ?? "absent")")
    }
  }

  case object(fields: [Field])
  case emptyObject
  case stringEnum(values: [String])
  case string
  case integer
  case number
  case boolean
  case array(item: [String: Any])
  case union(branches: [[String: Any]])
  case allOf(branches: [[String: Any]])
  case freeObject
  case unknown(String)
}

/// One generated Swift type, ready to write into a bucketed file.
struct GeneratedType {
  let bucket: String
  let name: String
  let code: String
  /// The Swift type of the `data` array element for list/search containers,
  /// or nil for other shapes. Two inline response schemas can share a title
  /// (every Stripe search response is titled "SearchResult") while carrying
  /// different item types; the distinct item type is what tells them apart.
  let dataItemType: String?
}

/// Resolves schemas to Swift type names and collects every type that must be
/// emitted. All types are emitted at top level (no nesting), so the module
/// needs no declaration ordering.
final class TypeEmitter {

  let registry = NameRegistry()
  private var pending: [(bucket: String, type: GeneratedType)] = []
  private var emittedNames = Set<String>()

  var types: [GeneratedType] { pending.map(\.type) }

  /// The schema key a `$ref` points to.
  static func refKey(_ ref: String) -> String {
    guard let range = ref.range(of: "#/components/schemas/") else { return ref }
    return String(ref[range.upperBound...])
  }

  /// Registers the Swift type name for a component schema key (idempotent).
  func nameForSchemaKey(_ key: String) -> String {
    if let assigned = schemaKeyNames[key] {
      return assigned
    }
    // Unseeded key (should not happen); fall back to a unique name.
    let name = registry.unique(Naming.pascal(key))
    schemaKeyNames[key] = name
    return name
  }

  /// The file bucket for a component schema: its key prefix before the
  /// first separator, with v2 grouped separately.
  static func bucket(forSchemaKey key: String) -> String {
    if key.hasPrefix("v2") { return "v2" }
    let cut1 = key.firstIndex(of: ".")
    let cut2 = key.firstIndex(of: "_")
    let cuts = [cut1, cut2].compactMap { $0 }
    if let first = cuts.min(), first != key.startIndex {
      return String(key[key.startIndex..<first])
    }
    return key
  }

  /// Resolves a property's schema into a Swift type expression, registering
  /// any helper types needed (enums, inline objects, unions).
  func swiftType(
    for schema: [String: Any],
    fallbackName: String,
    bucket: String
  ) -> String {
    // Const discriminator fields ({"const": "billing.alert.triggered"})
    // are fixed strings, not shapes of their own.
    if schema["const"] is String {
      return "String"
    }

    // Direct reference.
    if let ref = schema["$ref"] as? String {
      let key = TypeEmitter.refKey(ref)
      return nameForSchemaKey(key)
    }

    // Expandable: anyOf [string-ish, $ref] where the string branch has no
    // enum. Stripe marks every expandable field this way and records the
    // expansion targets in x-expansionResources.
    if let anyOf = (schema["oneOf"] ?? schema["anyOf"]) as? [[String: Any]], anyOf.count == 2 {
      let stringBranch = anyOf.first { isPlainString($0) }
      let refBranch = anyOf.first { $0["$ref"] != nil }
      if stringBranch != nil, let refBranch = refBranch,
        let ref = refBranch["$ref"] as? String {
        let target = nameForSchemaKey(TypeEmitter.refKey(ref))
        return "Expandable<\(target)>"
      }
      // Clearable: anyOf [T, enum [""]] — the request-side "pass empty
      // string to clear" pattern.
      func isClearBranch(_ branch: [String: Any]) -> Bool {
        guard let values = branch["enum"] as? [Any], values.count == 1,
          (values[0] as? String) == ""
        else { return false }
        return true
      }
      let clearBranch = anyOf.first(where: isClearBranch)
      if clearBranch != nil, anyOf.count == 2 {
        let other = anyOf.first { branch in !isClearBranch(branch) } ?? anyOf[0]
        let inner = swiftType(for: other, fallbackName: fallbackName, bucket: bucket)
        return "Clearable<\(inner)>"
      }
    }

    // A single-branch anyOf/oneOf is not polymorphic: Stripe uses it as a
    // nullable/reference wrapper (for example charge.fraud_details is
    // `anyOf: [$ref charge_fraud_details]`). Mapping it to a union enum
    // named after the branch made the union reference itself, and its
    // synthesized Codable recursed until the stack overflowed at decode
    // time. Classify the branch directly instead.
    if let anyOf = (schema["oneOf"] ?? schema["anyOf"]) as? [[String: Any]],
      anyOf.count == 1, let only = anyOf.first {
      return swiftType(for: only, fallbackName: fallbackName, bucket: bucket)
    }

    let classified = ParsedSchema.classify(schema)
    switch classified {
    case .object, .allOf, .emptyObject:
      return registerObjectLike(schema, fallbackName: fallbackName, bucket: bucket)
    case .stringEnum(let values):
      return registerEnum(values: values, fallbackName: fallbackName, bucket: bucket)
    case .string:
      return "String"
    case .integer:
      return schema["format"] as? String == "unix-time" ? "StripeTimestamp" : "Int"
    case .number:
      return "Decimal"
    case .boolean:
      return "Bool"
    case .array(let item):
      let inner = swiftType(for: item, fallbackName: fallbackName + "Item", bucket: bucket)
      return "[\(inner)]"
    case .union(let branches):
      return registerUnion(branches: branches, fallbackName: fallbackName, bucket: bucket)
    case .freeObject:
      // Metadata-style maps: string values when documented, otherwise raw.
      if case .string = ParsedSchema.classify(
        schema["additionalProperties"] as? [String: Any] ?? [:]) {
        return "[String: String]"
      }
      return "[String: JSONValue]"
    case .unknown(let reason):
      emitUnknownComment(reason, fallbackName: fallbackName)
      return "JSONValue"
    }
  }

  private func isPlainString(_ schema: [String: Any]) -> Bool {
    guard schema["$ref"] == nil,
      (schema["type"] as? String) == "string",
      schema["enum"] == nil
    else { return false }
    return true
  }

  private func emitUnknownComment(_ reason: String, fallbackName: String) {
    pendingUnknowns.insert("\(fallbackName): \(reason)")
  }

  var unknowns: Set<String> { pendingUnknowns }
  private var pendingUnknowns = Set<String>()
  private var enumsByValues: [String: String] = [:]

  // MARK: Object emission

  private func registerObjectLike(
    _ schema: [String: Any],
    fallbackName: String,
    bucket: String
  ) -> String {
    // Merge allOf branches when present.
    var merged: [String: Any] = schema
    if let allOf = schema["allOf"] as? [[String: Any]] {
      var properties: [String: Any] = schema["properties"] as? [String: Any] ?? [:]
      var required: [Any] = schema["required"] as? [Any] ?? []
      for branch in allOf {
        if let ref = branch["$ref"] as? String {
          // allOf + $ref inheritance: inline the referenced schema's
          // properties if reachable.
          if let branchProps = self.inlinedProperties[TypeEmitter.refKey(ref)] {
            for (key, value) in branchProps where properties[key] == nil {
              properties[key] = value
            }
            if let req = (self.inlinedSchemas[TypeEmitter.refKey(ref)]?["required"] as? [Any]) {
              required.append(contentsOf: req)
            }
          }
        }
        if let branchProps = branch["properties"] as? [String: Any] {
          for (key, value) in branchProps where properties[key] == nil {
            properties[key] = value
          }
        }
        if let req = branch["required"] as? [Any] {
          required.append(contentsOf: req)
        }
      }
      merged = schema
      merged["properties"] = properties
      merged["required"] = required
      merged["allOf"] = nil
    }

    let name = registry.unique(fallbackName)
    guard !emittedNames.contains(name) else { return name }
    emittedNames.insert(name)

    let props = (merged["properties"] as? [String: [String: Any]]) ?? [:]
    let required = Set((merged["required"] as? [Any])?.compactMap { $0 as? String } ?? [])
    let fields = props.keys.sorted().map { key in
      ParsedSchema.Field(jsonName: key, schema: props[key] ?? [:], required: required.contains(key))
    }
    // Objects with a required, non-nullable string `id` identify
    // themselves, which cursor pagination relies on.
    var conformances: [String] = []
    let hasPlainId = fields.contains { field in
      guard field.jsonName == "id", field.required else { return false }
      return (field.schema["type"] as? String) == "string"
        && field.schema["nullable"] as? Bool != true
    }
    if hasPlainId {
      conformances.append("StripeIdentified")
    }
    let code = emitStruct(
      name: name, fields: fields, bucket: bucket, extraConformances: conformances)
    pending.append((bucket, GeneratedType(bucket: bucket, name: name, code: code, dataItemType: nil)))
    return name
  }

  /// Fields the pinned spec marks required that Stripe in practice omits
  /// on some shapes (stripe-mock follows the live API). Typed as plain
  /// optionals so absence decodes to nil instead of keyNotFound. Each
  /// entry is "<Struct>.<field>"; keep it short and documented.
  static let legacyRequiredOptional: Set<String> = [
    "SubscriptionItem.plan",
    // Account-session components: the live API (and stripe-mock) omit the
    // three reporting/terminal configs unless requested; the pinned spec
    // still lists them as required.
    "ConnectEmbeddedAccountSessionCreateComponents.reporting_chart",
    "ConnectEmbeddedAccountSessionCreateComponents.terminal_hardware_orders",
    "ConnectEmbeddedAccountSessionCreateComponents.terminal_hardware_shop",
  ]

  /// Lets allOf branches with $ref inline the referenced object's
  /// properties; populated lazily by the driver.
  var inlinedProperties: [String: [String: Any]] = [:]
  var inlinedSchemas: [String: [String: Any]] = [:]

  /// One stable Swift name per component schema key. Distinct keys must
  /// never share a name: `Naming.pascal` collapses both "." and "_", so
  /// "billing.alert.triggered" (event wrapper) and "billing.alert_triggered"
  /// (the object) would otherwise collide and one shape would be lost.
  private var schemaKeyNames: [String: String] = [:]

  func seedInliner(schemas: [String: [String: Any]]) {
    for key in schemas.keys.sorted() {
      let schema = schemas[key] ?? [:]
      var base = Naming.pascal(key)
      // Event payload wrappers carry x-stripeEvent; suffix them so the
      // wrapped object keeps the plain name.
      if schema["x-stripeEvent"] != nil {
        base += "Event"
      }
      // A type named `Error` shadows Swift.Error at every use site in
      // importing modules; never emit one.
      if base == "Error" {
        base = "ErrorObject"
      }
      schemaKeyNames[key] = registry.unique(base)
    }
    for (key, schema) in schemas {
      if let props = schema["properties"] as? [String: Any] {
        inlinedProperties[key] = props
        inlinedSchemas[key] = schema
      }
    }
  }

  /// Wraps an inner type expression per the spec's nullability rules:
  /// required+nullable -> Nullable<T>; optional+nullable -> Nullable<T>?;
  /// required -> T; optional -> T?.
  static func optionalWrap(_ inner: String, nullable: Bool, required: Bool) -> String {
    if nullable {
      return required ? "Nullable<\(inner)>" : "Nullable<\(inner)>?"
    }
    if required { return inner }
    return inner.hasSuffix("?") ? inner : "\(inner)?"
  }

  func emitStruct(
    name: String, fields: [ParsedSchema.Field], bucket: String, decodable: Bool = true,
    extraConformances: [String] = []
  ) -> String {
    var lines: [String] = []
    let conformance =
      decodable ? "Sendable, Codable, Equatable, Hashable" : "Sendable, Encodable, Hashable"
    let conformances = ([conformance] + extraConformances).joined(separator: ", ")
    lines.append("public struct \(name): \(conformances) {")
    var swiftNames: [(json: String, swift: String, typeExpr: String, legacyOptional: Bool)] = []
    for field in fields {
      let swiftName = Naming.camel(field.jsonName)
      let innerType = swiftType(
        for: field.schema,
        fallbackName: name + Naming.pascal(field.jsonName),
        bucket: bucket
      )
      let isNullable = field.schema["nullable"] as? Bool == true
      // Spec-required fields Stripe no longer sends on every shape
      // decode as plain optionals instead of throwing keyNotFound.
      let legacyOptional =
        field.required && Self.legacyRequiredOptional.contains("\(name).\(field.jsonName)")
      let typeExpr = TypeEmitter.optionalWrap(
        innerType, nullable: isNullable,
        required: field.required && !legacyOptional)
      swiftNames.append((field.jsonName, swiftName, typeExpr, legacyOptional))
      lines.append("    public var \(swiftName): \(typeExpr)")
    }
    if decodable {
      lines.append("    /// Fields present in the payload that the pinned spec does not")
      lines.append("    /// describe. Kept so decoding never drops data (lossless decoding).")
      lines.append("    public var unknownFields: [String: JSONValue]?")
    }
    lines.append("")

    // Memberwise init with nil defaults for optionals.
    var params = swiftNames.map { entry -> String in
      if entry.typeExpr.hasSuffix("?") {
        return "\(entry.swift): \(entry.typeExpr) = nil"
      }
      return "\(entry.swift): \(entry.typeExpr)"
    }
    if decodable { params.append("unknownFields: [String: JSONValue]? = nil") }
    lines.append("    public init(\(params.joined(separator: ", "))) {")
    for entry in swiftNames {
      lines.append("        self.\(entry.swift) = \(entry.swift)")
    }
    if decodable {
      lines.append("        self.unknownFields = unknownFields")
    }
    lines.append("    }")
    lines.append("")

    // Coding keys. An empty key set cannot carry a String raw type.
    if swiftNames.isEmpty {
      lines.append("    private enum CodingKeys: CodingKey {")
    } else {
      lines.append("    private enum CodingKeys: String, CodingKey {")
    }
    for entry in swiftNames {
      if entry.swift == entry.json {
        lines.append("        case \(entry.swift)")
      } else {
        lines.append("        case \(entry.swift) = \"\(entry.json)\"")
      }
    }
    lines.append("    }")
    lines.append("")

    if decodable {
      // Decoding with unknown-field capture. The decoded type argument
      // is always the unwrapped base type; optionality decides between
      // decode and decodeIfPresent.
      lines.append("    public init(from decoder: Decoder) throws {")
      lines.append("        let container = try decoder.container(keyedBy: CodingKeys.self)")
      for entry in swiftNames {
        let base =
          entry.typeExpr.hasSuffix("?")
          ? String(entry.typeExpr.dropLast())
          : entry.typeExpr
        if entry.typeExpr.hasSuffix("?") {
          lines.append(
            "        self.\(entry.swift) = try container.decodeIfPresent(\(base).self, forKey: .\(entry.swift))"
          )
        } else if base.hasPrefix("Nullable<"), base.hasSuffix(">") {
          // required+nullable: Stripe routinely omits these keys even
          // though the spec marks them required (legacy fields, optional
          // sub-resources). Treat absence the same as explicit null
          // instead of throwing keyNotFound at decode time.
          lines.append(
            "        self.\(entry.swift) = try container.decodeIfPresent("
              + "\(base).self, forKey: .\(entry.swift)) ?? .null"
          )
        } else if entry.legacyOptional {
          // Spec-required but Stripe omits it in practice (see
          // legacyRequiredOptional below): a plain optional decodes
          // absence honestly as nil instead of throwing keyNotFound.
          lines.append(
            "        self.\(entry.swift) = try container.decodeIfPresent(\(base).self, forKey: .\(entry.swift))"
          )
        } else {
          lines.append(
            "        self.\(entry.swift) = try container.decode(\(base).self, forKey: .\(entry.swift))"
          )
        }
      }
      lines.append("        var captured: [String: JSONValue] = [:]")
      lines.append("        for key in container.allKeys {")
      let knownCases = swiftNames.map { ".\($0.swift)" }.joined(separator: ", ")
      lines.append("            switch key {")
      if !knownCases.isEmpty {
        lines.append("            case \(knownCases): continue")
      }
      lines.append("            default: break")
      lines.append("            }")
      lines.append(
        "            captured[key.stringValue] = try? container.decode(JSONValue.self, forKey: key)"
      )
      lines.append("        }")
      lines.append("        self.unknownFields = captured.isEmpty ? nil : captured")
      lines.append("    }")
      lines.append("")
    }

    // Encoding, including preserved unknown fields when decoding too.
    lines.append("    public func encode(to encoder: Encoder) throws {")
    lines.append("        var container = encoder.container(keyedBy: CodingKeys.self)")
    for entry in swiftNames {
      lines.append(
        "        try container.encodeIfPresent(self.\(entry.swift), forKey: .\(entry.swift))")
    }
    if decodable {
      lines.append("        if let unknownFields = unknownFields {")
      lines.append("            for (key, value) in unknownFields {")
      lines.append("                if let codingKey = CodingKeys(stringValue: key) {")
      lines.append("                    try? container.encode(value, forKey: codingKey)")
      lines.append("                }")
      lines.append("            }")
      lines.append("        }")
    }
    lines.append("    }")
    lines.append("}")
    return lines.joined(separator: "\n")
  }

  // MARK: Enum emission

  func registerEnum(values: [String], fallbackName: String, bucket: String) -> String {
    // Enums with identical value sets share one type.
    let valueKey = values.sorted().joined(separator: "|")
    if let existing = enumsByValues[valueKey] {
      return existing
    }
    let name = registry.unique(fallbackName)
    guard !emittedNames.contains(name) else { return name }
    emittedNames.insert(name)
    enumsByValues[valueKey] = name

    var caseNames: [(raw: String, swift: String)] = []
    var usedCases = Set<String>()
    for raw in values.sorted() {
      var swiftCase = Naming.camel(raw)
      if swiftCase.hasPrefix("`") {
        // strip backticks for member naming decisions
      }
      let bare = swiftCase.trimmingCharacters(in: CharacterSet(charactersIn: "`"))
      var candidate = bare
      if let first = candidate.first, first.isNumber {
        candidate = "v" + candidate
      }
      var counter = 2
      while usedCases.contains(candidate) {
        candidate = bare + "\(counter)"
        counter += 1
      }
      usedCases.insert(candidate)
      swiftCase = Naming.camel(candidate)
      caseNames.append((raw, swiftCase))
    }

    var lines: [String] = []
    lines.append("/// Lossless enum: values Stripe documents plus any value the API")
    lines.append("/// adds later, kept in `undocumented` instead of dropped.")
    lines.append("public enum \(name): Sendable, Equatable, Hashable, LosslessEnum {")
    for entry in caseNames {
      lines.append("    case \(entry.swift)")
    }
    lines.append("    case undocumented(String)")
    lines.append("")
    lines.append("    public init(rawValue raw: String) {")
    lines.append("        switch raw {")
    for entry in caseNames {
      lines.append("        case \"\(entry.raw)\": self = .\(entry.swift)")
    }
    lines.append("        default: self = .undocumented(raw)")
    lines.append("        }")
    lines.append("    }")
    lines.append("")
    lines.append("    public var rawValue: String {")
    lines.append("        switch self {")
    for entry in caseNames {
      lines.append("        case .\(entry.swift): return \"\(entry.raw)\"")
    }
    lines.append("        case .undocumented(let value): return value")
    lines.append("        }")
    lines.append("    }")
    lines.append("")
    lines.append("    public init(from decoder: Decoder) throws {")
    lines.append("        let container = try decoder.singleValueContainer()")
    lines.append("        self.init(rawValue: try container.decode(String.self))")
    lines.append("    }")
    lines.append("")
    lines.append("    public func encode(to encoder: Encoder) throws {")
    lines.append("        var container = encoder.singleValueContainer()")
    lines.append("        try container.encode(rawValue)")
    lines.append("    }")
    lines.append("}")
    pending.append(
      (bucket, GeneratedType(
        bucket: bucket, name: name, code: lines.joined(separator: "\n"), dataItemType: nil)))
    return name
  }

  // MARK: Union emission

  func registerUnion(branches: [[String: Any]], fallbackName: String, bucket: String) -> String {
    let name = registry.unique(fallbackName)
    guard !emittedNames.contains(name) else { return name }
    emittedNames.insert(name)

    // Resolve variants: refs stay refs; inline objects get names.
    struct Variant {
      let swiftCase: String
      let typeName: String
      let tagField: String?
      let tagValue: String?
    }
    var variants: [Variant] = []
    var usedCases = Set<String>()
    var index = 1
    for branch in branches {
      let typeName: String
      let caseBase: String
      if let ref = branch["$ref"] as? String {
        let key = TypeEmitter.refKey(ref)
        typeName = nameForSchemaKey(key)
        caseBase = Naming.camel(typeName)
      } else {
        typeName = swiftType(for: branch, fallbackName: name + "Variant\(index)", bucket: bucket)
        caseBase = Naming.camel(typeName)
      }
      index += 1
      var candidate = caseBase
      var counter = 2
      while usedCases.contains(candidate) {
        candidate = caseBase + "\(counter)"
        counter += 1
      }
      usedCases.insert(candidate)

      // Tag: a property of the variant whose enum has exactly one
      // value, named "object" or "type" — Stripe's discriminator.
      var tagField: String?
      var tagValue: String?
      let variantProps: [String: Any]
      if let ref = branch["$ref"] as? String {
        variantProps = inlinedProperties[TypeEmitter.refKey(ref)] ?? [:]
      } else {
        variantProps = (branch["properties"] as? [String: Any]) ?? [:]
      }
      for candidateTag in ["object", "type"] {
        if let tagSchema = variantProps[candidateTag] as? [String: Any],
          let values = tagSchema["enum"] as? [Any], values.count == 1,
          let value = values[0] as? String {
          tagField = candidateTag
          tagValue = value
          break
        }
      }
      variants.append(
        Variant(swiftCase: candidate, typeName: typeName, tagField: tagField, tagValue: tagValue))
    }

    var lines: [String] = []
    lines.append("/// Polymorphic union; unknown shapes are kept in `other` (lossless).")
    lines.append("public enum \(name): Sendable, Codable, Equatable, Hashable {")
    for variant in variants {
      let prefix = variant.typeName == name ? "indirect case " : "case "
      lines.append("    \(prefix)\(variant.swiftCase)(\(variant.typeName))")
    }
    lines.append("    case other(JSONValue)")
    lines.append("")
    lines.append("    public init(from decoder: Decoder) throws {")
    lines.append("        let container = try decoder.singleValueContainer()")
    if variants.contains(where: { $0.tagField != nil }) {
      lines.append("        if let raw = try? container.decode([String: JSONValue].self),")
      lines.append(
        "           let tag = raw[\"object\"]?.stringValue ?? raw[\"type\"]?.stringValue {")
      for variant in variants {
        guard let tagValue = variant.tagValue else { continue }
        // Tag branches must not throw: variants can share a tag (full vs
        // deleted customer both tagged "customer"), and the full object is
        // listed first, so a hard try makes the deleted branch unreachable
        // and turns any missing required key into a fatal decode error.
        // A try? guard keeps decoding order (full wins on complete data,
        // deleted wins when the payload only fits the deleted shape) and
        // falls through to the tolerant chain otherwise.
        lines.append(
          "            if tag == \"" + tagValue + "\", let v = try? container.decode("
            + "\(variant.typeName).self) { self = .\(variant.swiftCase)(v); return }"
        )
      }
      lines.append("        }")
    }
    for variant in variants {
      lines.append(
        "        if let value = try? container.decode(\(variant.typeName).self) "
        + "{ self = .\(variant.swiftCase)(value); return }"
      )
    }
    lines.append("        self = .other(try container.decode(JSONValue.self))")
    lines.append("    }")
    lines.append("")
    lines.append("    public func encode(to encoder: Encoder) throws {")
    lines.append("        var container = encoder.singleValueContainer()")
    lines.append("        switch self {")
    for variant in variants {
      lines.append("        case .\(variant.swiftCase)(let value): try container.encode(value)")
    }
    lines.append("        case .other(let value): try container.encode(value)")
    lines.append("        }")
    lines.append("    }")
    lines.append("}")
    pending.append(
      (bucket, GeneratedType(
        bucket: bucket, name: name, code: lines.joined(separator: "\n"), dataItemType: nil)))
    return name
  }
}
