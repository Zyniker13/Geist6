import Foundation

/// Configuration values read from launch arguments.
///
/// During UI tests the app receives `--api-base-url http://127.0.0.1:12111`
/// so the setup flow can verify keys against `stripe-mock` instead of the
/// live Stripe API.
enum AppConfig {

  /// The Stripe API base URL override, or nil (use the default).
  static var apiBaseUrl: URL? {
    guard let arg = CommandLine.arguments.first(where: { $0.hasPrefix("--api-base-url") })
    else { return nil }
    let urlStr = arg.split(separator: "=", maxSplits: 1).last.map(String.init) ?? ""
    return URL(string: urlStr)
  }
}
