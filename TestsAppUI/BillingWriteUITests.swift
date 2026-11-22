import XCTest

/// M6 slice-2 UI tests for the billing tab's coupon and promotion-code
/// flows against stripe-mock on 127.0.0.1:12111. The mock's fixtures are
/// stable: one coupon ("Z4OV52SU", named "25.5% off") and one promotion
/// code ("promo_1Pgc79B7WZ01zgkWNy4mn5NX", code "FALL20"). Writes echo a
/// fixture back, so these assert flow completion (sheet → submit →
/// success alert); state transitions are covered by service-level tests.
///
/// The API key is a hand-written, obviously fake placeholder that never
/// leaves the test target.
@MainActor
final class BillingWriteUITests: XCTestCase {

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
    keyField.typeText("sk_test_uitest1234")
    app.buttons["setup.add"].tap()
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
  /// coupon fixture row to appear.
  private func openBilling(_ app: XCUIApplication) {
    let billingButton = app.buttons["home.billing"]
    XCTAssertTrue(billingButton.waitForExistence(timeout: 10), "billing button missing")
    billingButton.tap()
    let couponRow = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier == %@", "billing.row.coupon.Z4OV52SU")
    ).firstMatch
    XCTAssertTrue(couponRow.waitForExistence(timeout: 20), "coupon row missing")
  }

  private func openAddMenu(_ app: XCUIApplication, item identifier: String) {
    let addButton = app.buttons["billing.add"]
    XCTAssertTrue(addButton.waitForExistence(timeout: 10), "add menu missing")
    waitHittable(app, addButton, "add menu")
    addButton.tap()
    let item = app.buttons[identifier]
    XCTAssertTrue(item.waitForExistence(timeout: 10), "menu item \(identifier) missing")
    item.tap()
  }

  private func couponRow(_ app: XCUIApplication) -> XCUIElement {
    let row = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier == %@", "billing.row.coupon.Z4OV52SU")
    ).firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 10), "coupon row missing")
    return row
  }

  /// Pushes the coupon fixture's detail screen from the Billing list.
  private func openCouponDetail(_ app: XCUIApplication) {
    let row = couponRow(app)
    waitHittable(app, row, "coupon row")
    // Tap near the row's bottom edge: a center tap can land on an
    // overlapping element and silently no-op.
    row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)).tap()

    let edit = app.buttons["coupon.edit"]
    XCTAssertTrue(edit.waitForExistence(timeout: 10), "coupon detail missing")
  }

  private func dismissAlert(_ app: XCUIApplication) {
    let ok = app.buttons["OK"]
    XCTAssertTrue(ok.waitForExistence(timeout: 10), "alert OK button missing")
    ok.tap()
  }

  // MARK: - Coupon detail

  /// Pushes the coupon fixture's detail screen and asserts it loaded (the
  /// edit and delete toolbar buttons exist only once the coupon is loaded
  /// and the account allows writes).
  func testCouponDetailShowsFixture() {
    let app = launchFresh()
    addAccountAndWait(app, name: "Billing Store")
    openBilling(app)
    openCouponDetail(app)

    XCTAssertTrue(app.buttons["coupon.delete"].waitForExistence(timeout: 10),
                  "delete button missing on coupon detail")
  }

  // MARK: - Create coupon flow

  /// Creates a coupon from the Billing toolbar: menu → sheet → name +
  /// percent off → submit → success alert. stripe-mock echoes a fixture
  /// coupon back.
  func testCreateCouponFlowCompletesAgainstMock() {
    let app = launchFresh()
    addAccountAndWait(app, name: "Coupon Store")
    openBilling(app)
    openAddMenu(app, item: "billing.newCoupon")

    let nameField = app.textFields["billing.coupon.create.name"]
    XCTAssertTrue(nameField.waitForExistence(timeout: 10), "create sheet missing")
    nameField.tap()
    nameField.typeText("Launch promo")

    let percentField = app.textFields["billing.coupon.create.percentOff"]
    XCTAssertTrue(percentField.waitForExistence(timeout: 10), "percent field missing")
    percentField.tap()
    percentField.typeText("10")

    let submit = app.buttons["billing.coupon.create.submit"]
    XCTAssertTrue(submit.waitForExistence(timeout: 10), "create submit missing")
    submit.tap()

    let success = app.staticTexts["Coupon created"]
    XCTAssertTrue(success.waitForExistence(timeout: 15), "create success alert missing")
    dismissAlert(app)
  }

  // MARK: - Create promotion code flow

  /// Creates a promotion code from the Billing toolbar: menu → sheet →
  /// code → submit → success alert. The coupon picker defaults to the
  /// first loaded coupon (the fixture), which stripe-mock echoes back.
  func testCreatePromotionCodeFlowCompletesAgainstMock() {
    let app = launchFresh()
    addAccountAndWait(app, name: "Promo Store")
    openBilling(app)
    openAddMenu(app, item: "billing.newPromotionCode")

    let codeField = app.textFields["billing.promo.create.code"]
    XCTAssertTrue(codeField.waitForExistence(timeout: 10), "create sheet missing")
    codeField.tap()
    codeField.typeText("FALLNEW")

    let submit = app.buttons["billing.promo.create.submit"]
    XCTAssertTrue(submit.waitForExistence(timeout: 10), "create submit missing")
    submit.tap()

    let success = app.staticTexts["Promotion code created"]
    XCTAssertTrue(success.waitForExistence(timeout: 15), "create success alert missing")
    dismissAlert(app)
  }

  // MARK: - Catalog rows

  /// The Products section decodes against the overlaid stripe-mock (decision
  /// 0029): the fixture product row renders and pushes its detail screen,
  /// which shows the product's fields and its price rows.
  func testProductRowsDecodeAndOpenDetail() {
    let app = launchFresh()
    addAccountAndWait(app, name: "Catalog Store")
    openBilling(app)

    let productRow = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "billing.row.product.prod_")
    ).firstMatch
    XCTAssertTrue(productRow.waitForExistence(timeout: 20),
                  "product row missing — products section failed to decode")
    waitHittable(app, productRow, "product row")
    productRow.tap()

    let actions = app.buttons["billing.product.actions"]
    XCTAssertTrue(actions.waitForExistence(timeout: 10), "product detail missing")
    actions.tap()
    let edit = app.buttons["billing.product.edit"]
    XCTAssertTrue(edit.waitForExistence(timeout: 5), "product actions menu missing")
  }

  /// The Prices section decodes against the overlaid stripe-mock: the
  /// fixture price row renders and pushes the price detail screen.
  func testPriceRowsDecodeAndOpenDetail() {
    let app = launchFresh()
    addAccountAndWait(app, name: "Price Store")
    openBilling(app)

    let priceRow = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "billing.row.price.price_")
    ).firstMatch
    XCTAssertTrue(priceRow.waitForExistence(timeout: 20),
                  "price row missing — prices section failed to decode")
    waitHittable(app, priceRow, "price row")
    priceRow.tap()

    let edit = app.buttons["price.edit"]
    XCTAssertTrue(edit.waitForExistence(timeout: 10), "price detail missing")
  }

  // MARK: - Delete coupon flow

  /// Deletes the coupon fixture from its detail screen: delete →
  /// confirmation alert → success alert. stripe-mock accepts any delete.
  func testDeleteCouponFlowCompletesAgainstMock() {
    let app = launchFresh()
    addAccountAndWait(app, name: "Delete Store")
    openBilling(app)
    openCouponDetail(app)

    let deleteButton = app.buttons["coupon.delete"]
    XCTAssertTrue(deleteButton.waitForExistence(timeout: 10), "delete button missing")
    waitHittable(app, deleteButton, "delete button")
    deleteButton.tap()

    let alert = app.alerts["Delete coupon?"]
    XCTAssertTrue(alert.waitForExistence(timeout: 10), "delete confirmation missing")
    alert.buttons["Delete"].tap()

    let success = app.staticTexts["Coupon deleted"]
    XCTAssertTrue(success.waitForExistence(timeout: 15), "delete success alert missing")
    dismissAlert(app)
  }
}
