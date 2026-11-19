import XCTest

/// M4b/M4c UI tests for payment write flows and the dashboard-mode no-write
/// guarantee (decision 0017). stripe-mock on 127.0.0.1:12111 echoes fixture
/// responses for writes, so these assert flow completion (sheet → confirm →
/// success alert); state transitions are covered by service-level tests.
///
/// The API key is a hand-written, obviously fake placeholder that never
/// leaves the test target.
@MainActor
final class PaymentWriteUITests: XCTestCase {

  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  // MARK: - Helpers

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
    keyField.typeText("sk_test_uibuild0000")
    app.buttons["setup.add"].tap()
    sidebarRow(app, named: name).tap()
  }

  /// Opens the Payments screen for the just-added account and waits for the
  /// payment-intent list.
  private func openPayments(_ app: XCUIApplication) {
    let paymentsButton = app.buttons["home.payments"]
    XCTAssertTrue(paymentsButton.waitForExistence(timeout: 10), "payments button missing")
    paymentsButton.tap()
    let intentRow = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "payments.row.")
    ).firstMatch
    XCTAssertTrue(intentRow.waitForExistence(timeout: 20), "payments row missing")
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

  /// Opens the Charges segment and pushes the first charge's detail screen.
  private func openFirstChargeDetail(_ app: XCUIApplication) {
    let chargesSegment = app.buttons["Charges"]
    XCTAssertTrue(chargesSegment.waitForExistence(timeout: 10), "charges segment missing")
    waitHittable(app, chargesSegment, "charges segment")
    chargesSegment.tap()
    // The picker's identifier tracks the selection, so its change proves the
    // tap actually switched segments (an unobserved tap silently no-ops).
    let switched = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier == %@", "payments.segment.charges")
    ).firstMatch
    XCTAssertTrue(switched.waitForExistence(timeout: 10), "segment did not switch to charges")

    let chargeRow = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "payments.row.ch_")
    ).firstMatch
    XCTAssertTrue(chargeRow.waitForExistence(timeout: 10), "charge row missing")
    waitHittable(app, chargeRow, "charge row")
    // Tap near the row's bottom edge: a center tap can land on an overlapping
    // header/segment control and silently switch the list instead of pushing.
    chargeRow.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)).tap()

    let chargeAmount = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier == %@", "payments.charge.amount")
    ).firstMatch
    if chargeAmount.waitForExistence(timeout: 20) == false {
      let labels = app.staticTexts.allElementsBoundByIndex.prefix(30)
        .map { "\($0.identifier)=\($0.label)" }
      print("G6DUMP texts: \(labels.joined(separator: " | "))")
      print("G6DUMP alerts: \(app.alerts.count) sheets: \(app.sheets.count) nav: \(app.navigationBars.count)")
      let chargesProbe = app.descendants(matching: .any)
        .matching(NSPredicate(format: "identifier == %@", "payments.segment.charges")).firstMatch
      print("G6DUMP onCharges: \(chargesProbe.exists)")
      let shot = XCTAttachment(screenshot: app.screenshot())
      shot.name = "failure-screenshot"
      shot.lifetime = .keepAlways
      add(shot)
    }
    XCTAssertTrue(chargeAmount.waitForExistence(timeout: 20), "charge detail missing")
  }

  // MARK: - Write flows

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
    // detail.done pops to the account list; return to the account's home
    // screen through the (always visible) sidebar so the caller can open
    // Payments. Regression (2026-11-18): without this the flow still sat
    // on the account list and openPayments timed out.
    sidebarRow(app, named: name).tap()
  }

  // MARK: - Refund flow

  func testRefundFlowCompletesAgainstMock() {
    let app = launchFresh()
    addAccountAndWait(app, name: "Refund Store")
    openPayments(app)
    openFirstChargeDetail(app)

    let actionsMenu = app.buttons["payments.charge.actions"]
    XCTAssertTrue(actionsMenu.waitForExistence(timeout: 10), "actions menu missing")
    actionsMenu.tap()

    let refundItem = app.buttons["payments.charge.refund"]
    XCTAssertTrue(refundItem.waitForExistence(timeout: 10), "refund item missing")
    refundItem.tap()

    let submit = app.buttons["payments.refund.submit"]
    XCTAssertTrue(submit.waitForExistence(timeout: 10), "refund sheet missing")
    submit.tap()

    let confirm = app.buttons["payments.refund.confirm"].firstMatch
    XCTAssertTrue(confirm.waitForExistence(timeout: 10), "refund confirmation missing")
    confirm.tap()

    let success = app.staticTexts["Refund created"]
    XCTAssertTrue(success.waitForExistence(timeout: 15), "refund success alert missing")
    app.buttons["OK"].tap()
  }

  // MARK: - Capture flow

  func testCaptureFlowCompletesAgainstMock() {
    let app = launchFresh()
    addAccountAndWait(app, name: "Capture Store")
    openPayments(app)
    openFirstChargeDetail(app)

    let actionsMenu = app.buttons["payments.charge.actions"]
    XCTAssertTrue(actionsMenu.waitForExistence(timeout: 10), "actions menu missing")
    actionsMenu.tap()

    let captureItem = app.buttons["payments.charge.capture"]
    XCTAssertTrue(captureItem.waitForExistence(timeout: 10), "capture item missing")
    captureItem.tap()

    let submit = app.buttons["payments.capture.submit"]
    XCTAssertTrue(submit.waitForExistence(timeout: 10), "capture sheet missing")
    submit.tap()

    let confirm = app.buttons["payments.capture.confirm"].firstMatch
    XCTAssertTrue(confirm.waitForExistence(timeout: 10), "capture confirmation missing")
    confirm.tap()

    let success = app.staticTexts["Captured"]
    XCTAssertTrue(success.waitForExistence(timeout: 15), "capture success alert missing")
    app.buttons["OK"].tap()
  }

  // MARK: - Create intent flow (M4c)

  /// Creates a payment intent from the Payments toolbar: sheet → fill amount
  /// → confirm → success alert. stripe-mock echoes a fixture intent back.
  func testCreateIntentFlowCompletesAgainstMock() {
    let app = launchFresh()
    addAccountAndWait(app, name: "Create Store")
    openPayments(app)

    let newButton = app.buttons["payments.newIntent"]
    XCTAssertTrue(newButton.waitForExistence(timeout: 10), "new intent button missing")
    waitHittable(app, newButton, "new intent button")
    newButton.tap()

    let amountField = app.textFields["payments.create.amountField"]
    XCTAssertTrue(amountField.waitForExistence(timeout: 10), "create sheet missing")
    amountField.tap()
    amountField.typeText("1500")

    let submit = app.buttons["payments.create.submit"]
    XCTAssertTrue(submit.waitForExistence(timeout: 10), "create submit missing")
    submit.tap()

    let confirm = app.buttons["payments.create.confirm"].firstMatch
    XCTAssertTrue(confirm.waitForExistence(timeout: 10), "create confirmation missing")
    confirm.tap()

    let success = app.staticTexts["Intent created"]
    XCTAssertTrue(success.waitForExistence(timeout: 15), "create success alert missing")
    app.buttons["OK"].tap()
  }

  // MARK: - Dashboard mode refuses writes

  func testDashboardLockedAccountHasNoWriteControls() {
    let app = launchFresh()
    addAccountAndWait(app, name: "Locked Store")
    enableDashboardLock(app, name: "Locked Store")
    openPayments(app)

    // M4c: the create-intent toolbar button is a write control too.
    XCTAssertFalse(
      app.buttons["payments.newIntent"].exists,
      "dashboard-locked account must not expose create intent")

    openFirstChargeDetail(app)

    // The detail loads (read path works) but no Actions menu may appear.
    sleep(3)
    let actionsMenu = app.buttons["payments.charge.actions"]
    XCTAssertFalse(actionsMenu.exists, "dashboard-locked account must not show write controls")
    XCTAssertFalse(
      app.buttons["payments.charge.refund"].exists,
      "dashboard-locked account must not expose refund")
    XCTAssertFalse(
      app.buttons["payments.charge.capture"].exists,
      "dashboard-locked account must not expose capture")
  }
}
