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
  /// Final client method name and params type name per operation identity.
  /// Assigned in one pre-pass over every operation before emission, so
  /// naming never depends on file or bucket ordering.
  private var methodNames: [String: String] = [:]
  private var paramsNames: [String: String] = [:]

  private func identity(_ op: OpRequest) -> String {
    op.resourceSchemaKey + "|" + op.methodName + "|" + op.http + "|" + op.path
  }

  /// Deterministically assigns every operation's client method name and
  /// params type name before any emission, so naming never depends on file
  /// or bucket ordering. Methods keep the plain name unless a bare call
  /// could be ambiguous: only two fully-defaulted overloads with the same
  /// argument labels conflict, and the canonical claimant (v1 before v2,
  /// fewer path segments, then the smaller path) wins it while the rest
  /// get a path-prefixed name. Params structs must be unique types, so
  /// every contested params base is resolved by the same canonical rule.
  /// Without this pass the generator silently dropped params structs on
  /// name collisions, which left those methods unable to send filters or
  /// request bodies, and a per-bucket method dedup missed cross-bucket
  /// pairs, which left ambiguous overloads for bare calls like
  /// `listProducts()`.
  func assignNames(for ops: [OpRequest]) throws {
    let sorted = ops.sorted { a, b in
      if a.resourceClassName != b.resourceClassName {
        return a.resourceClassName < b.resourceClassName
      }
      if a.methodType != b.methodType { return a.methodType < b.methodType }
      return a.path < b.path
    }
    var methodClaims: [String: [OpRequest]] = [:]
    var paramsClaims: [String: [OpRequest]] = [:]
    for op in sorted {
      methodClaims[methodName(op), default: []].append(op)
      paramsClaims[paramsBaseName(op), default: []].append(op)
    }

    // The canonical claimant: prefer v1 over v2, then fewer path segments,
    // then the lexicographically smaller path.
    func winner(_ candidates: [OpRequest]) -> OpRequest {
      candidates.min { a, b in
        if a.isV2 != b.isV2 { return !a.isV2 }
        let aSegments = a.path.split(separator: "/").count
        let bSegments = b.path.split(separator: "/").count
        if aSegments != bSegments { return aSegments < bSegments }
        return a.path < b.path
      } ?? candidates[0]
    }

    // Two same-name methods are only ambiguous when one argument list can
    // match both. Overloads with a path parameter differ in argument
    // labels, and create/update methods take a required params value, so
    // those resolve by label or type. Only same-label, fully-defaulted
    // overloads can be ambiguous — a bare call matches both — so only
    // those contest the plain name.
    func labelKey(_ op: OpRequest) -> String {
      var labels = pathParameterNames(op.path).map { Naming.camel($0) }
      if op.bodySchema != nil || !op.queryParameters.isEmpty { labels.append("_") }
      labels.append("expand")
      if op.http != "get" { labels.append("idempotencyKey") }
      return labels.joined(separator: "|")
    }

    func allDefaulted(_ op: OpRequest) -> Bool {
      if !pathParameterNames(op.path).isEmpty { return false }
      let hasParams = op.bodySchema != nil || !op.queryParameters.isEmpty
      if hasParams {
        return op.http == "get" || op.methodType == "list" || op.methodType == "search"
      }
      return true
    }

    var claimedDefaultMethods = Set<String>()
    var claimedParams = Set<String>()

    func claimDefaultMethod(_ base: String, labels: String) -> String {
      var candidate = base
      var counter = 2
      while claimedDefaultMethods.contains(candidate + "|" + labels) {
        candidate = base + String(counter)
        counter += 1
      }
      claimedDefaultMethods.insert(candidate + "|" + labels)
      return candidate
    }

    func claimParams(_ base: String) -> String {
      var candidate = base
      var counter = 2
      while claimedParams.contains(candidate) {
        candidate = base + String(counter)
        counter += 1
      }
      claimedParams.insert(candidate)
      return candidate
    }

    // Methods: ops that can never be called ambiguously (path parameters or
    // a required params value) keep the plain name. Fully-defaulted ops
    // keep it too, unless the same name and argument labels are already
    // claimed by another fully-defaulted op; then only the canonical one
    // keeps it and the rest get path-prefixed names.
    var methodLosers: [(op: OpRequest, plain: String)] = []
    for (base, candidates) in methodClaims {
      for op in candidates where !allDefaulted(op) {
        methodNames[identity(op)] = base
      }
      var byLabels: [String: [OpRequest]] = [:]
      for op in candidates where allDefaulted(op) {
        byLabels[labelKey(op), default: []].append(op)
      }
      for (labels, group) in byLabels {
        if group.count == 1 {
          methodNames[identity(group[0])] = claimDefaultMethod(base, labels: labels)
        } else {
          let canonical = winner(group)
          methodNames[identity(canonical)] = claimDefaultMethod(base, labels: labels)
          for op in group where identity(op) != identity(canonical) {
            methodLosers.append((op, base))
          }
        }
      }
    }

    // Params structs must be unique types no matter how the methods are
    // named, so every contested params base is resolved the same way.
    var paramsLosers: [(op: OpRequest, base: String)] = []
    for (base, candidates) in paramsClaims {
      if candidates.count == 1 {
        let name = claimParams(base)
        paramsNames[identity(candidates[0])] = name
        _ = emitter.registry.unique(name)
      } else {
        let canonical = winner(candidates)
        let name = claimParams(base)
        paramsNames[identity(canonical)] = name
        _ = emitter.registry.unique(name)
        for op in candidates where identity(op) != identity(canonical) {
          paramsLosers.append((op, base))
        }
      }
    }

    // Round 2: losers are renamed with a path prefix.
    for (op, plain) in methodLosers {
      let prefix = Naming.pascal(pathPrefix(op))
      var candidate = insertPrefix(prefix, into: plain, op: op)
      if claimedDefaultMethods.contains(candidate + "|" + labelKey(op)) {
        candidate = insertPrefix(Naming.pascal(fullPathPrefix(op)), into: plain, op: op)
      }
      methodNames[identity(op)] = claimDefaultMethod(candidate, labels: labelKey(op))
    }
    for (op, base) in paramsLosers {
      var candidate = Naming.pascal(pathPrefix(op)) + base
      if claimedParams.contains(candidate) {
        candidate = Naming.pascal(fullPathPrefix(op)) + base
      }
      let name = claimParams(candidate)
      paramsNames[identity(op)] = name
      _ = emitter.registry.unique(name)
    }
  }

  /// The params struct name an operation would use if it owned the plain
  /// name: resource class + camel method + Params, for example
  /// ProductListParams.
  private func paramsBaseName(_ op: OpRequest) -> String {
    op.resourceClassName + Naming.pascal(op.methodName) + "Params"
  }

  /// Inserts a path prefix right after the leading verb: listProducts
  /// with prefix Climate becomes listClimateProducts. Falls back to a
  /// plain concatenation when the name does not start with a known verb.
  private func insertPrefix(_ prefix: String, into name: String, op: OpRequest) -> String {
    let verb: String
    switch op.methodType {
    case "list": verb = "list"
    case "search": verb = "search"
    default: verb = Naming.camel(op.methodName)
    }
    guard name.hasPrefix(verb), name.count > verb.count else {
      return prefix + name
    }
    let rest = name.dropFirst(verb.count)
    // list + Climate + Products -> listClimateProducts
    return verb + prefix + rest
  }

  /// The assigned params struct name for an operation.
  private func paramsTypeName(_ op: OpRequest) throws -> String {
    guard let name = paramsNames[identity(op)] else {
      throw GenError.unassignedName(identity(op))
    }
    return name
  }

  /// The assigned client method name for an operation.
  func finalMethodName(_ op: OpRequest) throws -> String {
    guard let name = methodNames[identity(op)] else {
      throw GenError.unassignedName(identity(op))
    }
    return name
  }

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

  /// The first non-version, non-parameter path segment, PascalCased, with
  /// a V2 prefix for v2 paths. For example, /v1/checkout/sessions gives
  /// "Checkout" and /v2/core/accounts gives "V2Core".
  private func pathPrefix(_ op: OpRequest) -> String {
    let segments = op.path.split(separator: "/").map(String.init)
    let first = segments.first(where: { !Self.isVersionSegment($0) && !$0.hasPrefix("{") })
      ?? op.resourceClassName
    let p = Naming.pascal(first)
    return op.isV2 ? "V2" + p : p
  }

  /// Every non-version, non-parameter path segment, PascalCased, with a
  /// V2 prefix for v2 paths. Fallback when two operations share the first
  /// path segment.
  private func fullPathPrefix(_ op: OpRequest) -> String {
    let segments = op.path.split(separator: "/").map(String.init)
      .filter { !Self.isVersionSegment($0) && !$0.hasPrefix("{") }
    let raw = segments.joined(separator: "_")
    let p = Naming.pascal(raw.isEmpty ? op.resourceClassName : raw)
    return op.isV2 ? "V2" + p : p
  }

  private static func isVersionSegment(_ segment: String) -> Bool {
    guard segment.hasPrefix("v"), segment.count > 1 else { return false }
    return segment.dropFirst().allSatisfy(\.isNumber)
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

    let name = try paramsTypeName(op)
    // Fail loudly if the name is somehow taken: a silently missing params
    // struct would leave the method unable to send its request body.
    guard !paramsTypes.contains(where: { $0.name == name }) else {
      throw GenError.duplicateParamsType(name)
    }
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
    for op in ops {
      let name = try finalMethodName(op)

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
