// ListExportUITests.swift — TestsAppUI
// CSV export of any list (M7's last tier-1 row): the Charges segment
// exports through the toolbar action, the file lands in Documents, and the
// share sheet offers it for Save to Files. Drives the same share-sheet flow
// proven in ReportRunUITests; stripe-mock supplies the charges.

import XCTest

final class ListExportUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  private func launchFresh() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments += ["--uitest-reset"]
    app.launchArguments += ["--api-base-url=http://127.0.0.1:12111"]
    app.launch()
    return app
  }

  private func waitHittable(_ app: XCUIApplication, _ element: XCUIElement,
                            _ context: String) {
    XCTAssertTrue(element.waitForExistence(timeout: 10), "\(context) missing")
    // Coordinate tap: the element can report hittable=false while visible.
    element.tap()
  }

  private func addAccountAndWait(_ app: XCUIApplication, name: String) {
    let add = app.buttons["accounts.add"]
    XCTAssertTrue(add.waitForExistence(timeout: 10), "add button missing")
    add.tap()
    let nameField = app.textFields["setup.name"]
    XCTAssertTrue(nameField.waitForExistence(timeout: 10), "name field missing")
    nameField.tap()
    nameField.typeText(name)
    let keyField = app.textFields["setup.apiKey"]
    XCTAssertTrue(keyField.waitForExistence(timeout: 10), "key field missing")
    keyField.tap()
    // Full fake key: the setup-time GET /v1/account verification needs a
    // key the app's own format check accepts AND the mock returns 200 for.
    keyField.typeText("sk_test_uitest1234")
    app.buttons["setup.add"].tap()
    let row = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier == %@", "sidebar.account.\(name)")
    ).firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 10), "sidebar row for \(name) not found")
    row.tap()
  }

  /// The done-when: open Payments → Charges, export, and confirm the file
  /// reaches the share sheet; then save it via the Files action.
  func testExportChargesToFiles() throws {
    let app = launchFresh()
    addAccountAndWait(app, name: "Export Store")

    let paymentsButton = app.buttons["home.payments"]
    XCTAssertTrue(paymentsButton.waitForExistence(timeout: 10), "payments button missing")
    paymentsButton.tap()

    let chargesSegment = app.buttons["Charges"]
    XCTAssertTrue(chargesSegment.waitForExistence(timeout: 10), "charges segment missing")
    chargesSegment.tap()
    let chargesReady = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier == %@", "payments.segment.charges")
    ).firstMatch
    XCTAssertTrue(chargesReady.waitForExistence(timeout: 10), "segment did not switch")

    // The mock serves one charge; wait for its row, then export.
    let chargeRow = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "payments.row.ch_")
    ).firstMatch
    XCTAssertTrue(chargeRow.waitForExistence(timeout: 20), "charge row missing")

    let exportButton = app.buttons["payments.export"]
    XCTAssertTrue(exportButton.waitForExistence(timeout: 10), "export action missing")
    exportButton.tap()

    // The export sheet shows the prepared file and a Share link.
    let share = app.buttons["payments.export.share"]
    XCTAssertTrue(share.waitForExistence(timeout: 10), "share action missing")
    share.tap()

    // The share sheet's Files action: match by label across all element
    // types (the cell lives in the share-sheet extension process).
    let saveToFiles = app.descendants(matching: .any)
      .matching(NSPredicate(format: "label == %@", "Save to Files"))
      .firstMatch
    XCTAssertTrue(saveToFiles.waitForExistence(timeout: 20), "Save to Files action missing")
    saveToFiles.tap()
    let saveButton = app.descendants(matching: .any)
      .matching(NSPredicate(format: "label == %@ OR identifier == %@", "Save", "Save"))
      .matching(NSPredicate(format: "isEnabled == YES"))
      .firstMatch
    XCTAssertTrue(saveButton.waitForExistence(timeout: 20), "Save button missing")
    saveButton.tap()
  }
}
