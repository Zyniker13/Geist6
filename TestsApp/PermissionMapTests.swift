import Foundation
import Testing
@testable import Geist6

struct PermissionMapTests {

  @Test func dashboardMapHasEntries() {
    let map = PermissionMap.dashboard
    #expect(!map.entries.isEmpty)
  }

  @Test func managementMapHasEntries() {
    let map = PermissionMap.management
    #expect(!map.entries.isEmpty)
  }

  @Test func managementIncludesDashboardEntries() {
    let dashboardCount = PermissionMap.dashboard.entries.count
    let managementCount = PermissionMap.management.entries.count
    #expect(managementCount >= dashboardCount)
  }

  @Test func dashboardPermissionsAreReadOnly() {
    let entries = PermissionMap.dashboard.entries
    for entry in entries {
      #expect(entry.isWrite == false)
    }
  }

  @Test func managementHasWriteEntries() {
    let entries = PermissionMap.management.entries
    let writeEntries = entries.filter { $0.isWrite }
    #expect(!writeEntries.isEmpty)
    for entry in writeEntries {
      #expect(entry.permission == "restricted")
    }
  }

  @Test func permissionLookupWorks() {
    let map = PermissionMap.dashboard
    #expect(map.permission(for: "Charges") == "charge_read")
    #expect(map.permission(for: "NonExistent") == nil)
  }

  @Test func isReadOnlyAndIsWritableWork() {
    let map = PermissionMap.dashboard
    #expect(map.isReadOnly(resource: "Charges") == true)
    #expect(map.isWritable(resource: "Charges") == false)
  }

  @Test func entriesInCategoryReturnsCorrectSubset() {
    let map = PermissionMap.dashboard
    let paymentEntries = map.entries(in: .payments)
    for entry in paymentEntries {
      #expect(entry.category == .payments)
    }
    #expect(!paymentEntries.isEmpty)
  }

  @Test func categoriesListIsSorted() {
    let map = PermissionMap.dashboard
    let categories = map.categories
    for i in 1..<categories.count {
      #expect(categories[i-1].rawValue <= categories[i].rawValue)
    }
  }

  @Test func descriptionFormat() {
    let map = PermissionMap.dashboard
    let desc = map.description()
    #expect(desc.contains("read"))
  }

  @Test func specificResourcePermissions() {
    let map = PermissionMap.dashboard

    // Refunds should be in billing category
    let billingEntries = map.entries(in: .billing)
    for entry in billingEntries {
      #expect(entry.category == .billing)
    }

    // Connect resources
    let connectEntries = map.entries(in: .connect)
    for entry in connectEntries {
      #expect(entry.category == .connect)
    }
  }

  @Test func entriesAreDeduplicated() {
    let map = PermissionMap.dashboard
    let resources = map.entries.map { "\($0.resource).\($0.isWrite)" }
    let unique = Set(resources)
    #expect(resources.count == unique.count)
  }
}
