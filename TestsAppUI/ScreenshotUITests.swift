import XCTest

/// TEMPORARY (local-only, not committed): drives the app to the three
/// main screens and saves PNG screenshots for visual review.
@MainActor
final class ScreenshotUITests: XCTestCase {

  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  private func save(_ app: XCUIApplication, to path: String) {
    let data = app.screenshot().image.pngData()
    XCTAssertNotNil(data, "screenshot data missing")
    try? data?.write(to: URL(fileURLWithPath: path))
  }

  func testCaptureScreens() throws {
    let app = XCUIApplication()
    app.launchArguments += ["--uitest-reset", "--api-base-url=http://127.0.0.1:12111"]
    app.launch()

    // 1. Empty shell (accounts screen).
    let emptyState = app.staticTexts["No accounts"]
    XCTAssertTrue(emptyState.waitForExistence(timeout: 15), "empty state missing")
    save(app, to: "/tmp/geist6-shot-shell.png")

    // 2. Home dashboard for a fresh account.
    let addButton = app.buttons["accounts.add"]
    XCTAssertTrue(addButton.waitForExistence(timeout: 10), "add button missing")
    addButton.tap()

    let nameField = app.textFields["setup.name"]
    XCTAssertTrue(nameField.waitForExistence(timeout: 10), "setup sheet missing")
    nameField.tap()
    nameField.typeText("Shot Store")

    let keyField = app.textFields["setup.apiKey"]
    keyField.tap()
    keyField.typeText("sk_test_geist6screenshot")

    app.buttons["setup.add"].tap()

    let row = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier == %@", "sidebar.account.Shot Store")
    ).firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 15), "sidebar row missing")
    row.tap()

    let header = app.staticTexts.matching(
      NSPredicate(format: "label == %@", "Shot Store")
    ).firstMatch
    XCTAssertTrue(header.waitForExistence(timeout: 20), "home header missing")
    // Give the dashboard a moment to render its figures.
    Thread.sleep(forTimeInterval: 2)
    save(app, to: "/tmp/geist6-shot-home.png")

    // 3. Payments tab: intent list, charge detail with timeline, refunds.
    //    Runs before the search step: typing in the search field hides the
    //    home toolbar, so the payments entry point must be tapped first.
    let paymentsButton = app.buttons["home.payments"]
    XCTAssertTrue(paymentsButton.waitForExistence(timeout: 10), "payments button missing")
    paymentsButton.tap()

    let intentRow = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "payments.row.")
    ).firstMatch
    XCTAssertTrue(intentRow.waitForExistence(timeout: 20), "payments row missing")
    Thread.sleep(forTimeInterval: 1)
    save(app, to: "/tmp/geist6-shot-payments-intents.png")

    // Segmented pickers expose their segments as buttons by label; the
    // accessibility identifier on the picker tracks the current segment.
    let chargesSegment = app.buttons["Charges"]
    XCTAssertTrue(chargesSegment.waitForExistence(timeout: 10), "charges segment missing")
    chargesSegment.tap()
    Thread.sleep(forTimeInterval: 1)
    save(app, to: "/tmp/geist6-shot-payments-charges.png")

    let chargeRow = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "payments.row.ch_")
    ).firstMatch
    XCTAssertTrue(chargeRow.waitForExistence(timeout: 10), "charge row missing")
    chargeRow.tap()

    let chargeAmount = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier == %@", "payments.charge.amount")
    ).firstMatch
    XCTAssertTrue(chargeAmount.waitForExistence(timeout: 20), "charge detail missing")
    Thread.sleep(forTimeInterval: 2)
    save(app, to: "/tmp/geist6-shot-charge-detail.png")

    // 5. Refunds segment list. The back chevron is matched by label: the
    //    detail bar also hosts the actions Menu, so a bare firstMatch can
    //    open the menu instead of popping (iPad, decision 0018 nav).
    let back = app.navigationBars.buttons.matching(
      NSPredicate(format: "label == %@ OR identifier == %@", "Payments", "Back")
    ).firstMatch
    XCTAssertTrue(back.waitForExistence(timeout: 10), "back button missing")
    back.tap()
    let refundsSegment = app.buttons["Refunds"]
    XCTAssertTrue(refundsSegment.waitForExistence(timeout: 10), "refunds segment missing")
    refundsSegment.tap()
    Thread.sleep(forTimeInterval: 1)
    save(app, to: "/tmp/geist6-shot-payments-refunds.png")

    // Back home before the search step (matched by label, as above).
    let backHome = app.navigationBars.buttons.matching(
      NSPredicate(format: "label == %@ OR identifier == %@", "Shot Store", "Back")
    ).firstMatch
    XCTAssertTrue(backHome.waitForExistence(timeout: 10), "back-to-home button missing")
    backHome.tap()
    XCTAssertTrue(app.buttons["home.payments"].waitForExistence(timeout: 10), "home missing after payments")

    // 4. Customers tab: list and one customer detail. Runs before the
    //    search step (the focused search field hides the home toolbar).
    let customersButton = app.buttons["home.customers"]
    XCTAssertTrue(customersButton.waitForExistence(timeout: 10), "customers button missing")
    customersButton.tap()

    let customerRow = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "customers.row.")
    ).firstMatch
    XCTAssertTrue(customerRow.waitForExistence(timeout: 20), "customers row missing")
    Thread.sleep(forTimeInterval: 1)
    save(app, to: "/tmp/geist6-shot-customers.png")

    customerRow.tap()

    let detailName = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier == %@", "customers.detail.name")
    ).firstMatch
    XCTAssertTrue(detailName.waitForExistence(timeout: 20), "customer detail missing")
    Thread.sleep(forTimeInterval: 2)
    save(app, to: "/tmp/geist6-shot-customer-detail.png")

    // 5. Search results for the fixture charge amount.
    let field = app.searchFields.firstMatch
    XCTAssertTrue(field.waitForExistence(timeout: 10), "search field missing")
    field.tap()
    field.typeText("100\n")

    let hit = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "search.hit.")
    ).firstMatch
    XCTAssertTrue(hit.waitForExistence(timeout: 20), "search hit missing")
    Thread.sleep(forTimeInterval: 1)
    save(app, to: "/tmp/geist6-shot-search.png")
}
}
