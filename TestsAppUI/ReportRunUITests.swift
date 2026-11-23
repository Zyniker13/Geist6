import Network
import XCTest

/// M7 report-run UI tests (decision 0031). The mock's canned runs carry
/// `url: null`, so the nil-URL state is asserted directly against the mock.
/// The download flow is exercised through decision 0031's documented seam:
/// the app accepts `-g6FileDownloadOverride <url>`, and this test runner
/// hosts a tiny NWListener HTTP server serving a deterministic CSV so the
/// download is a real HTTP fetch the app performs. The Files-app save
/// (share sheet → Save to Files → Save) completes the roadmap done-when.
///
/// The API key is a hand-written, obviously fake placeholder that never
/// leaves the test target.
@MainActor
final class ReportRunUITests: XCTestCase {

  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  // MARK: - Helpers

  @discardableResult
  private func launchFresh(overrides: [String] = []) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments += ["--uitest-reset"]
    app.launchArguments += ["--api-base-url=http://127.0.0.1:12111"]
    app.launchArguments += overrides
    app.launch()
    return app
  }

  private func waitHittable(_ app: XCUIApplication, _ element: XCUIElement,
                            _ name: String, timeout: TimeInterval = 10) {
    let exp = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "hittable == true"), object: element)
    let result = XCTWaiter.wait(for: [exp], timeout: timeout)
    XCTAssertTrue(result == .completed, "\(name) never became hittable")
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
    // setup-time GET /v1/account verification.
    keyField.typeText("sk_test_uitest1234")
    app.buttons["setup.add"].tap()
    let row = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier == %@", "sidebar.account.\(name)")
    ).firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 10), "sidebar row for \(name) not found")
    row.tap()
  }

  /// Opens the Reports segment in Payments.
  private func openReportsSegment(_ app: XCUIApplication) {
    let paymentsButton = app.buttons["home.payments"]
    XCTAssertTrue(paymentsButton.waitForExistence(timeout: 10), "payments button missing")
    paymentsButton.tap()
    let reportsSegment = app.buttons["Reports"]
    XCTAssertTrue(reportsSegment.waitForExistence(timeout: 10), "reports segment missing")
    waitHittable(app, reportsSegment, "reports segment")
    reportsSegment.tap()
    let switched = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier == %@", "payments.segment.reports")
    ).firstMatch
    XCTAssertTrue(switched.waitForExistence(timeout: 10), "segment did not switch to reports")
    let runRow = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "payments.row.frr_")
    ).firstMatch
    XCTAssertTrue(runRow.waitForExistence(timeout: 20), "report run row missing")
  }

  // MARK: - Tests

  /// The reports section lists the mock's canned run; the run's result file
  /// has `url: null`, so the detail shows the download action disabled with
  /// an explanation — the graceful path (decision 0031, point 1).
  func testReportsSectionListsRunAndNilURLDisablesDownload() {
    let app = launchFresh()
    addAccountAndWait(app, name: "Report Store")
    openReportsSegment(app)

    // Push the canned run's detail.
    let runRow = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "payments.row.frr_")
    ).firstMatch
    waitHittable(app, runRow, "report run row")
    runRow.tap()

    let download = app.buttons["payments.report.download"]
    XCTAssertTrue(download.waitForExistence(timeout: 20), "download action missing")
    XCTAssertFalse(download.isEnabled, "a run with a nil result URL must not offer download")

    let explanation = app.staticTexts["payments.report.noURL"]
    XCTAssertTrue(explanation.waitForExistence(timeout: 10), "nil-URL explanation missing")
  }

  /// The full done-when: run a report, open its detail, download the file
  /// over HTTP from the in-runner server, and save it through the Files app.
  func testDownloadReportRunAndSaveToFiles() throws {
    // 1. In-runner HTTP server serving a deterministic CSV.
    let server = try FileDownloadTestServer()
    try server.start()
    defer { server.stop() }

    // 2. Launch with the documented override pointing at the server.
    let app = launchFresh(overrides: [
      "-g6FileDownloadOverride=\(server.url)",
    ])
    addAccountAndWait(app, name: "Download Store")
    openReportsSegment(app)

    // 3. Push the canned run's detail; the override supplies the URL, so
    //    download is enabled even though the mock's `url` is null.
    let runRow = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "payments.row.frr_")
    ).firstMatch
    waitHittable(app, runRow, "report run row")
    runRow.tap()

    let download = app.buttons["payments.report.download"]
    XCTAssertTrue(download.waitForExistence(timeout: 20), "download action missing")
    waitHittable(app, download, "download action")
    download.tap()

    // 4. The app fetched the CSV over HTTP from the runner's server.
    let hit = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier == %@", "payments.report.share")
    ).firstMatch
    XCTAssertTrue(hit.waitForExistence(timeout: 20), "share action missing after download")
    XCTAssertTrue(server.hitCount == 1, "the server saw \(server.hitCount) hits, expected 1")

    // 5. Save to Files via the share sheet.
    waitHittable(app, hit, "share action")
    hit.tap()
    // The share sheet's Files action: navigate into "Save to Files".
    // The action lives in the share-sheet extension process, where it is a
    // Cell, not a Button — so match by label across all element types.
    let saveToFiles = app.descendants(matching: .any)
      .matching(NSPredicate(format: "label == %@", "Save to Files"))
      .firstMatch
    XCTAssertTrue(saveToFiles.waitForExistence(timeout: 20), "Save to Files action missing")
    saveToFiles.tap()
    let saveButton = app.descendants(matching: .any)
      .matching(NSPredicate(format: "label == %@ OR identifier == %@", "Save", "Save"))
      .matching(NSPredicate(format: "isEnabled == YES"))
      .firstMatch
    XCTAssertTrue(saveButton.waitForExistence(timeout: 20), "Save button missing")
    waitHittable(app, saveButton, "Save button")
    saveButton.tap()

    // 6. The sheet closes and the detail confirms the saved file name.
    let saved = app.staticTexts["payments.report.saved"]
    XCTAssertTrue(saved.waitForExistence(timeout: 15), "saved confirmation missing")
  }
}

