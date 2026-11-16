import Foundation
import StripeSpec

// Tools/inventory — builds docs/stripe/api-inventory.md and
// docs/stripe/coverage-matrix.md from the pinned Stripe OpenAPI definition,
// and checks the committed copies against a fresh regeneration.
//
// Usage:
//   swift run inventory gen [docs/stripe]   regenerate both documents
//   swift run inventory check [docs/stripe] fail if regenerated output differs
//
// The tier, milestone, screen, and permission assignments below are the
// reviewed M0 plan; edit them here and regenerate, never hand-edit the
// generated markdown.

let helpText = """
    usage: inventory gen [outdir] | inventory check [outdir]
    outdir defaults to docs/stripe
    """

func fail(_ message: String) -> Never {
    FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
    exit(1)
}

// MARK: - Coverage plan (tier, milestone, screen) per resource

/// The coverage assignment for one resource: which milestone covers it, at
/// which tier of support, and where it appears in the app.
struct Coverage {
    let tier: Int
    let milestone: String
    let screen: String
    let note: String

    static func tier2(_ milestone: String = "M10", note: String = "") -> Coverage {
        Coverage(tier: 2, milestone: milestone, screen: "Generated list, detail, and edit views", note: note)
    }

    static func tier3(_ milestone: String = "M10", note: String = "") -> Coverage {
        Coverage(tier: 3, milestone: milestone, screen: "API Explorer", note: note)
    }
}

/// Tier 1: hand-built screens for the everyday work.
let tier1Screen: [String: String] = [
    "PaymentIntent": "Payments screens (M4)",
    "Charge": "Payments screens (M4)",
    "Refund": "Payments screens (M4)",
    "PaymentMethod": "Payments screens (M4); customer payment methods (M5)",
    "CheckoutSession": "Payments screens (M4)",
    "PaymentLink": "Payments screens (M4)",
    "SetupIntent": "Payments screens (M4)",
    "Customer": "Customers screens (M5); home metrics (M3)",
    "Subscription": "Billing screens (M6)",
    "Invoice": "Billing screens (M6)",
    "Product": "Catalog screens (M6)",
    "Price": "Catalog screens (M6)",
    "Balance": "Home dashboard (M3)",
    "BalanceTransaction": "Balances screens (M7)",
    "Payout": "Payouts screens (M7)",
    "Dispute": "Disputes screens (M9)",
    "Account": "Account screens (M8); setup and account details (M2)",
    "Event": "Activity feed (M3; full filters M11)",
]

let tier1: Set<String> = Set(tier1Screen.keys)

/// Milestones for resources covered before M10, keyed by class name; rows
/// listing a specific operation override per operation.
let earlyMilestones: [String: String] = [
    // M2 setup and account store.
    "Account": "M2",
    // M3 home dashboard and search.
    "Balance": "M3",
    "BalanceTransaction": "M3",
    "Event": "M3",
    "CashBalance": "M7",
    // M4 payments.
    "PaymentIntent": "M4",
    "Charge": "M4",
    "Refund": "M4",
    "PaymentMethod": "M4",
    "CheckoutSession": "M4",
    "PaymentLink": "M4",
    "SetupIntent": "M4",
    // M5 customers.
    "Customer": "M5",
    "TaxId": "M5",
    "CustomerBalanceTransaction": "M5",
    "CustomerCashBalanceTransaction": "M5",
    // M6 billing.
    "Product": "M6",
    "Price": "M6",
    "Subscription": "M6",
    "SubscriptionItem": "M6",
    "SubscriptionSchedule": "M6",
    "Invoice": "M6",
    "InvoiceItem": "M6",
    "InvoiceLineItem": "M6",
    "InvoiceRenderingTemplate": "M6",
    "InvoicePayment": "M6",
    "CreditNote": "M6",
    "CreditNoteLineItem": "M6",
    "Coupon": "M6",
    "PromotionCode": "M6",
    "Quote": "M6",
    "Meter": "M6",
    "MeterEvent": "M6",
    "MeterEventAdjustment": "M6",
    "MeterEventSummary": "M6",
    "TaxRate": "M6",
    "TaxCode": "M6",
    "Configuration": "M6",
    "Session": "M6",
    "Alert": "M6",
    "CreditGrant": "M6",
    "CreditBalanceSummary": "M6",
    "CreditBalanceTransaction": "M6",
    "FeedbackOption": "M6",
    "TestClock": "M6",
    // M7 balances, payouts, reporting.
    "Payout": "M7",
    "Transfer": "M7",
    "TransferReversal": "M7",
    "Topup": "M7",
    "BalanceSettings": "M7",
    "ReportRun": "M7",
    "ReportType": "M7",
    "ExchangeRate": "M7",
    "CountrySpec": "M7",
    // M8 Connect.
    "AccountLink": "M8",
    "AccountSession": "M8",
    "LoginLink": "M8",
    "ApplicationFee": "M8",
    "FeeRefund": "M8",
    "Capability": "M8",
    "Person": "M8",
    // M9 disputes and fraud.
    "Review": "M9",
    "EarlyFraudWarning": "M9",
    "ValueList": "M9",
    "ValueListItem": "M9",
    "PaymentEvaluation": "M9",
]

