import SwiftUI
import UIKit

/// Maps the stored color name of an account to a real color.
///
/// `Color("name")` looks up ASSET CATALOG colors, so a stored name like
/// ".systemBlue" would silently fail and render as a missing-color
/// placeholder. The app stores the UIKit system-color names instead and
/// resolves them explicitly here.
enum AccountColor {
  /// The names offered in the setup and edit pickers.
  static let names = [
    ".systemBlue",
    ".systemRed",
    ".systemGreen",
    ".systemOrange",
    ".systemPurple",
    ".systemTeal",
    ".systemIndigo",
    ".systemMint"
  ]
  static func color(for stored: String) -> Color {
    switch stored {
    case ".systemBlue": return Color(uiColor: .systemBlue)
    case ".systemRed": return Color(uiColor: .systemRed)
    case ".systemGreen": return Color(uiColor: .systemGreen)
    case ".systemOrange": return Color(uiColor: .systemOrange)
    case ".systemPurple": return Color(uiColor: .systemPurple)
    case ".systemTeal": return Color(uiColor: .systemTeal)
    case ".systemIndigo": return Color(uiColor: .systemIndigo)
    case ".systemMint": return Color(uiColor: .systemMint)
    default: return .gray
    }
  }
}
