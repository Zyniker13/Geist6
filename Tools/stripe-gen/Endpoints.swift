import Foundation

// Generates the request-parameter structs, list containers, and typed
// client methods for every operation in the pinned spec.

struct OpRequest {
  let resourceSchemaKey: String
  let resourceClassName: String
  let resourcePackage: String
  let methodName: String
  let methodType: String
  let http: String
  let path: String
  let operationId: String
  let bodySchema: [String: Any]?
  let bodyContentType: String?
  let queryParameters: [(name: String, schema: [String: Any])]
  let responseSchema: [String: Any]?
  let isV2: Bool
}

enum OpCollector {

  static func collect(schemas: [String: [String: Any]], paths: [String: [String: Any]]) throws
    -> [OpRequest] {
    var resources: [(key: String, schema: [String: Any])] = []
    for (key, schema) in schemas {
      guard let resource = schema["x-stripeResource"] as? [String: Any],
        let operations = schema["x-stripeOperations"] as? [[String: Any]],
        !operations.isEmpty
      else { continue }
      resources.append((key, schema))
    }
    resources.sort { a, b in
      let packageA =
        (a.schema["x-stripeResource"] as? [String: Any])?["in_package"] as? String ?? ""
      let packageB =
        (b.schema["x-stripeResource"] as? [String: Any])?["in_package"] as? String ?? ""
      if packageA != packageB {
        return packageA.localizedCaseInsensitiveCompare(packageB) == .orderedAscending
      }
      return a.key < b.key
    }

    var ops: [OpRequest] = []
    var seen = Set<String>()
    for (key, schema) in resources {
      let resource = schema["x-stripeResource"] as? [String: Any] ?? [:]
      let className = resource["class_name"] as? String ?? key
      let packageName = resource["in_package"] as? String ?? ""
      for operation in schema["x-stripeOperations"] as? [[String: Any]] ?? [] {
        guard let methodName = operation["method_name"] as? String,
          let methodType = operation["method_type"] as? String,
          let http = operation["operation"] as? String,
          let path = operation["path"] as? String,
          let pathItem = paths[path],
          let op = pathItem[http] as? [String: Any]
        else { continue }
        let dedupeKey = "\(className)|\(methodName)|\(http)|\(path)"
        guard !seen.contains(dedupeKey) else { continue }
        seen.insert(dedupeKey)

        let isV2 = path.hasPrefix("/v2")
        var bodySchema: [String: Any]?
        var bodyContentType: String?
        if let requestBody = op["requestBody"] as? [String: Any],
          let content = requestBody["content"] as? [String: [String: Any]] {
          for (contentType, media) in content {
            if let schema = media["schema"] as? [String: Any] {
              bodySchema = schema
              bodyContentType = contentType
              break
            }
          }
        }
        var queryParameters: [(String, [String: Any])] = []
        if let parameters = op["parameters"] as? [[String: Any]] {
          for parameter in parameters {
            guard let name = parameter["name"] as? String,
              let parameterSchema = parameter["schema"] as? [String: Any]
            else { continue }
            if name == "expand" || name == "include" { continue }
            queryParameters.append((name, parameterSchema))
          }
        }
        var responseSchema: [String: Any]?
        if let responses = op["responses"] as? [String: Any],
          let ok = responses["200"] as? [String: Any],
          let content = ok["content"] as? [String: [String: Any]],
          let media = content["application/json"],
          let schema = media["schema"] as? [String: Any] {
          responseSchema = schema
        }
        let operationId = op["operationId"] as? String ?? "\(http) \(path)"
        ops.append(
          OpRequest(
            resourceSchemaKey: key,
            resourceClassName: className,
            resourcePackage: packageName,
            methodName: methodName,
            methodType: methodType,
            http: http,
            path: path,
            operationId: operationId,
            bodySchema: bodySchema,
            bodyContentType: bodyContentType,
            queryParameters: queryParameters,
            responseSchema: responseSchema,
            isV2: isV2
          ))
      }
    }
    return ops
  }
}

final class EndpointEmitter {

  let emitter: TypeEmitter
  private var paramsTypes: [GeneratedType] = []
  private var listTypes: [GeneratedType] = []
  private var serviceFiles: [(bucket: String, code: String)] = []
  /// methodName overrides for awkward generated names.
  private let methodOverrides: [String: String] = [
    "FeeRefund.refund": "refundApplicationFee",
    "Account.retrieve#self": "retrieveCurrentAccount"
  ]

  init(emitter: TypeEmitter) {
    self.emitter = emitter
  }

  var params: [GeneratedType] { paramsTypes }
  var lists: [GeneratedType] { listTypes }
  var services: [(bucket: String, code: String)] { serviceFiles }

  // MARK: Naming

  private func paramsTypeName(_ op: OpRequest) -> String {
    let base = op.resourceClassName + Naming.pascal(op.methodName) + "Params"
    return emitter.registry.unique(base)
  }