// MARK: - In-runner file server

/// A tiny HTTP server inside the test runner process that serves one
/// deterministic CSV body (decision 0031, point 3). No companion process
/// in check.sh: the server lives and dies with this test.
final class FileDownloadTestServer: @unchecked Sendable {
  private var listener: NWListener?
  private let queue = DispatchQueue(label: "g6.file-server")
  private(set) var servedCount = 0
  private let lock = NSLock()
  private var port: UInt16 = 0

  static let csv = "category,currency,description,net_amount\ngross_volume,usd,Charge,1000\n"

  var url: String { "http://127.0.0.1:\(port)/report.csv" }

  func start() throws {
    let parameter = NWParameters.tcp
    let options = NWProtocolTCP.Options()
    options.noDelay = true
    parameter.defaultProtocolStack.transportProtocol = options
    let listener = try NWListener(using: parameter, on: .any)
    self.listener = listener
    let ready = DispatchSemaphore(value: 0)
    listener.stateUpdateHandler = { [weak self] (state: NWListener.State) in
      if case .ready = state {
        if let p = self?.listener?.port?.rawValue, p != 0 {
          self?.port = p
        }
        ready.signal()
      }
      if case .failed = state { ready.signal() }
    }
    listener.newConnectionHandler = { [weak self] connection in
      self?.handle(connection)
    }
    listener.start(queue: queue)
    _ = ready.wait(timeout: .now() + 5)
    guard port != 0 else { throw NSError(domain: "g6.file-server", code: 1) }
  }

  func stop() {
    listener?.cancel()
    listener = nil
  }

  var hitCount: Int {
    lock.withLock { servedCount }
  }

  private func handle(_ connection: NWConnection) {
    connection.start(queue: queue)
    receiveRequest(connection)
  }

  private func receiveRequest(_ connection: NWConnection) {
    connection.receive(minimumIncompleteLength: 1, maximumLength: 16_384) {
      [weak self] data, _, isComplete, error in
      guard let self else { return }
      lock.lock()
      servedCount += 1
      lock.unlock()
      let body = Self.csv
      let head = """
      HTTP/1.1 200 OK\r
      Content-Type: text/csv\r
      Content-Length: \(body.utf8.count)\r
      Connection: close\r
      \r

      """
      connection.send(
        content: Data((head + body).utf8), completion: .contentProcessed { _ in
          connection.cancel()
        })
      if isComplete || error != nil { return }
    }
  }
}
