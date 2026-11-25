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

  /// The account detail's Actions menu (management mode) opens and shows
  /// the onboarding-link entry; the link sheet restates the account and
  /// creates through the stubbed mock (POST /v1/account_links).
  func testAccountDetailActionsCreateOnboardingLink() {
    let app = launchFresh()
    addAccountAndWait(app, name: "connectactions")
    openConnect(app)

    let row = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "connect.row.")
    ).firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 15), "no connected-account row")
    row.tap()

    let actions = app.buttons["connect.detail.actions"]
    XCTAssertTrue(actions.waitForExistence(timeout: 15), "actions menu missing")
    actions.tap()

    let linkItem = app.buttons["connect.detail.link"]
    XCTAssertTrue(linkItem.waitForExistence(timeout: 10), "link action missing")
    linkItem.tap()

    let submit = app.buttons["connect.link.submit"]
    XCTAssertTrue(submit.waitForExistence(timeout: 10), "link sheet missing")
    submit.tap()

    let confirm = app.buttons.matching(
      NSPredicate(format: "identifier == %@", "connect.link.confirm")
    ).firstMatch
    XCTAssertTrue(confirm.waitForExistence(timeout: 10), "confirm missing")
    confirm.tap()

    let alert = app.descendants(matching: .any).matching(
      NSPredicate(format: "label CONTAINS %@", "Account link created")
    ).firstMatch
    XCTAssertTrue(alert.waitForExistence(timeout: 15), "success alert missing")
  }

  /// The Actions menu's login-link entry runs the same confirm-then-write
  /// flow against the stubbed mock (POST /v1/accounts/{a}/login_links).
  func testAccountDetailActionsCreateLoginLink() {
    let app = launchFresh()
    addAccountAndWait(app, name: "connectlogin")
    openConnect(app)

    let row = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "connect.row.")
    ).firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 15), "no connected-account row")
    row.tap()

    let actions = app.buttons["connect.detail.actions"]
    XCTAssertTrue(actions.waitForExistence(timeout: 15), "actions menu missing")
    actions.tap()

    let loginItem = app.buttons["connect.detail.loginLink"]
    XCTAssertTrue(loginItem.waitForExistence(timeout: 10), "login-link action missing")
    loginItem.tap()

    let submit = app.buttons["connect.loginlink.submit"]
    XCTAssertTrue(submit.waitForExistence(timeout: 10), "login-link sheet missing")
    submit.tap()

    let confirm = app.buttons.matching(
      NSPredicate(format: "identifier == %@", "connect.loginlink.confirm")
    ).firstMatch
    XCTAssertTrue(confirm.waitForExistence(timeout: 10), "confirm missing")
    confirm.tap()

    let alert = app.descendants(matching: .any).matching(
      NSPredicate(format: "label CONTAINS %@", "Login link created")
    ).firstMatch
    XCTAssertTrue(alert.waitForExistence(timeout: 15), "success alert missing")
  }

  /// The Actions menu's account-session entry runs the confirm-then-write
  /// flow against the stubbed mock (POST /v1/account_sessions).
  func testAccountDetailActionsCreateAccountSession() {
    let app = launchFresh()
    addAccountAndWait(app, name: "connectsession")
    openConnect(app)

    let row = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "connect.row.")
    ).firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 15), "no connected-account row")
    row.tap()

    let actions = app.buttons["connect.detail.actions"]
    XCTAssertTrue(actions.waitForExistence(timeout: 15), "actions menu missing")
    actions.tap()

    let sessionItem = app.buttons["connect.detail.session"]
    XCTAssertTrue(sessionItem.waitForExistence(timeout: 10), "session action missing")
    sessionItem.tap()

    let submit = app.buttons["connect.session.submit"]
    XCTAssertTrue(submit.waitForExistence(timeout: 10), "session sheet missing")
    submit.tap()

    let confirm = app.buttons.matching(
      NSPredicate(format: "identifier == %@", "connect.session.confirm")
    ).firstMatch
    XCTAssertTrue(confirm.waitForExistence(timeout: 10), "confirm missing")
    confirm.tap()

    let alert = app.descendants(matching: .any).matching(
      NSPredicate(format: "label CONTAINS %@", "Account session created")
    ).firstMatch
    XCTAssertTrue(alert.waitForExistence(timeout: 15), "success alert missing")
  }

  /// The Actions menu's capability entry toggles the first non-active
  /// capability (stripe-mock's card_payments: requested=true, inactive) via
  /// POST /v1/accounts/{a}/capabilities/{id}, then reloads the section.
  func testAccountDetailActionsToggleCapability() {
    let app = launchFresh()
    addAccountAndWait(app, name: "connectcapability")
    openConnect(app)

    let row = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "connect.row.")
    ).firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 15), "no connected-account row")
    row.tap()

    let actions = app.buttons["connect.detail.actions"]
    XCTAssertTrue(actions.waitForExistence(timeout: 15), "actions menu missing")
    actions.tap()

    let capabilityItem = app.buttons["connect.detail.capability"]
    XCTAssertTrue(capabilityItem.waitForExistence(timeout: 10), "capability action missing")
    capabilityItem.tap()

    let run = app.buttons.matching(
      NSPredicate(format: "identifier == %@", "connect.detail.capability.run")
    ).firstMatch
    XCTAssertTrue(run.waitForExistence(timeout: 10), "capability confirm missing")
    run.tap()

    let alert = app.descendants(matching: .any).matching(
      NSPredicate(format: "label CONTAINS %@", "Capability unrequested")
    ).firstMatch
    XCTAssertTrue(alert.waitForExistence(timeout: 15), "success alert missing")
  }

  /// The Actions menu's delete-person entry removes the mock's person row
  /// (DELETE /v1/accounts/{a}/persons/{id}) after confirmation.
  func testAccountDetailActionsDeletePerson() {
    let app = launchFresh()
    addAccountAndWait(app, name: "connectperson")
    openConnect(app)

    let row = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "connect.row.")
    ).firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 15), "no connected-account row")
    row.tap()

    let actions = app.buttons["connect.detail.actions"]
    XCTAssertTrue(actions.waitForExistence(timeout: 15), "actions menu missing")
    actions.tap()

    let personItem = app.buttons["connect.detail.deletePerson"]
    XCTAssertTrue(personItem.waitForExistence(timeout: 10), "delete-person action missing")
    personItem.tap()

    let run = app.buttons.matching(
      NSPredicate(format: "identifier == %@", "connect.detail.deletePerson.run")
    ).firstMatch
    XCTAssertTrue(run.waitForExistence(timeout: 10), "person confirm missing")
    run.tap()

    let alert = app.descendants(matching: .any).matching(
      NSPredicate(format: "label CONTAINS %@", "Person deleted")
    ).firstMatch
    XCTAssertTrue(alert.waitForExistence(timeout: 15), "success alert missing")
  }

  /// The Actions menu's remove-bank entry deletes the mock's external bank
  /// account (DELETE /v1/accounts/{a}/external_accounts/{id}).
  func testAccountDetailActionsRemoveBank() {
    let app = launchFresh()
    addAccountAndWait(app, name: "connectbank")
    openConnect(app)

    let row = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "connect.row.")
    ).firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 15), "no connected-account row")
    row.tap()

    let actions = app.buttons["connect.detail.actions"]
    XCTAssertTrue(actions.waitForExistence(timeout: 15), "actions menu missing")
    actions.tap()

    let bankItem = app.buttons["connect.detail.deleteBank"]
    XCTAssertTrue(bankItem.waitForExistence(timeout: 10), "remove-bank action missing")
    bankItem.tap()

    let run = app.buttons.matching(
      NSPredicate(format: "identifier == %@", "connect.detail.deleteBank.run")
    ).firstMatch
    XCTAssertTrue(run.waitForExistence(timeout: 10), "bank confirm missing")
    run.tap()

    let alert = app.descendants(matching: .any).matching(
      NSPredicate(format: "label CONTAINS %@", "Bank account removed")
    ).firstMatch
    XCTAssertTrue(alert.waitForExistence(timeout: 15), "success alert missing")
  }

  /// The application-fee detail's Refund action runs the full-fee refund
  /// (POST /v1/application_fees/{id}/refunds) after confirmation, and the
  /// success alert names the refund.
  func testFeeDetailRefundFlow() {
    let app = launchFresh()
    addAccountAndWait(app, name: "connectfee")
    openConnect(app)

    let feeRow = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "connect.fee.")
    ).firstMatch
    XCTAssertTrue(feeRow.waitForExistence(timeout: 15), "no application-fee row")
    feeRow.tap()

    let refund = app.buttons["connect.feeDetail.refund"]
    XCTAssertTrue(refund.waitForExistence(timeout: 15), "refund action missing")
    refund.tap()

    let run = app.buttons.matching(
      NSPredicate(format: "identifier == %@", "connect.feeDetail.refundRun")
    ).firstMatch
    XCTAssertTrue(run.waitForExistence(timeout: 10), "refund confirm missing")
    run.tap()

    let alert = app.descendants(matching: .any).matching(
      NSPredicate(format: "label CONTAINS %@", "Fee refunded")
    ).firstMatch
    XCTAssertTrue(alert.waitForExistence(timeout: 15), "success alert missing")
  }
}
