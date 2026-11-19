import XCTest

/// M4c-5 UI tests for the payments filter sheet. stripe-mock's list fixtures
/// are static (one intent whose customer is unset), so a customer filter
/// proves the full round trip: server-side param on the request, client-side
/// trim over the fetched page, and the filtered empty state.
///
/// The API key is a hand-written, obviously fake placeholder that never
/// leaves the test target.
@MainActor
final class PaymentFilterUITests: XCTestCase {

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
    keyField.typeText("sk_test_uibuild0000")
    app.buttons["setup.add"].tap()
    // Select the new account: home tiles (incl. home.payments) only appear
    // once an account is active.
    let row = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier == %@", "sidebar.account.\(name)")
    ).firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 10), "sidebar row for \(name) not found")
    row.tap()
  }

  private func openPayments(_ app: XCUIApplication) {
    let paymentsButton = app.buttons["home.payments"]
    XCTAssertTrue(paymentsButton.waitForExistence(timeout: 10), "payments button missing")
    paymentsButton.tap()
    let intentRow = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "payments.row.")
    ).firstMatch
    XCTAssertTrue(intentRow.waitForExistence(timeout: 20), "payments row missing")
  }

  private func waitHittable(_ app: XCUIApplication, _ element: XCUIElement,
                            _ name: String, timeout: TimeInterval = 10) {
    let exp = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "hittable == true"), object: element)
    let result = XCTWaiter.wait(for: [exp], timeout: timeout)
    XCTAssertTrue(result == .completed, "\(name) never became hittable")
  }

  /// Waits until no payment row exists (the filter narrowed the list away).
  private func waitRowsGone(_ app: XCUIApplication) {
    let anyRow = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "payments.row.")
    ).firstMatch
    let gone = NSPredicate(format: "exists == false")
    let exp = XCTNSPredicateExpectation(predicate: gone, object: anyRow)
    let result = XCTWaiter.wait(for: [exp], timeout: 15)
    XCTAssertTrue(result == .completed, "rows never disappeared after applying the filter")
  }

  private func filteredEmptyState(_ app: XCUIApplication) -> XCUIElement {
    app.descendants(matching: .any).matching(
      NSPredicate(format: "label CONTAINS %@", "match the filter")
    ).firstMatch
  }

  private func applyCustomerFilter(_ app: XCUIApplication, customer: String) {
    let filterButton = app.buttons["payments.filter"]
    XCTAssertTrue(filterButton.waitForExistence(timeout: 10), "filter button missing")
    waitHittable(app, filterButton, "filter button")
    filterButton.tap()
    let sheet = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier == %@", "payments.filter.sheet")
    ).firstMatch
    XCTAssertTrue(sheet.waitForExistence(timeout: 10), "filter sheet missing")

    let customerField = app.textFields["payments.filter.customer"]
    XCTAssertTrue(customerField.waitForExistence(timeout: 10), "customer field missing")
    waitHittable(app, customerField, "customer field")
    customerField.tap()
    customerField.typeText(customer)
    app.buttons["payments.filter.apply"].tap()
  }

  // MARK: - Tests

  func testFilterNarrowsListAndEmptyStateNamesTheFilter() {
    let app = launchFresh()
    addAccountAndWait(app, name: "Acme")
    openPayments(app)

    applyCustomerFilter(app, customer: "cus_nope_test")

    waitRowsGone(app)
    let empty = filteredEmptyState(app)
    XCTAssertTrue(empty.waitForExistence(timeout: 10), "filtered empty state missing")

    // Clearing the filter restores the list. The reopened sheet starts from
    // the applied filter, so "Clear all" resets the draft to empty first.
    let filterButton = app.buttons["payments.filter"]
    waitHittable(app, filterButton, "filter button (second pass)")
    filterButton.tap()
    let clearAll = app.buttons["payments.filter.clear"]
    XCTAssertTrue(clearAll.waitForExistence(timeout: 10), "clear button missing")
    clearAll.tap()
    app.buttons["payments.filter.apply"].tap()

    let restoredRow = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "payments.row.")
    ).firstMatch
    XCTAssertTrue(restoredRow.waitForExistence(timeout: 15), "rows never returned after clear")
  }
}
