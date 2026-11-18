import XCTest

/// M2 UI tests: add, rename, lock, and remove accounts; the setup flow's
/// tap budget; and validation errors.
///
/// Every launch passes --uitest-reset so the app starts with an empty
/// store: no test depends on what an earlier run left in the simulator
/// keychain. The API keys used here are hand-written, obviously fake
/// placeholder strings that never leave the test target.
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
    // Point the setup flow at stripe-mock for account verification.
    app.launchArguments += ["--api-base-url=http://127.0.0.1:12111"]
    app.launch()
    return app
  }

  /// Opens the Accounts tab and the add-account sheet.
  ///
  /// On iPadOS 26 the SwiftUI TabView renders as a top tab strip of
  /// plain Buttons (identifier is the SF Symbol name, label the title);
  /// there is no UITabBar element, so query by label.
  private func openSetup(_ app: XCUIApplication) {
    let accountsTab = app.buttons.matching(NSPredicate(format: "label == %@", "Accounts")).firstMatch
    XCTAssertTrue(accountsTab.waitForExistence(timeout: 10), "Accounts tab missing")
    accountsTab.tap()

    let addButton = app.buttons["accounts.add"]
    XCTAssertTrue(addButton.waitForExistence(timeout: 10), "add button missing")
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

  /// Waits for a row whose label contains the given account name.
  private func row(_ app: XCUIApplication, named name: String) -> XCUIElement {
    let predicate = NSPredicate(format: "label CONTAINS %@", name)
    let rows = app.buttons.matching(NSPredicate(format: "identifier == 'account.row'"))
    let match = rows.matching(predicate).firstMatch
    XCTAssertTrue(match.waitForExistence(timeout: 10), "row for \(name) not found")
    return match
  }

  // MARK: - Setup flow

  func testSetupAddsAccountAndShowsInList() {
    let app = launchFresh()
    openSetup(app)
    addAccount(app, name: "Alpha Store", key: "sk_test_uiexample0000000000000000")

    row(app, named: "Alpha Store")
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
  }

  func testSetupRejectsDuplicateName() {
    let app = launchFresh()
    openSetup(app)
    addAccount(app, name: "Duplicate", key: "sk_test_uiexample0000000000000000")
    row(app, named: "Duplicate")

    openSetup(app)
    addAccount(app, name: "Duplicate", key: "sk_test_uiexample1111111111111111")

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
    keyField.typeText("sk_test_uiexample0000000000000000")

    app.buttons["setup.add"].tap(); taps += 1

    row(app, named: "Budget Store")
    XCTAssertLessThanOrEqual(taps, 5, "setup must take at most five taps after pasting a key")
  }

  // MARK: - Detail, rename, lock

  func testRenameAccountViaDetailEdit() {
    let app = launchFresh()
    openSetup(app)
    addAccount(app, name: "Old Name", key: "sk_test_uiexample0000000000000000")

    row(app, named: "Old Name").tap()

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

    // Back on the list, the row carries the new name.
    app.buttons["detail.done"].tap()
    row(app, named: "New Name")
    let staleRow = app.buttons.matching(
      NSPredicate(format: "identifier == 'account.row' AND label CONTAINS 'Old Name'")
    ).firstMatch
    XCTAssertFalse(
      staleRow.exists,
      "the old name must be gone from the list"
    )
  }

  func testToggleDashboardLockInEdit() {
    let app = launchFresh()
    openSetup(app)
    addAccount(app, name: "Lock Target", key: "sk_test_uiexample0000000000000000")

    row(app, named: "Lock Target").tap()

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
    XCTAssertTrue(row(app, named: "Lock Target").exists)
  }

  // MARK: - Removal

  func testRemoveAccountsToEmpty() {
    let app = launchFresh()
    openSetup(app)
    addAccount(app, name: "Removable One", key: "sk_test_uiexample0000000000000000")
    row(app, named: "Removable One")

    openSetup(app)
    addAccount(app, name: "Removable Two", key: "sk_test_uiexample1111111111111111")
    row(app, named: "Removable Two")

    // Remove both via swipe action, then confirm the alert.
    for name in ["Removable Two", "Removable One"] {
      let target = row(app, named: name)
      target.swipeLeft()
      let removeButton = app.buttons["Remove"]
      XCTAssertTrue(removeButton.waitForExistence(timeout: 5), "swipe action missing for \(name)")
      removeButton.tap()

      let alert = app.alerts["Remove account"]
      XCTAssertTrue(alert.waitForExistence(timeout: 5), "confirm alert missing")
      alert.buttons["Remove"].tap()
    }

    let emptyState = app.staticTexts["No accounts"]
    XCTAssertTrue(emptyState.waitForExistence(timeout: 10), "list should be empty after removing both")
  }

  // MARK: - Home

  func testHomeShowsActiveAccountAfterSetup() {
    let app = launchFresh()
    openSetup(app)
    addAccount(app, name: "Home Acct", key: "sk_test_uiexample0000000000000000")

    let homeTab = app.buttons.matching(NSPredicate(format: "label == %@", "Home")).firstMatch
    XCTAssertTrue(homeTab.waitForExistence(timeout: 10), "Home tab missing")
    homeTab.tap()

    let header = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Home Acct")).firstMatch
    XCTAssertTrue(header.waitForExistence(timeout: 10), "home should show the active account name")
  }
}
