import XCTest

/// M6 slice-3 UI tests for the billing tab's invoice flows against
/// stripe-mock on 127.0.0.1:12111. The mock's invoice list has one draft
/// fixture, so rows are matched by the `billing.row.invoice.in_` prefix
/// rather than a hardcoded ID. stripe-mock echoes a fixture back on every
/// verb, so these assert flow completion (menu → confirm/sheet → success
/// alert); state transitions are covered by service-level tests.
///
/// The API key is a hand-written, obviously fake placeholder that never
/// leaves the test target.
@MainActor
final class InvoiceWriteUITests: XCTestCase {

  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  // MARK: - Helpers (same pattern as PaymentWriteUITests)

  @discardableResult
  private func launchFresh() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments += ["--uitest-reset"]
    app.launchArguments += ["--api-base-url=http://127.0.0.1:12111"]
    app.launch()
    return app
  }

  private func sidebarRow(_ app: XCUIApplication, named name: String) -> XCUIElement {
    let row = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier == %@", "sidebar.account.\(name)")
    ).firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 10), "sidebar row for \(name) not found")
    return row
  }

  private func openSetup(_ app: XCUIApplication) {
    let addButton = app.buttons["accounts.add"]
    XCTAssertTrue(addButton.waitForExistence(timeout: 10), "add button missing")
    addButton.tap()
    let nameField = app.textFields["setup.name"]
    XCTAssertTrue(nameField.waitForExistence(timeout: 10), "setup sheet missing")
  }

  private func addAccountAndWait(_ app: XCUIApplication, name: String) {
    openSetup(app)
    let nameField = app.textFields["setup.name"]
    nameField.tap()
    nameField.typeText(name)
    let keyField = app.textFields["setup.apiKey"]
    keyField.tap()
    keyField.typeText("sk_test_abc123def456")
    app.buttons["setup.add"].tap()
    sidebarRow(app, named: name).tap()
  }

  private func manageAccounts(_ app: XCUIApplication) -> XCUIElement {
    let row = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier == %@", "sidebar.manageAccounts")
    ).firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 10), "manage accounts row missing")
    return row
  }

  private func accountRow(_ app: XCUIApplication, named name: String) -> XCUIElement {
    let rows = app.buttons.matching(NSPredicate(format: "identifier == 'account.row'"))
    let match = rows.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
    XCTAssertTrue(match.waitForExistence(timeout: 10), "row for \(name) not found")
    return match
  }

  /// Flips the dashboard lock on for `name` through the edit screen.
  private func enableDashboardLock(_ app: XCUIApplication, name: String) {
    manageAccounts(app).tap()
    accountRow(app, named: name).tap()
    let editButton = app.buttons["detail.edit"]
    XCTAssertTrue(editButton.waitForExistence(timeout: 10), "edit button missing")
    editButton.tap()

    let lockToggle = app.switches["edit.lock"]
    XCTAssertTrue(lockToggle.waitForExistence(timeout: 10), "lock toggle missing")
    let before = lockToggle.value as? String
    lockToggle.tap()
    sleep(1)
    var after = lockToggle.value as? String
    if after == before {
      lockToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
      sleep(1)
      after = lockToggle.value as? String
    }
    XCTAssertNotEqual(after, before, "tapping the lock toggle must change its value")
    app.buttons["edit.save"].tap()
    app.buttons["detail.done"].tap()
    sidebarRow(app, named: name).tap()
  }

  /// Waits until `element` is actually tappable — existence alone is not
  /// enough mid-animation, and a tap on an un-hittable element silently
  /// no-ops.
  private func waitHittable(_ app: XCUIApplication, _ element: XCUIElement,
                            _ name: String, timeout: TimeInterval = 10) {
    let exp = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "hittable == true"), object: element)
    let result = XCTWaiter.wait(for: [exp], timeout: timeout)
    XCTAssertTrue(result == .completed, "\(name) never became hittable")
  }

  /// Opens the Billing screen for the just-added account and waits for the
  /// invoice fixture row to appear.
  private func openBilling(_ app: XCUIApplication) {
    let billingButton = app.buttons["home.billing"]
    XCTAssertTrue(billingButton.waitForExistence(timeout: 10), "billing button missing")
    billingButton.tap()
    let invoiceRow = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "billing.row.invoice.in_")
    ).firstMatch
    XCTAssertTrue(invoiceRow.waitForExistence(timeout: 20), "invoice row missing")
  }

  /// Pushes the invoice fixture's detail screen from the Billing list.
  private func openInvoiceDetail(_ app: XCUIApplication) {
    let row = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "billing.row.invoice.in_")
    ).firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 10), "invoice row missing")
    waitHittable(app, row, "invoice row")
    // Tap near the row's bottom edge: a center tap can land on an
    // overlapping element and silently no-op.
    row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)).tap()

    let nav = app.navigationBars["Invoice"]
    XCTAssertTrue(nav.waitForExistence(timeout: 10), "invoice detail missing")
  }

  /// Opens the detail screen's Actions menu and taps `item`.
  private func openActionsMenu(_ app: XCUIApplication, item identifier: String) {
    let menu = app.buttons["billing.invoice.actions"]
    XCTAssertTrue(menu.waitForExistence(timeout: 10), "actions menu missing")
    waitHittable(app, menu, "actions menu")
    menu.tap()
    let entry = app.buttons[identifier]
    XCTAssertTrue(entry.waitForExistence(timeout: 10), "menu item \(identifier) missing")
    entry.tap()
  }

  private func dismissAlert(_ app: XCUIApplication) {
    let ok = app.buttons["OK"]
    XCTAssertTrue(ok.waitForExistence(timeout: 10), "alert OK button missing")
    ok.tap()
  }

  // MARK: - Detail screen

  /// The draft fixture's detail screen exposes the Actions menu once loaded
  /// and the account allows writes.
  func testInvoiceDetailShowsActionsMenu() {
    let app = launchFresh()
    addAccountAndWait(app, name: "Invoice Store")
    openBilling(app)
    openInvoiceDetail(app)

    XCTAssertTrue(app.buttons["billing.invoice.actions"].exists, "actions menu missing")
  }

  // MARK: - Finalize flow

  /// Finalizes the draft fixture: menu → confirmation dialog → run →
  /// success alert. stripe-mock accepts the finalize verb.
  func testFinalizeInvoiceFlowCompletesAgainstMock() {
    let app = launchFresh()
    addAccountAndWait(app, name: "Finalize Store")
    openBilling(app)
    openInvoiceDetail(app)
    openActionsMenu(app, item: "billing.invoice.finalize")

    let run = app.buttons["billing.invoice.finalizeRun"].firstMatch
    XCTAssertTrue(run.waitForExistence(timeout: 10), "finalize confirmation missing")
    waitHittable(app, run, "finalize run")
    run.tap()

    let success = app.staticTexts["Invoice finalized"]
    XCTAssertTrue(success.waitForExistence(timeout: 15), "finalize success alert missing")
    dismissAlert(app)
  }

  // MARK: - Add line item flow

  /// Adds a line item to the draft fixture: menu → sheet → description +
  /// amount → submit → success alert. stripe-mock echoes the invoice back.
  func testAddLineItemFlowCompletesAgainstMock() {
    let app = launchFresh()
    addAccountAndWait(app, name: "Line Store")
    openBilling(app)
    openInvoiceDetail(app)
    openActionsMenu(app, item: "billing.invoice.addLine")

    let description = app.textFields["billing.invoice.line.add.description"]
    XCTAssertTrue(description.waitForExistence(timeout: 10), "add-line sheet missing")
    description.tap()
    description.typeText("Consulting")

    let amount = app.textFields["billing.invoice.line.add.amount"]
    XCTAssertTrue(amount.waitForExistence(timeout: 10), "amount field missing")
    amount.tap()
    amount.typeText("1500")

    let submit = app.buttons["billing.invoice.line.add.submit"]
    XCTAssertTrue(submit.waitForExistence(timeout: 10), "add submit missing")
    submit.tap()

    let success = app.staticTexts["Line item added"]
    XCTAssertTrue(success.waitForExistence(timeout: 15), "add-line success alert missing")
    dismissAlert(app)
  }

  // MARK: - Edit draft flow

  /// Edits the draft fixture's details: menu → sheet → description →
  /// submit → success alert. stripe-mock echoes the invoice back.
  func testEditDraftInvoiceFlowCompletesAgainstMock() {
    let app = launchFresh()
    addAccountAndWait(app, name: "Edit Store")
    openBilling(app)
    openInvoiceDetail(app)
    openActionsMenu(app, item: "billing.invoice.edit")

    let description = app.textFields["billing.invoice.edit.description"]
    XCTAssertTrue(description.waitForExistence(timeout: 10), "edit sheet missing")
    description.tap()
    description.typeText("Website redesign")

    let submit = app.buttons["billing.invoice.edit.submit"]
    XCTAssertTrue(submit.waitForExistence(timeout: 10), "edit submit missing")
    submit.tap()

    let success = app.staticTexts["Invoice updated"]
    XCTAssertTrue(success.waitForExistence(timeout: 15), "edit success alert missing")
    dismissAlert(app)
  }

  // MARK: - Dashboard-mode safety

  /// A dashboard-locked account shows the invoice detail but none of its
  /// write controls: the Actions menu never appears.
  func testDashboardLockedAccountHasNoInvoiceWriteControls() {
    let app = launchFresh()
    addAccountAndWait(app, name: "Locked Store")
    enableDashboardLock(app, name: "Locked Store")
    openBilling(app)
    openInvoiceDetail(app)

    let actions = app.buttons["billing.invoice.actions"]
    XCTAssertFalse(
      actions.exists,
      "dashboard-locked account must not expose the invoice actions menu")
  }
}
