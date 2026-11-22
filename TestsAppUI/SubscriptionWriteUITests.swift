import XCTest

/// M6 slice-4 UI tests for the billing tab's subscription flows against
/// stripe-mock on 127.0.0.1:12111. The mock's subscription list has one
/// active fixture, so rows are matched by the `billing.row.subscription.sub_`
/// prefix rather than a hardcoded ID. stripe-mock echoes a fixture back on
/// every verb, so these assert flow completion (menu → confirm/sheet →
/// success alert); state transitions are covered by service-level tests.
///
/// The API key is a hand-written, obviously fake placeholder that never
/// leaves the test target.
@MainActor
final class SubscriptionWriteUITests: XCTestCase {

  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  // MARK: - Helpers (same pattern as InvoiceWriteUITests)

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
    keyField.typeText("sk_test_uitest1234")
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
  /// subscription fixture row to appear.
  private func openBilling(_ app: XCUIApplication) {
    let billingButton = app.buttons["home.billing"]
    XCTAssertTrue(billingButton.waitForExistence(timeout: 10), "billing button missing")
    billingButton.tap()
    let subscriptionRow = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "billing.row.subscription.sub_")
    ).firstMatch
    XCTAssertTrue(subscriptionRow.waitForExistence(timeout: 20), "subscription row missing")
  }

  /// Pushes the subscription fixture's detail screen from the Billing list.
  private func openSubscriptionDetail(_ app: XCUIApplication) {
    let row = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "billing.row.subscription.sub_")
    ).firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 10), "subscription row missing")
    waitHittable(app, row, "subscription row")
    // Tap near the row's bottom edge: a center tap can land on an
    // overlapping element and silently no-op.
    row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)).tap()

    let nav = app.navigationBars["Subscription"]
    XCTAssertTrue(nav.waitForExistence(timeout: 10), "subscription detail missing")
  }

  /// Opens the detail screen's Actions menu and taps `item`.
  private func openActionsMenu(_ app: XCUIApplication, item identifier: String) {
    let menu = app.buttons["billing.subscription.actions"]
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

  /// The active fixture's detail screen exposes the Actions menu once loaded
  /// and the account allows writes.
  func testSubscriptionDetailShowsActionsMenu() {
    let app = launchFresh()
    addAccountAndWait(app, name: "Sub Store")
    openBilling(app)
    openSubscriptionDetail(app)

    XCTAssertTrue(app.buttons["billing.subscription.actions"].exists, "actions menu missing")
  }

  // MARK: - Edit flow

  /// Edits the fixture's details: menu → sheet → description → submit →
  /// success alert. stripe-mock echoes the subscription back.
  func testEditSubscriptionFlowCompletesAgainstMock() {
    let app = launchFresh()
    addAccountAndWait(app, name: "Edit Sub Store")
    openBilling(app)
    openSubscriptionDetail(app)
    openActionsMenu(app, item: "billing.subscription.edit")

    let description = app.textFields["billing.subscription.edit.description"]
    XCTAssertTrue(description.waitForExistence(timeout: 10), "edit sheet missing")
    description.tap()
    description.typeText("Website plan")

    let submit = app.buttons["billing.subscription.edit.submit"]
    XCTAssertTrue(submit.waitForExistence(timeout: 10), "edit submit missing")
    submit.tap()

    let success = app.staticTexts["Subscription updated"]
    XCTAssertTrue(success.waitForExistence(timeout: 15), "edit success alert missing")
    dismissAlert(app)
  }

  // MARK: - Pause flow

  /// Resumes the active fixture: menu → confirmation → run → success alert.
  /// The stripe-mock fixture already has `pause_collection` set, so the
  /// detail screen offers Resume… (not Pause…); the pause verb itself is
  /// covered at the service level. stripe-mock accepts the resume verb.
  func testResumeSubscriptionFlowCompletesAgainstMock() {
    let app = launchFresh()
    addAccountAndWait(app, name: "Resume Store")
    openBilling(app)
    openSubscriptionDetail(app)
    openActionsMenu(app, item: "billing.subscription.resume")

    let run = app.buttons["billing.subscription.resumeRun"].firstMatch
    XCTAssertTrue(run.waitForExistence(timeout: 10), "resume confirmation missing")
    waitHittable(app, run, "resume run")
    run.tap()

    let success = app.staticTexts["Subscription resumed"]
    XCTAssertTrue(success.waitForExistence(timeout: 15), "resume success alert missing")
    dismissAlert(app)
  }

  /// A paused-collection fixture must NOT offer Pause… again (it is already
  /// paused) — the resume entry is what shows instead.
  func testPausedFixtureHidesPauseEntry() {
    let app = launchFresh()
    addAccountAndWait(app, name: "No Pause Store")
    openBilling(app)
    openSubscriptionDetail(app)

    let menu = app.buttons["billing.subscription.actions"]
    XCTAssertTrue(menu.waitForExistence(timeout: 10), "actions menu missing")
    menu.tap()
    let pause = app.buttons["billing.subscription.pause"]
    XCTAssertFalse(pause.waitForExistence(timeout: 3), "Pause… must be hidden for a paused fixture")
    let resume = app.buttons["billing.subscription.resume"]
    XCTAssertTrue(resume.exists, "Resume… missing for a paused fixture")
  }

  // MARK: - Migrate flow

  /// Migrates the classic fixture to flexible billing: menu → confirmation
  /// dialog → run → success alert. stripe-mock accepts the migrate verb.
  func testMigrateSubscriptionFlowCompletesAgainstMock() {
    let app = launchFresh()
    addAccountAndWait(app, name: "Migrate Store")
    openBilling(app)
    openSubscriptionDetail(app)
    openActionsMenu(app, item: "billing.subscription.migrate")

    let run = app.buttons["billing.subscription.migrateRun"].firstMatch
    XCTAssertTrue(run.waitForExistence(timeout: 10), "migrate confirmation missing")
    waitHittable(app, run, "migrate run")
    run.tap()

    let success = app.staticTexts["Subscription migrated"]
    XCTAssertTrue(success.waitForExistence(timeout: 15), "migrate success alert missing")
    dismissAlert(app)
  }

  // MARK: - Add item flow

  /// Adds an item to the fixture: menu → sheet → price ID + quantity →
  /// submit → success alert. stripe-mock echoes a subscription item back.
  func testAddSubscriptionItemFlowCompletesAgainstMock() {
    let app = launchFresh()
    addAccountAndWait(app, name: "Item Store")
    openBilling(app)
    openSubscriptionDetail(app)
    openActionsMenu(app, item: "billing.subscription.addItem")

    let price = app.textFields["billing.subscription.item.add.price"]
    XCTAssertTrue(price.waitForExistence(timeout: 10), "add-item sheet missing")
    price.tap()
    price.typeText("price_123")

    let submit = app.buttons["billing.subscription.item.add.submit"]
    XCTAssertTrue(submit.waitForExistence(timeout: 10), "add submit missing")
    submit.tap()

    let success = app.staticTexts["Item added"]
    XCTAssertTrue(success.waitForExistence(timeout: 15), "add-item success alert missing")
    dismissAlert(app)
  }

  // MARK: - Dashboard-mode safety

  /// A dashboard-locked account shows the subscription detail but none of
  /// its write controls: the Actions menu never appears.
  func testDashboardLockedAccountHasNoSubscriptionWriteControls() {
    let app = launchFresh()
    addAccountAndWait(app, name: "Locked Sub Store")
    enableDashboardLock(app, name: "Locked Sub Store")
    openBilling(app)
    openSubscriptionDetail(app)

    let actions = app.buttons["billing.subscription.actions"]
    XCTAssertFalse(
      actions.exists,
      "dashboard-locked account must not expose the subscription actions menu")
  }
}
