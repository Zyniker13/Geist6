/// Currency display rules for the home dashboard.
///
/// Stripe represents most amounts in the currency's smallest unit (cents,
/// sen, etc.), so a displayed value is `amount / 100`. A small set of
/// currencies is the exception: their API amount is already the currency
/// unit itself, so dividing would be wrong.
///
/// Per the Stripe currencies page, 16 currencies are zero-decimal. Two of
/// them — UGX and ISK — are special cases that the API still represents
/// two-decimal for backward compatibility (an amount of `500` means 5 UGX),
/// so they divide by 100 like everything else. HUF and TWD are also charged
/// as two-decimal amounts. The result is a 15-currency "no-divide" set.
public enum Currency {
    /// Currencies whose API amount is already the currency unit.
    /// Displayed without dividing by 100.
    public static let noDivide: Set<String> = [
        "BIF", "CLP", "DJF", "GNF", "JPY", "KMF", "KRW", "MGA", "PYG",
        "RWF", "VND", "VUV", "XAF", "XOF", "XPF"
    ]

    /// Whether a currency's API amount is already the major unit
    /// (no divide by 100). Stripe returns lowercase codes ("jpy"), so the
    /// lookup is case-insensitive.
    public static func isZeroDecimal(_ code: String) -> Bool {
        noDivide.contains(code.uppercased())
    }

    /// Whether a currency's API amount must be divided by 100 to get the
    /// major unit.
    public static func dividesBy100(_ code: String) -> Bool {
        !isZeroDecimal(code)
    }
}
