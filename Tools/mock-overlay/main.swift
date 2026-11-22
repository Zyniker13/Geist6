// Tools/mock-overlay — main.swift
// Builds the stripe-mock overlay: a spec file that is stripe-mock's own
// pinned OpenAPI definition with the fields our pinned Stripe spec requires
// but stripe-mock's older bundled definition lacks, plus stripe-mock's
// pinned fixtures file.
//
// Why: stripe-mock 0.206.0's bundled spec is older than our pinned Stripe
// spec (2026-10-28.endive, decision 0004). Its `product` schema lacks the
// `type` field our spec requires, so its response synthesis drops `type`
// and generated models cannot decode the response (decision 0027). The
// overlay adds the missing schema properties to the mock's spec so the
// mock serves responses the pinned models can decode.
//
// The upstream files are fetched once per cache directory from stripe-mock's
// GitHub tag v0.206.0 (the version check.sh pins), verified against recorded
// SHA-256 digests, and never committed to the repository (decision 0029:
// generated at test time from pinned upstream files, not vendored).
//
// Usage:
//   swift run mock-overlay <cache-dir>
//     Ensures <cache-dir>/spec3.json and <cache-dir>/fixtures3.json exist
//     with the pinned digests (fetching them if missing), writes
//     <cache-dir>/overlay-spec3.json, and prints the two paths to pass to
//     `stripe-mock -spec ... -fixtures ...` (spec first, fixtures second).

import Foundation
import StripeSpec

// The stripe-mock release the repository pins. check.sh and CI install
// this exact version; the overlay is built from its upstream files.
private let mockRelease = "v0.206.0"

/// SHA-256 of the raw upstream files at that tag. If a fetch does not
/// match, the tool fails rather than building an overlay from unknown
/// input.
private let pinnedFiles: [(name: String, sha256: String)] = [
    (
        "spec3.json",
        "7cff4cc46d0654101a36a3302f7544640f5f73e4f3cad6f264f0e23c19fa1776"
    ),
    (
        "fixtures3.json",
        "e6822f7ee6fd71bdde6228537368aafcfb7191109340fe119d9aca27c6e9396d"
    ),
]

private let rawBase =
    "https://raw.githubusercontent.com/stripe/stripe-mock/\(mockRelease)/embedded/openapi/"

// MARK: - Digests

private func sha256Hex(_ data: Data) -> String {
    // CryptoKit is not linked into the tools; a small SHA-256 in Swift is
    // overkill, so shell out to `shasum`, present on macOS and in the
    // Ubuntu image CI uses (coreutils provides sha256sum there — try both).
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("mock-overlay-digest-\(UUID().uuidString)")
    do {
        try data.write(to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }
        for tool in [["shasum", "-a", "256"], ["sha256sum"]] {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            proc.arguments = tool + [tmp.path]
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = Pipe()
            do {
                try proc.run()
                let out = pipe.fileHandleForReading.readDataToEndOfFile()
                proc.waitUntilExit()
                guard proc.terminationStatus == 0 else { continue }
                let text = String(decoding: out, as: UTF8.self)
                if let hex = text.split(separator: " ").first {
                    return String(hex).lowercased()
                }
            } catch {
                continue
            }
        }
    } catch {
        // fall through
    }
    fatalError("no SHA-256 tool available (need shasum or sha256sum)")
}

// MARK: - Fetch / verify

private func verifyOrFetch(cacheDir: URL) {
    try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    for file in pinnedFiles {
        let destination = cacheDir.appendingPathComponent(file.name)
        var data: Data
        if let existing = try? Data(contentsOf: destination),
           sha256Hex(existing) == file.sha256 {
            data = existing
        } else {
            // Wrong digest or missing: refetch. A stale cache from a bumped
            // pin self-heals here.
            guard let url = URL(string: rawBase + file.name) else {
                fatalError("bad URL for \(file.name)")
            }
            print("mock-overlay: fetching \(url) …")
            let fetched: Data
            do {
                fetched = try Data(contentsOf: url)
            } catch {
                fatalError(
                    "mock-overlay: could not fetch \(url): \(error). " +
                    "The overlay needs network access on first use per cache dir.")
            }
            let digest = sha256Hex(fetched)
            guard digest == file.sha256 else {
                fatalError(
                    "mock-overlay: \(file.name) digest mismatch: got \(digest), " +
                    "want \(file.sha256). The upstream file changed; update the " +
                    "pin deliberately (decision 0029).")
            }
            try! fetched.write(to: destination)
            data = fetched
        }
        _ = data
    }
}

// MARK: - Overlay

/// Schema properties our pinned spec requires that the mock's spec lacks,
/// copied from the pinned spec verbatim. Today: product.type (decision
/// 0027). Extend this list only when a decode failure against the mock
/// proves another gap, and record it.
private func overlayProperties() -> [String: [String: Any]] {
    guard
        let product = try? StripeSpec.loadRaw(),
        let components = product["components"] as? [String: Any],
        let schemas = components["schemas"] as? [String: Any],
        let productSchema = schemas["product"] as? [String: Any],
        let productProps = productSchema["properties"] as? [String: Any],
        let type = productProps["type"] as? [String: Any]
    else {
        fatalError("mock-overlay: pinned spec has no product.type")
    }
    return ["product": ["type": type]]
}

private func buildOverlay(cacheDir: URL) -> URL {
    let specURL = cacheDir.appendingPathComponent("spec3.json")
    let overlayURL = cacheDir.appendingPathComponent("overlay-spec3.json")
    guard var raw = try? Data(contentsOf: specURL),
        var spec = try? JSONSerialization.jsonObject(with: raw) as? [String: Any],
        let components = spec["components"] as? [String: Any],
        var schemas = components["schemas"] as? [String: Any]
    else {
        fatalError("mock-overlay: cannot read the mock spec at \(specURL)")
    }
    for (schemaName, props) in overlayProperties() {
        guard var schema = schemas[schemaName] as? [String: Any] else {
            fatalError("mock-overlay: mock spec has no schema \(schemaName)")
        }
        var properties = schema["properties"] as? [String: Any] ?? [:]
        for (key, value) in props {
            properties[key] = value
        }
        schema["properties"] = properties
        schemas[schemaName] = schema
    }
    spec["components"] = components.merging(["schemas": schemas]) { _, new in new }
    let data = try! JSONSerialization.data(withJSONObject: spec)
    try! data.write(to: overlayURL)
    return overlayURL
}

// MARK: - Main

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    FileHandle.standardError.write(Data(
        "usage: swift run mock-overlay <cache-dir>\n".utf8))
    exit(2)
}
let cacheDir = URL(fileURLWithPath: arguments[1], isDirectory: true)
verifyOrFetch(cacheDir: cacheDir)
let overlayURL = buildOverlay(cacheDir: cacheDir)
// Print the two arguments for stripe-mock, one per line: spec, fixtures.
print(overlayURL.path)
print(cacheDir.appendingPathComponent("fixtures3.json").path)
