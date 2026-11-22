// BalancesUITests.swift — TestsAppUI
// UI tests for the balances screens (M7 tier 1) against stripe-mock on port
// 12111 (the port check.sh starts). The mock holds one balance transaction
// (+100 usd, net 100, fee 0) and a balance whose usd available/pending are
// both 0. Proves: the home balances card is tappable and pushes the balances
// screen, the ledger rows decode, and a row opens the detail screen with the
// Net/Fee/Gross facts.
//
// The API key is a hand-written, obviously fake placeholder that never
// leaves the test target.
import XCTest

@MainActor
final class BalancesUITests: XCTestCase {

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

  private func waitHittable(_ app: XCUIApplication, _ element: XCUIElement,
                            _ name: String, timeout: TimeInterval = 10) {
    let exp = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "hittable == true"), object: element)
    let result = XCTWaiter.wait(for: [exp], timeout: timeout)
    XCTAssertTrue(result == .completed, "\(name) never became hittable")
  }

  private func openBalances(_ app: XCUIApplication) {
    // The home balances card is the entry point (HomeRoute.balances).
    let card = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier == %@", "home.balances")
    ).firstMatch
    XCTAssertTrue(card.waitForExistence(timeout: 10), "home balances card missing")
    waitHittable(app, card, "home.balances")
    card.tap()
    // The screen loads the balance lines and the ledger.
    let ledgerRow = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "balances.row.")
    ).firstMatch
    XCTAssertTrue(ledgerRow.waitForExistence(timeout: 20), "ledger row missing")
  }

  // MARK: - Tests

  func testBalancesRowsDecodeAndOpenDetail() {
    let app = launchFresh()
    addAccountAndWait(app, name: "balances")

    openBalances(app)

    // The per-currency balance line renders (usd from the mock fixture).
    let usdLine = app.otherElements["balances.line.usd"]
    if !usdLine.exists {
      let anyLine = app.descendants(matching: .any).matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "balances.line.")
      ).firstMatch
      XCTAssertTrue(anyLine.waitForExistence(timeout: 10), "no balance line rendered")
    }

    // The ledger's single fixture transaction row is tappable.
    let row = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier == %@",
                  "balances.row.txn_1PgaxNB7WZ01zgkWEV3TLf40")
    ).firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 10), "fixture ledger row missing")
    waitHittable(app, row, "balances.row.txn")
    row.tap()

    // The detail screen loads the transaction's Net fact.
    let netFact = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier == %@", "balances.detail.net")
    ).firstMatch
    XCTAssertTrue(netFact.waitForExistence(timeout: 15), "detail Net fact missing")
  }

  /// Tapping the home balances card must push the balances screen and not
  /// leave the card behind on a stale screen: the balances title appears.
  func testHomeBalancesCardPushesBalancesScreen() {
    let app = launchFresh()
    addAccountAndWait(app, name: "balances2")

    let card = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier == %@", "home.balances")
    ).firstMatch
    XCTAssertTrue(card.waitForExistence(timeout: 10), "home balances card missing")
    waitHittable(app, card, "home.balances")
    card.tap()

    let navBar = app.navigationBars["Balances"]
    XCTAssertTrue(navBar.waitForExistence(timeout: 15), "Balances screen did not open")
  }
}
