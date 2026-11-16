import Foundation

/// Access to the pinned Stripe OpenAPI definition.
///
/// The pinned file is `openapi.spec3.sdk.json`, Stripe's official SDK-annotated
/// OpenAPI specification (`stripe/openapi` release v2600, API version
/// 2026-10-28.endive). Decision 0004 records why the SDK variant is pinned.
public enum StripeSpec {
    /// The API version the repository is pinned to (decision 0004).
    public static let pinnedAPIVersion = "2026-10-28.endive"

    /// The stripe/openapi release tag the pinned file came from.
    public static let pinnedSourceRelease = "v2600"

    /// Error thrown when the pinned specification is missing or malformed.
    public enum SpecError: Error, CustomStringConvertible {
        case resourceUnavailable(String)
        case unexpectedShape(String)

        public var description: String {
            switch self {
            case let .resourceUnavailable(name):
                return "pinned spec resource unavailable: \(name)"
            case let .unexpectedShape(detail):
                return "pinned spec has unexpected shape: \(detail)"
            }
        }
    }

    /// Loads the pinned specification as a raw JSON dictionary.
    /// `JSONSerialization` is used instead of `Codable` because the file is
    /// ~9 MB and only a small part of it is read by the tools.
    public static func loadRaw() throws -> [String: Any] {
        guard let url = Bundle.module.url(
            forResource: "openapi.spec3.sdk", withExtension: "json"
        ) else {
            throw SpecError.resourceUnavailable("openapi.spec3.sdk.json")
        }
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dict = json as? [String: Any] else {
            throw SpecError.unexpectedShape("top level is not an object")
        }
        return dict
    }
}

// MARK: - Inventory model

/// One API operation (method) on a Stripe resource, as annotated by the spec.
public struct SpecOperation: Equatable {
    /// Stripe SDK method name, for example "capture" or "list".
    public let methodName: String
    /// Spec method type: list, retrieve, create, update, delete, or custom.
    public let methodType: String
    /// HTTP verb: get, post, or delete.
    public let http: String
    /// Full path, for example "/v1/charges/{charge}/capture".
    public let path: String

    /// True when the request would change data in Stripe (post or delete).
    /// Every write must carry an idempotency key and is forbidden in
    /// Dashboard mode.
    public var isWrite: Bool { http != "get" }

    public init(methodName: String, methodType: String, http: String, path: String) {
        self.methodName = methodName
        self.methodType = methodType
        self.http = http
        self.path = path
    }
}

/// A resource that carries its own operations in the spec. Resources without
/// operations are nested value types; they appear inside other resources and
/// are not a separate part of the API surface.
public struct SpecResource: Equatable {
    /// Schema key in the spec, for example "charge".
    public let schema: String
    /// Generated class name from `x-stripeResource.class_name`.
    public let className: String
    /// Stripe wire object name, for example "charge".
    public let stripeObject: String
    /// Service group from `x-stripeResource.in_package`; empty string means
    /// the core package.
    public let inPackage: String
    /// Polymorphic groups the resource belongs to, from `x-stripeResource`.
    public let polymorphicGroups: [String]
    /// The resource's operations, in spec order.
    public let operations: [SpecOperation]

    /// Readable product-area name: "Core" instead of an empty string.
    public var package: String { inPackage.isEmpty ? "Core" : inPackage }
}

/// The complete inventory of the pinned spec: API version plus resources
/// grouped by package.
public struct SpecInventory: Equatable {
    public let apiVersion: String
    public let packages: [PackageGroup]

    public struct PackageGroup: Equatable {
        public let name: String
        public let resources: [SpecResource]
    }

    public var resources: [SpecResource] { packages.flatMap(\.resources) }
    public var operations: [SpecOperation] { resources.flatMap(\.operations) }
}

// MARK: - Inventory extraction

extension StripeSpec {
    /// Extracts the inventory from a loaded spec dictionary. Reads only the
    /// documented vendor annotations (`x-stripeResource`,
    /// `x-stripeOperations`) so a spec update cannot silently change what the
    /// tool sees.
    public static func inventory(from spec: [String: Any]) throws -> SpecInventory {
        guard let info = spec["info"] as? [String: Any],
              let version = info["version"] as? String else {
            throw SpecError.unexpectedShape("info.version missing")
        }
        guard let components = spec["components"] as? [String: Any],
              let schemas = components["schemas"] as? [String: Any] else {
            throw SpecError.unexpectedShape("components.schemas missing")
        }

        var byPackage: [String: [(className: String, resource: SpecResource)]] = [:]
        for (key, raw) in schemas {
            guard let schema = raw as? [String: Any],
                  let resourceAnno = schema["x-stripeResource"] as? [String: Any],
                  let operationsAnno = schema["x-stripeOperations"] as? [[String: Any]],
                  !operationsAnno.isEmpty else {
                continue
            }
            let className = resourceAnno["class_name"] as? String ?? key
            let inPackage = resourceAnno["in_package"] as? String ?? ""
            let groups = (resourceAnno["polymorphic_groups"] as? [Any])?
                .compactMap { $0 as? String } ?? []
            let operations = try operationsAnno.map { op -> SpecOperation in
                guard let methodName = op["method_name"] as? String,
                      let methodType = op["method_type"] as? String,
                      let http = op["operation"] as? String,
                      let path = op["path"] as? String else {
                    throw SpecError.unexpectedShape("operation missing fields on \(key)")
                }
                return SpecOperation(
                    methodName: methodName, methodType: methodType,
                    http: http, path: path
                )
            }
            let resource = SpecResource(
                schema: key,
                className: className,
                stripeObject: schema["x-resourceId"] as? String ?? key,
                inPackage: inPackage,
                polymorphicGroups: groups,
                operations: operations
            )
            byPackage[inPackage, default: []].append((className, resource))
        }

        let packages = byPackage
            .map { name, entries -> (sortKey: String, group: SpecInventory.PackageGroup) in
                let sorted = entries.sorted { $0.className.localizedCaseInsensitiveCompare($1.className) == .orderedAscending }
                return (
                    name,
                    SpecInventory.PackageGroup(
                        name: name.isEmpty ? "Core" : name,
                        resources: sorted.map(\.resource)
                    )
                )
            }
            .sorted { a, b in
                // Core first, then alphabetical.
                let aName = a.sortKey.isEmpty ? "" : a.sortKey
                let bName = b.sortKey.isEmpty ? "" : b.sortKey
                if (aName.isEmpty) != (bName.isEmpty) { return aName.isEmpty }
                return aName.localizedCaseInsensitiveCompare(bName) == .orderedAscending
            }
            .map(\.group)

        return SpecInventory(apiVersion: version, packages: packages)
    }

    /// Loads the pinned spec and extracts its inventory.
    public static func loadInventory() throws -> SpecInventory {
        try inventory(from: loadRaw())
    }
}
