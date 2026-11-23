// ReportRunDownload.swift — Sources/GeistData
// Downloads a report run's result file (M7, decision 0031). The URL comes
// from Stripe itself (`result.url` on the run's result File) and is
// short-lived; the account's secret key is sent as the bearer token only
// to that Stripe-provided URL. Reads are not gated on dashboard mode —
// downloading a report is a read — but every network hop still rides the
// account's client key, never a stored copy.

import Foundation
import StripeClient
import StripeModels

public enum ReportRunDownloadError: LocalizedError, Equatable {
  /// The run's result file carries no URL (never generated, or expired).
  case missingURL
  /// The server answered with a non-2xx status.
  case httpStatus(Int)

  public var errorDescription: String? {
    switch self {
    case .missingURL:
      return "This report run has no downloadable file yet. Run it again "
        + "or wait for Stripe to finish generating it."
    case .httpStatus(let status):
      return "The file download failed (HTTP \(status)). The URL may have "
        + "expired; re-open the run to get a fresh one."
    }
  }
}

/// Fetches one report file's bytes.
public struct ReportRunDownloader: Sendable {
  /// The URL to fetch; tests and UI tests override this per decision 0031.
  private let overrideURL: URL?
  private let session: URLSession

  public init(session: URLSession = ReportRunDownloader.defaultSession) {
    self.overrideURL = nil
    self.session = session
  }

  public init(overrideURL: URL?, session: URLSession) {
    self.overrideURL = overrideURL
    self.session = session
  }

  /// The app's launch-argument override (`-g6FileDownloadOverride <url>`),
  /// set only by UI tests.
  public static var launchArgumentOverride: URL? {
    guard
      let arg = CommandLine.arguments.first(where: { $0.hasPrefix("-g6FileDownloadOverride") })
    else { return nil }
    let value = arg.split(separator: "=", maxSplits: 1).last.map(String.init) ?? ""
    return URL(string: value)
  }

  /// A session that never caches: report files are single-use artifacts.
  public static let defaultSession: URLSession = {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
    return URLSession(configuration: configuration)
  }()

  /// Downloads the file. `urlOverride` (when non-nil) replaces the file's
  /// own URL — the UI-test seam. Returns the raw bytes.
  public func fetch(file: File, bearerToken: String, urlOverride: URL? = nil) async throws -> Data {
    let target = urlOverride ?? overrideURL ?? file.url.valueOrNil.flatMap(URL.init(string:))
    guard let target else { throw ReportRunDownloadError.missingURL }
    var request = URLRequest(url: target)
    request.httpMethod = "GET"
    // The key goes only to a URL Stripe handed out (decision 0031).
    request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse else {
      throw ReportRunDownloadError.httpStatus(-1)
    }
    guard (200..<300).contains(http.statusCode) else {
      throw ReportRunDownloadError.httpStatus(http.statusCode)
    }
    return data
  }

  /// The suggested local file name for a run's CSV export.
  public static func fileName(reportType: String, runID: String) -> String {
    let safeType = reportType
      .lowercased()
      .map { $0.isLetter || $0.isNumber ? $0 : "_" }
      .reduce(into: "") { $0.append($1) }
    return "\(safeType)_\(runID).csv"
  }
}