/// Per-operation milestone overrides, keyed "ClassName.methodName".
let opMilestoneOverrides: [String: String] = [
    // Setup calls GET /v1/account in M2; the other Account screens come with
    // Connect in M8.
    "Account.retrieve": "M2",
]

/// Tier 3: endpoints too unusual for tier 2; reachable through the API
/// Explorer with mode and permission gating.
let tier3Classes: Set<String> = [
    // Stripe Apps management.
    "Install", "Secret",
    // v2 namespaces stay Explorer until they stabilize.
    "MeterEventSession",
    "ProductCatalogImport",
    "GbBankAccount", "UsBankAccount",
    "Adjustment", "FinancialAddress", "FinancialAddressCreditSimulation",
    "InboundTransfer", "OutboundPayment", "OutboundSetupIntent",
    "PayoutIntent", "PayoutMethod", "PayoutMethodsBankAccountSpec",
    "ReceivedCredit", "RecipientVerification",
    // Legacy or internal.
    "Source", "Token", "EphemeralKey", "SetupAttempt", "ThreeDSecure",
]

// MARK: - Restricted-key permissions (from Stripe's permissions reference)

/// Documented object permissions from Stripe's permissions reference
/// (docs.stripe.com/stripe-apps/reference/permissions). Dashboard restricted
/// keys expose the same read/write split per resource; for resources not in
/// that reference the Dashboard key picker is the source of truth.
let documentedPermissions: [String: (read: String, write: String)] = [
    "MeterEvent": ("billing_meter_event_read", "billing_meter_event_write"),
    "Meter": ("billing_meter_read", "billing_meter_write"),
    "Coupon": ("coupon_read", "coupon_write"),
    "CreditNote": ("credit_note_read", "credit_note_write"),
    "Configuration": ("customer_portal_read", "customer_portal_write"),
    "ActiveEntitlement": ("entitlement_read", "entitlement_read"),
    "Feature": ("entitlement_read", "entitlement_read"),
    "Invoice": ("invoice_read", "invoice_write"),
    "Price": ("plan_read", "plan_write"),
    "PromotionCode": ("promotion_code_read", "promotion_code_write"),
    "Quote": ("quote_read", "quote_write"),
    "Subscription": ("subscription_read", "subscription_write"),
    "TaxRate": ("tax_rate_read", "tax_rate_write"),
    "TestClock": ("billing_clock_read", "billing_clock_write"),
    "CheckoutSession": ("checkout_session_read", "checkout_session_write"),
    "ProductCatalogImport": ("product_catalog_import_read", "product_catalog_import_write"),
    "AccountLink": ("account_link_write", "account_link_write"),
    "ApplicationFee": ("application_fee_read", "application_fee_write"),
    "LoginLink": ("edit_link_write", "edit_link_write"),
    "Topup": ("top_up_read", "top_up_write"),
    "Transfer": ("transfer_read", "transfer_write"),
    "TransferReversal": ("transfer_read", "transfer_write"),
    "Account": ("connected_account_read", "connected_account_read"),
    "ApplePayDomain": ("apple_pay_domain_read", "apple_pay_domain_write"),
    "Balance": ("balance_read", "balance_read"),
    "BalanceTransaction": ("balance_transaction_source_read", "balance_transaction_source_read"),
    "Charge": ("charge_read", "charge_write"),
    "Refund": ("charge_read", "charge_write"),
    "ConfirmationToken": ("confirmation_token_read", "confirmation_token_read"),
    "CustomerSession": ("customer_session_read", "customer_session_write"),
    "Customer": ("customer_read", "customer_write"),
    "Event": ("event_read", "event_read"),
    "File": ("file_read", "file_write"),
    "FileLink": ("file_read", "file_write"),
    "Mandate": ("mandate_read", "mandate_write"),
    "Dispute": ("dispute_read", "dispute_write"),
    "PaymentIntent": ("payment_intent_read", "payment_intent_write"),
    "PaymentLink": ("payment_links_read", "payment_links_write"),
    "PaymentMethodConfiguration": ("payment_method_configurations_read", "payment_method_configurations_write"),
    "PaymentMethodDomain": ("payment_method_domain_read", "payment_method_domain_write"),
    "PaymentMethod": ("payment_method_read", "payment_method_write"),
    "PaymentRecord": ("payment_records_read", "payment_records_write"),
    "PaymentAttemptRecord": ("payment_records_read", "payment_records_write"),
    "Payout": ("payout_read", "payout_write"),
    "Product": ("product_read", "product_write"),
    "SetupIntent": ("setup_intent_read", "setup_intent_write"),
    "ShippingRate": ("shipping_rate_read", "shipping_rate_write"),
    "Source": ("source_read", "source_write"),
    "Token": ("token_read", "token_write"),
    "Review": ("review_read", "review_write"),
    "ReportRun": ("report_runs_and_report_types_read", "report_runs_and_report_types_read"),
    "ReportType": ("report_runs_and_report_types_read", "report_runs_and_report_types_read"),
]