  private func collectionName(_ op: OpRequest) -> String {
    // The last non-parameter path segment: /v1/charges -> Charges,
    // /v2/core/accounts -> Accounts.
    let segments = op.path.split(separator: "/").map(String.init)
    let collection = segments.last { !$0.hasPrefix("{") } ?? op.resourceClassName
    return Naming.pascal(collection)
  }

  private func methodName(_ op: OpRequest) -> String {
    if let override = methodOverrides["\(op.resourceClassName).\(op.methodName)"] {
      return override
    }
    switch op.methodType {
    case "list":
      return "list" + collectionName(op)
    case "search":
      return "search" + collectionName(op)
    case "retrieve", "create", "update", "delete":
      return op.methodName + op.resourceClassName
    default:
      return Naming.camel(op.methodName) + op.resourceClassName
    }
  }

  // MARK: List containers

  /// Returns the Swift return type for an operation response, generating
  /// the list container when the response is one.
  func responseType(for op: OpRequest) throws -> String {
    guard let responseSchema = op.responseSchema else { return "JSONValue" }
    if let ref = responseSchema["$ref"] as? String {
      return emitter.nameForSchemaKey(TypeEmitter.refKey(ref))
    }
    // Inline list containers (v1 lists, search results, v2 pages).
    let props = (responseSchema["properties"] as? [String: [String: Any]]) ?? [:]
    guard let data = props["data"], let items = data["items"] as? [String: Any] else {
      return emitter.swiftType(
        for: responseSchema, fallbackName: op.resourceClassName + "Response", bucket: bucketFor(op))
    }
    let itemType: String
    if let ref = items["$ref"] as? String {
      itemType = emitter.nameForSchemaKey(TypeEmitter.refKey(ref))
    } else {
      itemType = emitter.swiftType(
        for: items,
        fallbackName: op.resourceClassName + "ListItem",
        bucket: bucketFor(op)
      )
    }
    let isSearch = props["next_page"] != nil && props["total_count"] != nil
    let isV2Page = props["next_page_url"] != nil
    let title = responseSchema["title"] as? String
    let baseName =
      title.map { Naming.pascal($0) } ?? op.resourceClassName
      + (isSearch ? "SearchResult" : (isV2Page ? "Page" : "List"))
    var name = emitter.registry.unique(baseName)
    // Stripe titles every /search response "SearchResult" regardless of the
    // item type, and `unique` memoizes per base name, so the second and later
    // shapes would silently reuse the first struct's [Charge] data array.
    // When the name is taken by a container with a different item type, pick
    // a name that carries the item type (e.g. PaymentIntentSearchResult).
    if let existing = listTypes.first(where: { $0.name == name }),
      let existingItem = existing.dataItemType, existingItem != itemType {
      name = emitter.registry.unique(itemType + (isSearch ? "SearchResult" : "List"))
    }

    var fields: [ParsedSchema.Field] = []
    for (jsonName, schema) in props.sorted(by: { $0.key < $1.key }) {
      fields.append(ParsedSchema.Field(jsonName: jsonName, schema: schema, required: true))
    }
    let conform: String
    if isV2Page {
      conform = "V2Page"
    } else if isSearch {
      conform = "StripeSearchResult"
    } else {
      conform = "StripeList"
    }
    let code = emitter.emitStruct(
      name: name,
      fields: fields,
      bucket: bucketFor(op),
      extraConformances: [conform]
    )
    // Dedup: skip if the same list type was already generated from another op.
    let seen = listTypes.contains { $0.name == name }
    if seen {
      return name
    } else {
      // Pagination token helpers: the protocol wants plain optionals, the
      // generated field may be Nullable. Emit the witness that fits.
      var helpers: [String] = []
      func helper(forJsonName jsonName: String, as swiftPropertyName: String) -> String? {
        guard let schema = props[jsonName] else { return nil }
        let inner = emitter.swiftType(
          for: schema, fallbackName: name + Naming.pascal(jsonName), bucket: bucketFor(op))
        let expr = TypeEmitter.optionalWrap(
          inner, nullable: schema["nullable"] as? Bool == true, required: true)
        let member = Naming.camel(jsonName)
        if expr.contains("Nullable") {
          let casePattern = expr.hasSuffix("?") ? ".some(.value(let value))" : ".value(let value)"
          return """
            extension \(name) {
                public var \(swiftPropertyName): String? {
                    switch \(member) {
                    case \(casePattern): return value
                    default: return nil
                    }
                }
            }
            """
        }
        if expr.hasSuffix("?") {
          return """
            extension \(name) {
                public var \(swiftPropertyName): String? { \(member) }
            }
            """
        }
        return """
          extension \(name) {
              public var \(swiftPropertyName): String? { \(member) }
          }
          """
      }
      if conform == "StripeSearchResult" {
        if let helper = helper(forJsonName: "next_page", as: "nextPageToken") {
          helpers.append(helper)
        }
      }
      if conform == "V2Page" {
        if let helper = helper(forJsonName: "next_page_url", as: "nextPageUrlToken") {
          helpers.append(helper)
        }
        if let helper = helper(forJsonName: "previous_page_url", as: "previousPageUrlToken") {
          helpers.append(helper)
        }
      }
      let finalCode = helpers.isEmpty ? code : code + "\n\n" + helpers.joined(separator: "\n\n")
      listTypes.append(
        GeneratedType(
          bucket: bucketFor(op), name: name, code: finalCode, dataItemType: itemType))
    }
    return name
  }

