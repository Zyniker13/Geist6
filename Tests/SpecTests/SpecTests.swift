import Foundation
import Testing
@testable import StripeSpec

@Test func pinnedVersionIsStable() throws {
    #expect(StripeSpec.pinnedAPIVersion == "2026-10-28.endive")
    #expect(StripeSpec.pinnedSourceRelease == "v2600")
}

@Test func inventoryExtractionMatchesSpec() throws {
    let inventory = try StripeSpec.loadInventory()
    #expect(inventory.apiVersion == StripeSpec.pinnedAPIVersion)
    // The pinned spec's inventory is the source of truth for the coverage
    // matrix; it must stay non-empty and hold the documented totals.
    #expect(inventory.resources.count == 162)
    #expect(inventory.operations.count == 687)
}