/// Resources with no documented object permission name; a Dashboard restricted
/// key grants them through the key picker instead. The app probes read access
/// and treats every write as blocked until a successful write proves it.
func permissionLabel(for className: String, isWrite: Bool) -> String {
    if let documented = documentedPermissions[className] {
        return isWrite ? documented.write : documented.read
    }
    return isWrite ? "unlisted (Dashboard key picker)" : "unlisted (Dashboard key picker)"
}

// MARK: - Coverage resolution

func coverage(for resource: SpecResource, operation: SpecOperation) -> Coverage {
    let key = "\(resource.className).\(operation.methodName)"
    let milestone = opMilestoneOverrides[key] ?? earlyMilestones[resource.className] ?? "M10"
    let tier: Int
    let screen: String
    if tier1.contains(resource.className), milestone != "M10" {
        tier = 1
        screen = tier1Screen[resource.className] ?? "Hand-built screens"
    } else if tier3Classes.contains(resource.className) {
        tier = 3
        screen = "API Explorer"
    } else {
        tier = 2
        screen = "Generated list, detail, and edit views"
    }
    var note = ""
    if resource.schema.hasPrefix("v2.") || resource.inPackage.hasPrefix("v2.") {
        note = "v2 namespace: JSON bodies, page tokens, thin events"
    }
    if resource.inPackage == "TestHelpers" {
        note = "test mode only"
    }
    return Coverage(tier: tier, milestone: milestone, screen: screen, note: note)
}

// MARK: - Markdown generation

func escapeCell(_ text: String) -> String {
    text.replacingOccurrences(of: "|", with: "\\|")
}

func generateInventoryMarkdown(_ inventory: SpecInventory) -> String {
    var lines: [String] = []
    lines.append("# Stripe API inventory")
    lines.append("")
    lines.append("""
        Generated by `Tools/inventory` from Stripe's official OpenAPI definition: \
        `stripe/openapi` release \(StripeSpec.pinnedSourceRelease), file \
        `latest/openapi.spec3.sdk.json`, API version \(inventory.apiVersion) \
        (pinned by decision 0004). Regenerate with `swift run inventory gen`; \
        `swift run inventory check` fails when these documents drift from the \
        pinned spec. This file describes Stripe's API surface in our own words; \
        the source of truth is the pinned specification itself.
        """)
    lines.append("")
    let resources = inventory.resources
    let ops = inventory.operations
    var byType: [String: Int] = [:]
    for op in ops { byType[op.methodType, default: 0] += 1 }
    let typeSummary = ["list", "retrieve", "create", "update", "delete", "custom"]
        .compactMap { key -> String? in
            byType[key].map { "\($0) \(key)" }
        }
        .joined(separator: ", ")
    lines.append("Totals: \(resources.count) resources with their own operations, \(ops.count) operations (\(typeSummary)). Resources without operations are nested value types inside other resources; they are not a separate part of the API surface.")
    lines.append("")

    for group in inventory.packages {
        let displayName = group.name
        let count = group.resources.count
        lines.append("## \(displayName) (\(count) resources)")
        lines.append("")
        lines.append("| Resource | Operation | HTTP | Path |")
        lines.append("| --- | --- | --- | --- |")
        for resource in group.resources {
            var first = true
            for op in resource.operations {
                let name = first ? resource.className : ""
                first = false
                lines.append("| \(escapeCell(name)) | \(escapeCell(op.methodName)) | \(op.http.uppercased()) | \(escapeCell(op.path)) |")
            }
        }
        lines.append("")
    }
    return lines.joined(separator: "\n") + "\n"
}

