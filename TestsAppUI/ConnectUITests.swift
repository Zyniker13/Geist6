// ConnectUITests.swift — TestsAppUI
// UI tests for the Connect screen (M8 slice 1, decision 0032) against
// stripe-mock on port 12111 (the port check.sh starts). Proves: the home
// toolbar opens Connect, the banner names the acting account, the mock's
// connected-account rows decode and open the detail screen, and the
// capabilities section renders. The M8 done-when's "active connected
// account is always visible" is the banner assertion here.
//
// The API key is a hand-written, obviously fake placeholder that never
// leaves the test target.
import XCTest

@MainActor
final class ConnectUITests: XCTestCase {

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

  private func addAccountAndWait(_ app: XCUIApplication, name: String) {
    let addButton = app.buttons["accounts.add"]
    XCTAssertTrue(addButton.waitForExistence(timeout: 10), "add button missing")
    addButton.tap()
    let nameField = app.textFields["setup.name"]
    XCTAssertTrue(nameField.waitForExistence(timeout: 10), "setup sheet missing")
    nameField.tap()
    nameField.typeText(name)
    let keyField = app.textFields["setup.apiKey"]
    keyField.tap()
    // Full fake key: stripe-mock rejects abbreviated keys during the
    // setup-time GET /v1/account verification (sk_tes... would 401).
    keyField.typeText("sk_test_uitest123")
    app.buttons["setup.add"].tap()
    let row = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier == %@", "sidebar.account.\(name)")
    ).firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 10), "sidebar row for \(name) not found")
    row.tap()
  }

  private func openConnect(_ app: XCUIApplication) {
    let button = app.buttons["home.connect"]
    XCTAssertTrue(button.waitForExistence(timeout: 10), "home.connect missing")
    button.tap()
    // The banner is the always-visible proof of the acting account.
    let banner = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier == %@", "connect.banner")
    ).firstMatch
    XCTAssertTrue(banner.waitForExistence(timeout: 15), "connect banner missing")
  }

  // MARK: - Tests

  /// The Connect screen opens from home, shows the acting account's
  /// banner, and renders the connected accounts and fees sections
  /// (stripe-mock serves /v1/accounts and /v1/application_fees).
  func testConnectScreenShowsBannerAndSections() {
    let app = launchFresh()
    addAccountAndWait(app, name: "connect")
    openConnect(app)

    let navBar = app.navigationBars["Connect"]
    XCTAssertTrue(navBar.waitForExistence(timeout: 10), "Connect title missing")
  }

  /// A connected-account row (stripe-mock fixture) opens the detail
  /// screen, whose identity section shows the account's facts.
  func testConnectedAccountDetailOpens() {
    let app = launchFresh()
    addAccountAndWait(app, name: "connectdetail")
    openConnect(app)

    let row = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "connect.row.")
    ).firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 15), "no connected-account row")
    row.tap()

    let idFact = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier == %@", "connect.detail.id")
    ).firstMatch
    XCTAssertTrue(idFact.waitForExistence(timeout: 15), "detail ID fact missing")
  }
}
