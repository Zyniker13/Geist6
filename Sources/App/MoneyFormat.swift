import Foundation
import GeistMetrics

/// Shared money formatting for the UI layer. `Money` carries the API's
/// minor-unit amount; this turns it into a localized currency string,
/// honoring zero-decimal currencies through `Money.majorUnits`.
enum MoneyFormat {
  static func string(_ value: Money) -> String {
    value.majorUnits.formatted(.currency(code: value.currency.uppercased()))
  }
}