func generateCoverageMatrixMarkdown(_ inventory: SpecInventory) -> String {
    var lines: [String] = []
    lines.append("# Coverage matrix")
    lines.append("")
    lines.append("""
        One row for every operation on every resource in \
        [`api-inventory.md`](api-inventory.md) (built from the same pinned spec, \
        API version \(inventory.apiVersion)). Tiers of support are defined in \
        [ROADMAP.md](../../ROADMAP.md#tiers-of-support): tier 1 crafted screens, \
        tier 2 generated structured views, tier 3 the API Explorer. The \
        restricted-key permission column uses the names documented in Stripe's \
        permissions reference; "unlisted" resources are granted through the \
        Dashboard key picker, and the app probes access before showing a \
        feature. Regenerate with `swift run inventory gen`.
        """)
    lines.append("")
    lines.append("| Resource | Operation | HTTP | Path | Tier | Milestone | Screen or flow | Restricted-key permission |")
    lines.append("| --- | --- | --- | --- | --- | --- | --- | --- |")
    for group in inventory.packages {
        for resource in group.resources {
            var first = true
            for op in resource.operations {
                let coverage = coverage(for: resource, operation: op)
                let name = first ? resource.className : ""
                first = false
                var note = coverage.note
                if !note.isEmpty { note = " \(note)" }
                let permission = permissionLabel(for: resource.className, isWrite: op.isWrite)
                lines.append("| \(escapeCell(name)) | \(escapeCell(op.methodName)) | \(op.http.uppercased()) | \(escapeCell(op.path)) | \(coverage.tier) | \(coverage.milestone) | \(escapeCell(coverage.screen + note)) | \(escapeCell(permission)) |")
            }
        }
    }
    return lines.joined(separator: "\n") + "\n"
}

// MARK: - JSON inventory (machine-readable)

func generateInventoryJSON(_ inventory: SpecInventory) throws -> Data {
    struct Op: Codable {
        let name: String
        let type: String
        let http: String
        let path: String
        let write: Bool
    }
    struct Res: Codable {
        let className: String
        let schema: String
        let object: String
        let package: String
        let polymorphicGroups: [String]
        let operations: [Op]
    }
    struct Doc: Codable {
        let apiVersion: String
        let sourceRelease: String
        let packages: [String: [Res]]
    }
    var grouped: [String: [Res]] = [:]
    for group in inventory.packages {
        grouped[group.name] = group.resources.map { resource in
            Res(
                className: resource.className,
                schema: resource.schema,
                object: resource.stripeObject,
                package: resource.package,
                polymorphicGroups: resource.polymorphicGroups,
                operations: resource.operations.map {
                    Op(name: $0.methodName, type: $0.methodType, http: $0.http, path: $0.path, write: $0.isWrite)
                }
            )
        }
    }
    let doc = Doc(apiVersion: inventory.apiVersion, sourceRelease: StripeSpec.pinnedSourceRelease, packages: grouped)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
    return try encoder.encode(doc)
}

// MARK: - Main

let arguments = Array(CommandLine.arguments.dropFirst())
guard let firstArgument = arguments.first, firstArgument == "gen" || firstArgument == "check" else {
    print(helpText)
    exit(2)
}
let mode = firstArgument
let outDir = arguments.count > 1
    ? arguments[1]
    : "docs/stripe"

let inventory: SpecInventory
do {
    inventory = try StripeSpec.loadInventory()
} catch {
    fail("failed to load pinned spec: \(error)")
}

let markdown = generateInventoryMarkdown(inventory)
let matrix = generateCoverageMatrixMarkdown(inventory)
let json = try generateInventoryJSON(inventory)

if mode == "check" {
    let fileManager = FileManager.default
    var problems: [String] = []
    for (name, expected) in [("api-inventory.md", markdown), ("coverage-matrix.md", matrix)] {
        let path = outDir + "/" + name
        guard let existing = try? String(contentsOfFile: path, encoding: .utf8) else {
            problems.append("missing \(path)")
            continue
        }
        if existing != expected {
            problems.append("\(path) does not match the pinned spec; run `swift run inventory gen`")
        }
    }
    let jsonPath = outDir + "/api-inventory.json"
    if let existingData = fileManager.contents(atPath: jsonPath) {
        if existingData != json {
            problems.append("\(jsonPath) does not match the pinned spec; run `swift run inventory gen`")
        }
    } else {
        problems.append("missing \(jsonPath)")
    }
    if problems.isEmpty {
        print("inventory check: OK (\(inventory.resources.count) resources, \(inventory.operations.count) operations, version \(inventory.apiVersion))")
    } else {
        for problem in problems { fail("inventory check: \(problem)") }
    }
} else {
    try FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
    try markdown.write(toFile: outDir + "/api-inventory.md", atomically: true, encoding: .utf8)
    try matrix.write(toFile: outDir + "/coverage-matrix.md", atomically: true, encoding: .utf8)
    try json.write(to: URL(fileURLWithPath: outDir + "/api-inventory.json"))
    print("wrote \(outDir)/api-inventory.md, \(outDir)/coverage-matrix.md, \(outDir)/api-inventory.json (\(inventory.resources.count) resources, \(inventory.operations.count) operations, version \(inventory.apiVersion))")
}
