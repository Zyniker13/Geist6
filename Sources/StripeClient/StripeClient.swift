import Foundation
import StripeModels
import StripeSpec

/// Typed errors thrown by the client and the API.
public enum StripeClientError: Swift.Error, CustomStringConvertible, Sendable, Equatable {
  /// Dashboard mode refuses every request that would change anything.
  case dashboardModeReadOnly(method: String, path: String)
  case invalidKey(String)
  case missingResponse
  case decodingFailed(underlying: Swift.Error, path: String)
  case transport(underlying: Swift.Error)

  public static func == (lhs: StripeClientError, rhs: StripeClientError) -> Bool {
    switch (lhs, rhs) {
    case (.dashboardModeReadOnly(let m1, let p1), .dashboardModeReadOnly(let m2, let p2)):
      return m1 == m2 && p1 == p2
    case (.invalidKey(let a), .invalidKey(let b)):
      return a == b
    case (.missingResponse, .missingResponse):
      return true
    case (.decodingFailed(let a1, let p1), .decodingFailed(let a2, let p2)):
      return p1 == p2 && "\(a1)" == "\(a2)"
    case (.transport(let a), .transport(let b)):
      return "\(a)" == "\(b)"
    @unknown default:
      return false
    }
  }

  public var description: String {
    switch self {
    case .dashboardModeReadOnly(let method, let path):
      return "Dashboard mode is read-only: refused \(method) \(path) before it reached the network"
    case .invalidKey(let detail):
      return "invalid API key: \(detail)"
    case .missingResponse:
      return "the response carried no body where one was required"
    case .decodingFailed(let underlying, let path):
      return "could not decode the response for \(path): \(underlying)"
    case .transport(let underlying):
      return "network transport failed: \(underlying)"
    }
  }
}

/// An error Stripe returned, typed from the documented error object.
public struct StripeAPIError: Swift.Error, Sendable, CustomStringConvertible {
  public enum ErrorType: String, Sendable {
    case apiError = "api_error"
    case cardError = "card_error"
    case idempotencyError = "idempotency_error"
    case invalidRequestError = "invalid_request_error"
    case undocumented
  }

  public struct Detail: Sendable, Decodable {
    public var type: String?
    public var code: String?
    public var message: String?
    public var docUrl: String?
    public var param: String?
    public var declineCode: String?
    public var charge: String?
    public var paymentIntentId: String?
    public var paymentMethodType: String?
    public var requestId: String?
    public var adviceCode: String?

    enum CodingKeys: String, CodingKey {
      case type, code, message
      case docUrl = "doc_url"
      case param
      case declineCode = "decline_code"
      case charge
      case paymentIntentId = "payment_intent"
      case paymentMethodType = "payment_method_type"
      case requestId = "request_id"
      case adviceCode = "advice_code"
    }

    /// All-unknown detail, used when the body is not a parseable error.
    init() {
      type = nil
      code = nil
      message = nil
      docUrl = nil
      param = nil
      declineCode = nil
      charge = nil
      paymentIntentId = nil
      paymentMethodType = nil
      requestId = nil
      adviceCode = nil
    }

    /// The API's `payment_intent` field may be a full object or an ID
    /// string; keep the ID when it is one.
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      type = try container.decodeIfPresent(String.self, forKey: .type)
      code = try container.decodeIfPresent(String.self, forKey: .code)
      message = try container.decodeIfPresent(String.self, forKey: .message)
      docUrl = try container.decodeIfPresent(String.self, forKey: .docUrl)
      param = try container.decodeIfPresent(String.self, forKey: .param)
      declineCode = try container.decodeIfPresent(String.self, forKey: .declineCode)
      charge = try container.decodeIfPresent(String.self, forKey: .charge)
      paymentMethodType = try container.decodeIfPresent(String.self, forKey: .paymentMethodType)
      requestId = try container.decodeIfPresent(String.self, forKey: .requestId)
      adviceCode = try container.decodeIfPresent(String.self, forKey: .adviceCode)
      if let string = try? container.decode(String.self, forKey: .paymentIntentId) {
        paymentIntentId = string
      }
    }
  }

  public var status: Int
  public var httpStatus: Int { status }
  public var type: ErrorType
  public var detail: Detail
  /// Convenience: the error message from the API.
  public var message: String? { detail.message }
  /// Convenience: the error code from the API.
  public var code: String? { detail.code }
  /// The raw body, kept so nothing the app does not model is lost.
  public var rawBody: Data?
  public var requestId: String?
  /// True for `429` rate limits and lock timeouts, which Stripe documents
  /// as safe to retry.
  public var isRetryable: Bool {
    status == 429
  }

  public var description: String {
    var parts = ["HTTP \(status)", type.rawValue]
    if let message = detail.message {
      parts.append(message)
    }
    if let code = detail.code {
      parts.append("code=\(code)")
    }
    if let requestId = requestId {
      parts.append("request=\(requestId)")
    }
    return parts.joined(separator: " · ")
  }
}

