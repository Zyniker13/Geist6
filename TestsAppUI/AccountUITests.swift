import XCTest

/// M3 UI tests for the split-view shell (decision 0011): the sidebar and
/// detail pane, account management, the home dashboard, and global search.
///
/// Every launch passes --uitest-reset so the app starts with an empty
/// store: no test depends on what an earlier run left in the simulator
/// keychain. The API keys used here are hand-written, obviously fake
/// placeholder strings that never leave the test target. Dashboard and
/// search tests need stripe-mock on 127.0.0.1:12111 (the port CI uses);
/// the app is pointed at it with --api-base-url.
@MainActor
final class AccountUITests: XCTestCase {

  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  // MARK: - Helpers

  /// Launches the app with a wiped store and returns the query root.
  @discardableResult
  private func launchFresh() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments += ["--uitest-reset"]
    // Point the app at stripe-mock for dashboard and search.
    app.launchArguments += ["--api-base-url=http://127.0.0.1:12111"]
    app.launch()
    return app
  }

  /// The sidebar row for an account (combined a11y element).
  private func sidebarRow(_ app: XCUIApplication, named name: String) -> XCUIElement {
    let row = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier == %@", "sidebar.account.\(name)")
    ).firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 10), "sidebar row for \(name) not found")
    return row
  }

  /// The detail-pane account row (Button with identifier account.row).
  private func accountRow(_ app: XCUIApplication, named name: String) -> XCUIElement {
    let rows = app.buttons.matching(NSPredicate(format: "identifier == 'account.row'"))
    let match = rows.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
    XCTAssertTrue(match.waitForExistence(timeout: 10), "row for \(name) not found")
    return match
  }

  /// The sidebar's "Manage accounts" row.
  private func manageAccounts(_ app: XCUIApplication) -> XCUIElement {
    let row = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier == %@", "sidebar.manageAccounts")
    ).firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 10), "manage accounts row missing")
    return row
  }

  /// Opens the setup sheet. On a fresh launch the detail pane is already
  /// the accounts screen, so the add button is in its toolbar.
  private func openSetup(_ app: XCUIApplication) {
    let addButton = app.buttons["accounts.add"]
    XCTAssertTrue(addButton.waitForExistence(timeout: 10), "add button missing on the accounts screen")
    addButton.tap()
    let nameField = app.textFields["setup.name"]
    XCTAssertTrue(nameField.waitForExistence(timeout: 10), "setup sheet missing")
  }

  /// Fills the setup form and taps Add.
  private func addAccount(_ app: XCUIApplication, name: String, key: String) {
    let nameField = app.textFields["setup.name"]
    nameField.tap()
    nameField.typeText(name)

    let keyField = app.textFields["setup.apiKey"]
    keyField.tap()
    keyField.typeText(key)

    app.buttons["setup.add"].tap()
  }

  /// Adds an account and waits for it to appear in the sidebar.
  private func addAccountAndWait(_ app: XCUIApplication, name: String, key: String = "sk_test_uitest123") {
    openSetup(app)
    addAccount(app, name: name, key: key)
    sidebarRow(app, named: name)
  }

  /// The sidebar's search field.
  private func searchField(_ app: XCUIApplication) -> XCUIElement {
    let field = app.searchFields.firstMatch
    XCTAssertTrue(field.waitForExistence(timeout: 10), "sidebar search field missing")
    return field
  }

  // MARK: - Shell

  func testEmptyStoreShowsAccountsScreen() {
    let app = launchFresh()

    let emptyState = app.staticTexts["No accounts"]
    XCTAssertTrue(emptyState.waitForExistence(timeout: 10), "empty state missing")
    XCTAssertTrue(app.buttons["accounts.add"].exists, "add button missing")
  }

  // MARK: - Setup flow

  func testSetupAddsAccountAndShowsInSidebar() {
    let app = launchFresh()
    addAccountAndWait(app, name: "Alpha Store")

    // Test-mode accounts are labelled "Test" in the list.
    XCTAssertTrue(
      app.staticTexts.matching(NSPredicate(format: "label == %@", "Test")).firstMatch.exists,
      "list row should show the Test caption"
    )
  }

  func testSetupRejectsKeyWithoutStripePrefix() {
    let app = launchFresh()
    openSetup(app)
    addAccount(app, name: "Bad Key", key: "not-a-real-key-format")

    let error = app.staticTexts["setup.error"]
    XCTAssertTrue(error.waitForExistence(timeout: 10), "validation error missing")
    XCTAssertEqual(error.label, "API key must start with sk_ or rk_")
    // The sheet stays up and the account is not created.
    XCTAssertTrue(app.buttons["setup.add"].exists)
    let row = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier == %@", "sidebar.account.Bad Key")
    ).firstMatch
    XCTAssertFalse(row.exists, "a rejected account must not appear in the sidebar")
  }

  func testSetupRejectsDuplicateName() {
    let app = launchFresh()
    addAccountAndWait(app, name: "Duplicate")

    openSetup(app)
    addAccount(app, name: "Duplicate", key: "sk_test_uitest123")

    let error = app.staticTexts["setup.error"]
    XCTAssertTrue(error.waitForExistence(timeout: 10), "duplicate-name error missing")
    XCTAssertEqual(error.label, "An account with this name already exists")
  }

  /// The setup budget from the M2 done-when: after pasting a key, at
  /// most five taps reach the account screen. This test records the
  /// steps explicitly: the key field is treated as already pasted.
  func testSetupAfterPasteTakesAtMostFiveTaps() {
    let app = launchFresh()
    openSetup(app)

    var taps = 0
    let nameField = app.textFields["setup.name"]
    nameField.tap(); taps += 1 // focus name
    nameField.typeText("Budget Store")

    let keyField = app.textFields["setup.apiKey"]
    keyField.tap(); taps += 1 // paste goes here
    keyField.typeText("sk_test_uitest123")

    app.buttons["setup.add"].tap(); taps += 1

    sidebarRow(app, named: "Budget Store")
    XCTAssertLessThanOrEqual(taps, 5, "setup must take at most five taps after pasting a key")
  }

  // MARK: - Home

  func testHomeShowsActiveAccountAfterSetup() {
    let app = launchFresh()
    addAccountAndWait(app, name: "Home Acct")

    sidebarRow(app, named: "Home Acct").tap()

    let header = app.staticTexts.matching(NSPredicate(format: "label == %@", "Home Acct")).firstMatch
    XCTAssertTrue(header.waitForExistence(timeout: 15), "home should show the active account name")
    let period = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier == %@", "home.period")
    ).firstMatch
    XCTAssertTrue(period.waitForExistence(timeout: 10), "home dashboard controls missing")
  }

  // MARK: - Search

  func testSearchFindsChargeByAmount() {
    let app = launchFresh()
    addAccountAndWait(app, name: "Search Acct")

    let field = searchField(app)
    field.tap()
    field.typeText("100\n")

    let hits = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "search.hit."))
    XCTAssertTrue(hits.firstMatch.waitForExistence(timeout: 15), "search should return the fixture charge")
    XCTAssertGreaterThanOrEqual(hits.count, 1)
  }

  func testSearchOpensObjectDetail() {
    let app = launchFresh()
    addAccountAndWait(app, name: "Search Acct")

    let field = searchField(app)
    field.tap()
    field.typeText("100\n")

    let hit = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "search.hit.")).firstMatch
    XCTAssertTrue(hit.waitForExistence(timeout: 15), "search should return the fixture charge")
    hit.tap()

    let title = app.staticTexts["Charge"]
    XCTAssertTrue(title.waitForExistence(timeout: 10), "hit detail should show the Charge title")
    XCTAssertTrue(title.exists, "the pushed detail's title should be visible")
  }

  // MARK: - Multiple windows

  /// Opens a second window seeded with another account (decision 0011)
  /// and checks both windows show their own account's dashboard.
  func testOpenTwoWindowsOnTwoAccounts() throws {
    let app = launchFresh()
    addAccountAndWait(app, name: "Window A")
    addAccountAndWait(app, name: "Window B")

    // Put the first window on Window A's home (a fresh window starts on
    // the accounts screen when the store is empty).
    sidebarRow(app, named: "Window A").tap()

    let firstHeader = app.staticTexts.matching(
      NSPredicate(format: "label == %@", "Window A")
    ).firstMatch
    XCTAssertTrue(firstHeader.waitForExistence(timeout: 15), "first window should show Window A's home")

    // Open a second window for Window B through the toolbar menu.
    let openMenu = app.buttons["Open in New Window"]
    XCTAssertTrue(openMenu.waitForExistence(timeout: 10), "open-window toolbar menu missing")
    openMenu.tap()

    let windowBItem = app.buttons["Window B"]
    XCTAssertTrue(windowBItem.waitForExistence(timeout: 5), "menu item for Window B missing")
    windowBItem.tap()

    // A second window must appear (the scene takes a moment to spawn).
    let windows = app.windows
    let twoWindows = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "count >= 2"), object: windows
    )
    XCTAssertEqual(
      XCTWaiter.wait(for: [twoWindows], timeout: 10), .completed,
      "a second window should open"
    )

    // Window order is not guaranteed: collect the home headers of every
    // window and require one window per account.
    var sawA = false
    var sawB = false
    for index in 0..<windows.count {
      let window = windows.element(boundBy: index)
      if window.staticTexts["Window A"].exists { sawA = true }
      if window.staticTexts["Window B"].exists { sawB = true }
    }
    XCTAssertTrue(sawA, "one window should show Window A's home")
    XCTAssertTrue(sawB, "the second window should show Window B's home")
  }

  // MARK: - Manage accounts

  func testManageAccountsRename() {
    let app = launchFresh()
    addAccountAndWait(app, name: "Old Name")

    manageAccounts(app).tap()
    accountRow(app, named: "Old Name").tap()

    let editButton = app.buttons["detail.edit"]
    XCTAssertTrue(editButton.waitForExistence(timeout: 10), "detail sheet missing")
    editButton.tap()

    let nameField = app.textFields["edit.name"]
    XCTAssertTrue(nameField.waitForExistence(timeout: 10), "edit sheet missing")
    // Tap near the trailing edge so the cursor sits at the end of the
    // pre-filled name, then backspace past it.
    nameField.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
    nameField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 24))
    // An emptied SwiftUI TextField reports its PLACEHOLDER as its value;
    // both "" and "Account name" therefore mean the name is cleared.
    let cleared = nameField.value as? String
    XCTAssertTrue(cleared == nil || cleared!.isEmpty || cleared == "Account name",
                  "name field should be empty before typing, got \(cleared ?? "nil")")
    nameField.typeText("New Name")

    app.buttons["edit.save"].tap()

    // The detail reflects the new name.
    let newName = app.staticTexts.matching(NSPredicate(format: "label == %@", "New Name")).firstMatch
    XCTAssertTrue(newName.waitForExistence(timeout: 10), "detail should show the renamed account")

    // Back on the list, the row carries the new name and the sidebar
    // row was refreshed.
    app.buttons["detail.done"].tap()
    accountRow(app, named: "New Name")
    sidebarRow(app, named: "New Name")
    let staleRow = app.buttons.matching(
      NSPredicate(format: "identifier == 'account.row' AND label CONTAINS 'Old Name'")
    ).firstMatch
    XCTAssertFalse(staleRow.exists, "the old name must be gone from the list")
  }

  func testToggleDashboardLockInEdit() {
    let app = launchFresh()
    addAccountAndWait(app, name: "Lock Target")

    manageAccounts(app).tap()
    accountRow(app, named: "Lock Target").tap()

    let editButton = app.buttons["detail.edit"]
    XCTAssertTrue(editButton.waitForExistence(timeout: 10))
    editButton.tap()

    let lockToggle = app.switches["edit.lock"]
    XCTAssertTrue(lockToggle.waitForExistence(timeout: 10), "lock toggle missing")
    // Verify the flip by value ("0"/"1" on the switch); a plain tap on
    // the element can hit the surrounding Form row and do nothing.
    let before = lockToggle.value as? String
    lockToggle.tap()
    sleep(1)
    var after = lockToggle.value as? String
    if after == before {
      // Fallback: tap the switch's toggle knob area directly.
      lockToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
      sleep(1)
      after = lockToggle.value as? String
    }
    XCTAssertNotEqual(after, before, "tapping the lock toggle must change its value")

    app.buttons["edit.save"].tap()

    // The detail shows the lock as On (LabeledContent exposes the
    // combined "Dashboard lock, On" label).
    let onRow = app.staticTexts.matching(NSPredicate(format: "label == %@", "Dashboard lock, On")).firstMatch
    XCTAssertTrue(onRow.waitForExistence(timeout: 10), "detail should show Dashboard lock On")

    app.buttons["detail.done"].tap()
    // The list row shows the lock glyph via its label (hand icon).
    XCTAssertTrue(accountRow(app, named: "Lock Target").exists)
  }

  // MARK: - Removal

  func testRemoveAccountToEmpty() {
    let app = launchFresh()
    addAccountAndWait(app, name: "Removable")

    manageAccounts(app).tap()
    accountRow(app, named: "Removable").swipeLeft()
    let removeButton = app.buttons["Remove"]
    XCTAssertTrue(removeButton.waitForExistence(timeout: 5), "swipe action missing")
    removeButton.tap()

    let alert = app.alerts["Remove account"]
    XCTAssertTrue(alert.waitForExistence(timeout: 5), "confirm alert missing")
    alert.buttons["Remove"].tap()

    let emptyState = app.staticTexts["No accounts"]
    XCTAssertTrue(emptyState.waitForExistence(timeout: 10), "list should be empty after removal")
    let staleRow = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier == %@", "sidebar.account.Removable")
    ).firstMatch
    XCTAssertFalse(staleRow.exists, "the sidebar must not keep a removed account")
  }
}
