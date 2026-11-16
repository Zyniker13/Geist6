import Foundation
import StripeModels

/// Flattens an `Encodable` value into the key/value pairs Stripe's form
/// encoding expects: nested objects become bracket paths (`created[gt]=1`),
/// arrays are indexed (`tax_id_data[0][type]=…`), and booleans and numbers
/// become their string forms.
///
/// The value is first encoded to JSON (so every generated params struct works
/// without custom encoding code) and then walked.
public enum FormFlattener {

    /// Returns the flattened key/value pairs for a params value.
    public static func pairs(from value: some Encodable) throws -> [(String, String)] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(Int(date.timeIntervalSince1970))
        }
        let data = try encoder.encode(value)
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        var pairs: [(String, String)] = []
        flatten("", json, into: &pairs)
        return pairs.sorted { $0.0 < $1.0 }
    }

    /// URL-encodes pairs into a form body string.
    public static func urlEncoded(_ pairs: [(String, String)]) -> String {
        pairs
            .map { "\(formEscape($0.0))=\(formEscape($0.1))" }
            .joined(separator: "&")
    }

    private static func flatten(_ path: String, _ value: Any, into pairs: inout [(String, String)]) {
        if let dictionary = value as? [String: Any] {
            if dictionary.isEmpty { return }
            for key in dictionary.keys.sorted() {
                let childPath = path.isEmpty ? key : "\(path)[\(key)]"
                flatten(childPath, dictionary[key] ?? NSNull(), into: &pairs)
            }
        } else if let array = value as? [Any] {
            if array.isEmpty { return }
            for (index, element) in array.enumerated() {
                let childPath = path.isEmpty ? "[\(index)]" : "\(path)[\(index)]"
                flatten(childPath, element, into: &pairs)
            }
        } else if let null = value as? NSNull {
            _ = null
            // Stripe's form encoding has no null; omit the field.
            return
        } else if let number = value as? NSNumber {
            pairs.append((path, scalarString(for: number)))
        } else if let bool = value as? Bool {
            pairs.append((path, bool ? "true" : "false"))
        } else if let string = value as? String {
            pairs.append((path, string))
        }
    }

    private static func scalarString(for number: NSNumber) -> String {
        // JSON booleans arrive as NSNumber too; keep them as true/false.
        if CFGetTypeID(number) == CFBooleanGetTypeID() {
            return number.boolValue ? "true" : "false"
        }
        let objCType = String(cString: number.objCType)
        if objCType == "q" || objCType == "i" || objCType == "l" || objCType == "s" {
            return "\(number.intValue)"
        }
        let double = number.doubleValue
        if double.rounded() == double && abs(double) < 1e15 {
            return "\(Int(double))"
        }
        return number.stringValue
    }

    static func formEscape(_ string: String) -> String {
        let allowed = CharacterSet(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._*")
        let encoded = string.addingPercentEncoding(withAllowedCharacters: allowed) ?? string
        return encoded.replacingOccurrences(of: "%20", with: "+")
    }
}

extension JSONValue {
    /// Builds a JSONValue from a JSONSerialization object.
    init(json: Any) {
        if json is NSNull {
            self = .null
        } else if let number = json as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                self = .bool(number.boolValue)
            } else {
                let double = number.doubleValue
                if double.rounded() == double && abs(double) < 9_007_199_254_740_992 {
                    self = .int(Int(double))
                } else {
                    self = .double(double)
                }
            }
        } else if let string = json as? String {
            self = .string(string)
        } else if let array = json as? [Any] {
            self = .array(array.map { JSONValue(json: $0) })
        } else if let dictionary = json as? [String: Any] {
            var result: [String: JSONValue] = [:]
            for (key, value) in dictionary {
                result[key] = JSONValue(json: value)
            }
            self = .object(result)
        } else {
            self = .null
        }
    }
}