/// A parameter type for endpoints that take no parameters; lets the opaque
/// `some Encodable` in `request`/`perform` stay inferable from a nil.
public struct EmptyParams: Encodable, Sendable {}

/// The HTTP client for Stripe's API. Every request carries the pinned
/// `Stripe-Version`; every write carries an idempotency key; and in
/// Dashboard mode the client refuses every non-GET request before any
/// network traffic happens.
public struct StripeClient: Sendable {

  public enum Mode: String, Sendable {
    /// Read-only: the client refuses non-GET requests.
    case dashboard
    /// Reads and writes the key permits.
    case management
  }

  public let apiKey: String
  public let mode: Mode
  public var apiVersion: String
  /// The connected account to act on, sent as the `Stripe-Account` header.
  public var stripeAccount: String?
  public var baseURL: URL
  public var filesBaseURL: URL
  public var session: URLSession
  /// Retries for errors Stripe documents as safe to retry (`429`, lock
  /// timeouts, and transport failures).
  public var maxRetryAttempts: Int

  public init(
    apiKey: String,
    mode: Mode,
    apiVersion: String = StripeSpec.pinnedAPIVersion,
    stripeAccount: String? = nil,
    baseURL: URL = URL(string: "https://api.stripe.com")!,
    filesBaseURL: URL = URL(string: "https://files.stripe.com")!,
    session: URLSession = StripeClient.defaultSession,
    maxRetryAttempts: Int = 2
  ) {
    self.apiKey = apiKey
    self.mode = mode
    self.apiVersion = apiVersion
    self.stripeAccount = stripeAccount
    self.baseURL = baseURL
    self.filesBaseURL = filesBaseURL
    self.session = session
    self.maxRetryAttempts = maxRetryAttempts
  }

  /// Convenience: create a client from a `URLSessionConfiguration` (for tests).
  public init(
    apiKey: String,
    mode: Mode,
    apiVersion: String = StripeSpec.pinnedAPIVersion,
    stripeAccount: String? = nil,
    baseURL: URL = URL(string: "https://api.stripe.com")!,
    filesBaseURL: URL = URL(string: "https://files.stripe.com")!,
    configuration: URLSessionConfiguration,
    maxRetryAttempts: Int = 2
  ) {
    let session = URLSession(configuration: configuration)
    self.init(
      apiKey: apiKey,
      mode: mode,
      apiVersion: apiVersion,
      stripeAccount: stripeAccount,
      baseURL: baseURL,
      filesBaseURL: filesBaseURL,
      session: session,
      maxRetryAttempts: maxRetryAttempts)
  }

  public static let defaultSession: URLSession = {
    let configuration = URLSessionConfiguration.default
    configuration.waitsForConnectivity = false
    configuration.timeoutIntervalForRequest = 60
    configuration.timeoutIntervalForResource = 120
    return URLSession(configuration: configuration)
  }()

  public static let defaultApiVersion = StripeSpec.pinnedAPIVersion

  // MARK: Request plumbing

  public struct RequestOutcome: Sendable {
    public var status: Int
    public var requestId: String?
    public var body: Data
  }

  /// Performs a request and decodes the response.
  ///
  /// `params` is encoded as a form body for `/v1` writes and query items
  /// for `/v1` GETs, and as JSON for `/v2`. Generated service methods call
  /// this; hand-written code can too.
  public func request<Response: Decodable>(
    method: String,
    path: String,
    params: (some Encodable)? = nil,
    expand: [String]? = nil,
    idempotencyKey: String? = nil,
    include: [String]? = nil
  ) async throws -> Response {
    let outcome = try await perform(
      method: method,
      path: path,
      params: params,
      expand: expand,
      idempotencyKey: idempotencyKey,
      include: include
    )
    do {
      return try StripeClient.decoder.decode(Response.self, from: outcome.body)
    } catch {
      throw StripeClientError.decodingFailed(underlying: error, path: path)
    }
  }

  /// Same as `request` for endpoints that take no parameters. Swift cannot
  /// infer the opaque `some Encodable` from a lone `nil`, so generated
  /// methods without params call this overload.
  public func request<Response: Decodable>(
    method: String,
    path: String,
    expand: [String]? = nil,
    idempotencyKey: String? = nil,
    include: [String]? = nil
  ) async throws -> Response {
    try await self.request(
      method: method,
      path: path,
      params: nil as EmptyParams?,
      expand: expand,
      idempotencyKey: idempotencyKey,
      include: include
    )
  }