  private func bucketFor(_ op: OpRequest) -> String {
    TypeEmitter.bucket(forSchemaKey: op.resourceSchemaKey)
  }

  // MARK: Params structs

  @discardableResult
  func paramsType(for op: OpRequest) throws -> String? {
    var fields: [ParsedSchema.Field] = []

    if let bodySchema = op.bodySchema {
      let bodyProps = (bodySchema["properties"] as? [String: [String: Any]]) ?? [:]
      let required = Set((bodySchema["required"] as? [Any])?.compactMap { $0 as? String } ?? [])
      for (jsonName, schema) in bodyProps.sorted(by: { $0.key < $1.key }) {
        if jsonName == "expand" || jsonName == "include" { continue }
        fields.append(
          ParsedSchema.Field(
            jsonName: jsonName, schema: schema, required: required.contains(jsonName)))
      }
    }
    for (name, schema) in op.queryParameters {
      fields.append(ParsedSchema.Field(jsonName: name, schema: schema, required: false))
    }
    guard !fields.isEmpty else { return nil }

    let name = paramsTypeName(op)
    // Dedup: skip if a params type with this name already exists.
    guard !paramsTypes.contains(where: { $0.name == name }) else { return nil }
    // List params with the standard cursor fields conform to V1ListParams
    // so the auto-pagination helper can walk them generically.
    var conformances: [String] = []
    let fieldNames = Set(fields.map(\.jsonName))
    if Set(["limit", "starting_after", "ending_before"]).isSubset(of: fieldNames) {
      conformances.append("V1ListParams")
    }
    let code = emitter.emitStruct(
      name: name,
      fields: fields,
      bucket: bucketFor(op),
      decodable: false,
      extraConformances: conformances
    )
    paramsTypes.append(GeneratedType(bucket: bucketFor(op), name: name, code: code, dataItemType: nil))
    return name
  }

  // MARK: Service methods

  func serviceExtension(for ops: [OpRequest], bucket: String) throws -> String {
    var lines: [String] = []
    lines.append("// Generated client methods for the \(bucket) resources.")
    lines.append("extension StripeClient {")
    var usedNames = Set<String>()
    for op in ops {
      var name = methodName(op)
      if usedNames.contains(name) {
        // Distinguish by path when two resources share a class name
        // and method (for example, two `list` operations).
        name = Naming.camel(name + Naming.pascal(op.path))
      }
      usedNames.insert(name)

      let paramsName: String? = try paramsType(for: op)
      let returnType = try responseType(for: op)

      var signatureArgs: [String] = []
      let pathParams = pathParameterNames(op.path)
      for pathParam in pathParams {
        signatureArgs.append("\(Naming.camel(pathParam)): String")
      }
      if let paramsName = paramsName {
        let optional = op.http == "get" || op.methodType == "list" || op.methodType == "search"
        signatureArgs.append(
          optional ? "_ params: \(paramsName)? = nil" : "_ params: \(paramsName)")
      }
      if op.http == "get" {
        signatureArgs.append("expand: [String]? = nil")
      } else {
        signatureArgs.append("expand: [String]? = nil")
        signatureArgs.append("idempotencyKey: String? = nil")
      }

      var callArgs: [String] = []
      callArgs.append("method: \"\(op.http.uppercased())\"")
      var pathExpression = "\"\(op.path)\""
      for pathParam in pathParams {
        pathExpression = pathExpression.replacingOccurrences(
          of: "{\(pathParam)}",
          with: "\\(Self.encodePathSegment(\(Naming.camel(pathParam))))"
        )
      }
      callArgs.append("path: \(pathExpression)")
      if paramsName != nil {
        callArgs.append("params: params")
      }
      if op.http == "get" {
        callArgs.append("expand: expand")
      } else {
        callArgs.append("expand: expand")
        callArgs.append("idempotencyKey: idempotencyKey")
      }

      lines.append("    /// \(op.methodType) \(op.path) (\(op.http.uppercased())).")
      lines.append(
        "    public func \(name)(\(signatureArgs.joined(separator: ", "))) async throws -> \(returnType) {"
      )
      lines.append("        try await self.request(")
      for arg in callArgs {
        lines.append("            \(arg),")
      }
      lines.append("        )")
      lines.append("    }")
      lines.append("")
    }
    lines.append("}")
    return lines.joined(separator: "\n")
  }

  private func pathParameterNames(_ path: String) -> [String] {
    var names: [String] = []
    var rest = Substring(path)
    while let open = rest.firstIndex(of: "{") {
      guard let close = rest[open...].firstIndex(of: "}") else { break }
      let name = String(rest[rest.index(after: open)..<close])
      names.append(name)
      rest = rest[rest.index(after: close)...]
    }
    return names
  }
}