  /// Performs a request and returns the raw outcome (used by the explorer
  /// and by tests).
  @Sendable public func perform(
    method: String,
    path: String,
    params: (some Encodable)? = nil,
    expand: [String]? = nil,
    idempotencyKey: String? = nil,
    include: [String]? = nil
  ) async throws -> RequestOutcome {
    // Dashboard mode refuses writes before anything touches the network.
    if mode == .dashboard && method.uppercased() != "GET" {
      throw StripeClientError.dashboardModeReadOnly(method: method.uppercased(), path: path)
    }

    let namespace: Namespace = path.hasPrefix("/v2") ? .v2 : .v1
    let host: URL =
      (path.hasPrefix("/v1/files") && method.uppercased() == "POST")
      ? filesBaseURL
      : baseURL

    var components = URLComponents(
      url: host.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
    var queryItems: [URLQueryItem] = []
    var bodyData: Data?
    var contentType: String?

    var pairs: [(String, String)] = []
    if let params = params {
      pairs.append(contentsOf: try FormFlattener.pairs(from: params))
    }
    if let expand = expand, !expand.isEmpty {
      for (index, field) in expand.enumerated() {
        pairs.append(("expand[\(index)]", field))
      }
    }
    if let include = include, !include.isEmpty {
      for (index, field) in include.enumerated() {
        pairs.append(("include[\(index)]", field))
      }
    }

    if method.uppercased() == "GET" || namespace == .v1 && method.uppercased() == "GET" {
      queryItems = pairs.map { URLQueryItem(name: $0.0, value: $0.1) }
    } else if namespace == .v1 {
      let joined = FormFlattener.urlEncoded(pairs)
      bodyData = Data(joined.utf8)
      contentType = "application/x-www-form-urlencoded"
    } else {
      // `/v2` speaks JSON on both sides.
      let json = try JSONEncoder().encode(JSONBody(from: params, expand: nil, include: nil))
      bodyData = json
      contentType = "application/json"
    }

    if !queryItems.isEmpty {
      components.queryItems = queryItems
    }

    var request = URLRequest(url: components.url!)
    request.httpMethod = method.uppercased()
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue(apiVersion, forHTTPHeaderField: "Stripe-Version")
    if let stripeAccount = stripeAccount {
      request.setValue(stripeAccount, forHTTPHeaderField: "Stripe-Account")
    }
    if method.uppercased() != "GET" {
      // Stripe accepts idempotency keys on /v1 POST and /v2 POST and
      // DELETE; the key makes retries safe.
      let key = idempotencyKey ?? UUID().uuidString
      request.setValue(key, forHTTPHeaderField: "Idempotency-Key")
    }
    if let contentType = contentType {
      request.setValue(contentType, forHTTPHeaderField: "Content-Type")
    }
    request.httpBody = bodyData

    return try await execute(request: request, path: path)
  }

  /// Performs a request with an explicit namespace override (for tests).
  @Sendable public func perform(
    method: String,
    path: String,
    params: (some Encodable)? = nil,
    namespace: Namespace,
    expand: [String]? = nil,
    idempotencyKey: String? = nil,
    include: [String]? = nil
  ) async throws -> RequestOutcome {
    // Dashboard mode refuses writes before anything touches the network.
    if mode == .dashboard && method.uppercased() != "GET" {
      throw StripeClientError.dashboardModeReadOnly(method: method.uppercased(), path: path)
    }

    let host: URL =
      (path.hasPrefix("/v1/files") && method.uppercased() == "POST")
      ? filesBaseURL
      : baseURL

    var components = URLComponents(
      url: host.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
    var queryItems: [URLQueryItem] = []
    var bodyData: Data?
    var contentType: String?

    var pairs: [(String, String)] = []
    if let params = params {
      pairs.append(contentsOf: try FormFlattener.pairs(from: params))
    }
    if let expand = expand, !expand.isEmpty {
      for (index, field) in expand.enumerated() {
        pairs.append(("expand[\(index)]", field))
      }
    }
    if let include = include, !include.isEmpty {
      for (index, field) in include.enumerated() {
        pairs.append(("include[\(index)]", field))
      }
    }

    if method.uppercased() == "GET" || namespace == .v1 && method.uppercased() == "GET" {
      queryItems = pairs.map { URLQueryItem(name: $0.0, value: $0.1) }
    } else if namespace == .v1 {
      let joined = FormFlattener.urlEncoded(pairs)
      bodyData = Data(joined.utf8)
      contentType = "application/x-www-form-urlencoded"
    } else {
      let json = try JSONEncoder().encode(JSONBody(from: params, expand: nil, include: nil))
      bodyData = json
      contentType = "application/json"
    }

    if !queryItems.isEmpty {
      components.queryItems = queryItems
    }

    var request = URLRequest(url: components.url!)
    request.httpMethod = method.uppercased()
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue(apiVersion, forHTTPHeaderField: "Stripe-Version")
    if let stripeAccount = stripeAccount {
      request.setValue(stripeAccount, forHTTPHeaderField: "Stripe-Account")
    }
    if method.uppercased() != "GET" {
      let key = idempotencyKey ?? UUID().uuidString
      request.setValue(key, forHTTPHeaderField: "Idempotency-Key")
    }
    if let contentType = contentType {
      request.setValue(contentType, forHTTPHeaderField: "Content-Type")
    }
    request.httpBody = bodyData

    return try await execute(request: request, path: path)
  }

  public enum Namespace: String, Sendable {
    case v1
    case v2
  }

  /// Wraps optional params for `/v2` JSON bodies.
  struct JSONBody: Encodable {
    let wrapped: [String: JSONValue]

    init(from params: (some Encodable)?, expand: [String]?, include: [String]?) throws {
      var wrapped: [String: JSONValue] = [:]
      if let params = params {
        let data = try JSONEncoder().encode(params)
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        if let dict = json as? [String: Any] {
          for (key, value) in dict {
            wrapped[key] = JSONValue(json: value)
          }
        }
      }
      self.wrapped = wrapped
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.singleValueContainer()
      try container.encode(wrapped)
    }
  }

  static let decoder: JSONDecoder = JSONDecoder()

  private func execute(request: URLRequest, path: String) async throws -> RequestOutcome {
    var attempt = 0
    var lastError: Error = StripeClientError.missingResponse
    while attempt <= maxRetryAttempts {
      if attempt > 0 {
        let backoff = StripeClient.backoffInterval(attempt: attempt)
        try await Task.sleep(nanoseconds: UInt64(backoff * 1_000_000_000))
      }
      do {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
          throw StripeClientError.transport(underlying: URLError(.badServerResponse))
        }
        let requestId = StripeClient.requestId(from: http)
        if (200..<300).contains(http.statusCode) {
          return RequestOutcome(status: http.statusCode, requestId: requestId, body: data)
        }
        let apiError = StripeClient.parseError(
          status: http.statusCode, body: data, requestId: requestId)
        if apiError.isRetryable, attempt < maxRetryAttempts {
          attempt += 1
          lastError = apiError
          continue
        }
        throw apiError
      } catch let error as StripeAPIError {
        throw error
      } catch {
        // Transport-level failures are safe to retry because every
        // write carries an idempotency key.
        if attempt < maxRetryAttempts {
          attempt += 1
          lastError = error
          continue
        }
        throw StripeClientError.transport(underlying: error)
      }
    }
    if let apiError = lastError as? StripeAPIError {
      throw apiError
    }
    throw StripeClientError.transport(underlying: lastError)
  }

  static func backoffInterval(attempt: Int) -> TimeInterval {
    // Exponential backoff with jitter, bounded at a few seconds.
    let base = min(0.5 * pow(2.0, Double(attempt - 1)), 4.0)
    let jitter = Double.random(in: 0...0.25)
    return base + jitter
  }

  /// Percent-encodes one path segment (an object ID) so interpolation into
  /// a request path is always safe.
  public static func encodePathSegment(_ segment: String) -> String {
    var allowed = CharacterSet.alphanumerics
    allowed.insert(charactersIn: "-._~")
    return segment.addingPercentEncoding(withAllowedCharacters: allowed) ?? segment
  }

  static func requestId(from response: HTTPURLResponse) -> String? {
    let headers = response.allHeaderFields
    for (key, value) in headers {
      let keyStr = key as? String ?? String(describing: key)
      if keyStr.caseInsensitiveCompare("Request-Id") == .orderedSame {
        return value as? String
      }
    }
    return nil
  }

  static func parseError(status: Int, body: Data, requestId: String?) -> StripeAPIError {
    var detail = StripeAPIError.Detail()
    if let envelope = try? decoder.decode(ErrorEnvelope.self, from: body) {
      detail = envelope.error
    }
    let type = detail.type.flatMap(StripeAPIError.ErrorType.init(rawValue:)) ?? .undocumented
    return StripeAPIError(
      status: status, type: type, detail: detail, rawBody: body,
      requestId: requestId ?? detail.requestId)
  }

  struct ErrorEnvelope: Decodable {
    var error: StripeAPIError.Detail
  }
}

/// A paginated list response from Stripe's /v1 list endpoints.
public struct ListResponse<T: Decodable & Sendable>: Decodable, Sendable {
  public var data: [T]
  public var hasMore: Bool
  public var url: String
}

extension ListResponse: StripeList where T: StripeIdentified {}

/// A paginated search response from Stripe's /v1 search endpoints.
public struct SearchResponse<T: Decodable & Sendable>: Decodable, Sendable {
  public var data: [T]
  public var hasMore: Bool
  public var url: String
}

/// A response from a Stripe delete endpoint.
public struct DeletionResponse: Decodable, Sendable {
  public var id: String
  public var deleted: Bool
}
