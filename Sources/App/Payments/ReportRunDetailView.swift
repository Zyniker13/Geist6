import GeistData
import StripeModels
import SwiftUI

/// The detail screen for one report run (M7, decision 0031). Shows the
/// run's facts, offers "run again" behind the management-mode gate, and —
/// when the run succeeded and its result file carries a URL — downloads the
/// CSV with the account's key and hands it to a ShareLink so the user saves
/// it into the Files app. A run whose result URL is nil (never generated,
/// or expired) shows a disabled download with an explanation; that is a
/// real-product state Stripe produces, not a mock accommodation.
struct ReportRunDetailView: View {
  enum Phase: Equatable {
    case loading
    case loaded(ReportingReportRun)
    case failed(String)
  }

  enum DownloadPhase: Equatable {
    case idle
    case downloading
    case ready(URL)
    case failed(String)
  }

  let runID: String
  let backend: any PaymentsBackend
  /// The account key, sent only to Stripe-provided file URLs (decision 0031).
  let bearerToken: String
  /// Nil for dashboard-locked accounts: no write controls are shown.
  let writer: PaymentsWriteService?

  @State private var phase: Phase = .loading
  @State private var download: DownloadPhase = .idle
  @State private var runAgainPresented = false
  @State private var writeResult: WriteResult?
  @State private var downloader = ReportRunDownloader(
    overrideURL: ReportRunDownloader.launchArgumentOverride,
    session: ReportRunDownloader.defaultSession)

  var body: some View {
    Group {
      switch phase {
      case .loading:
        ProgressView()
      case .failed(let message):
        ContentUnavailableView(
          "Couldn't load report run",
          systemImage: "exclamationmark.triangle",
          description: Text(message)
        )
      case .loaded(let run):
        details(run)
      }
    }
    .navigationTitle("Report run")
    .navigationBarTitleDisplayMode(.inline)
    .task(id: runID) { await load() }
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        if let writer, case .loaded(let run) = phase {
          Button {
            runAgainPresented = true
          } label: {
            Label("Run again", systemImage: "arrow.clockwise")
          }
          .accessibilityIdentifier("payments.report.runAgain")
          .confirmationDialog(
            "Run \"\(run.reportType)\" again for the same interval?",
            isPresented: $runAgainPresented, titleVisibility: .visible
          ) {
            Button("Run report") {
              Task { await runAgain(run) }
            }
            .accessibilityIdentifier("payments.report.runAgainConfirm")
            Button("Cancel", role: .cancel) {}
          }
        }
      }
    }
    .writeResultAlert($writeResult)
  }

  private func details(_ run: ReportingReportRun) -> some View {
    List {
      Section {
        HStack(alignment: .firstTextBaseline) {
          Text(run.reportType)
            .font(.headline)
          Spacer(minLength: 8)
          PaymentStatusBadge(text: run.status)
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("payments.report.type")
      }

      Section("Details") {
        PaymentFactRow(
          label: "Created",
          value: run.created.date.formatted(date: .abbreviated, time: .shortened))
        if let succeededAt = run.succeededAt.valueOrNil {
          PaymentFactRow(
            label: "Succeeded",
            value: succeededAt.date.formatted(date: .abbreviated, time: .shortened))
        }
        if let intervalStart = run.parameters.intervalStart {
          PaymentFactRow(
            label: "Interval start",
            value: intervalStart.date.formatted(date: .abbreviated, time: .omitted))
        }
        if let intervalEnd = run.parameters.intervalEnd {
          PaymentFactRow(
            label: "Interval end",
            value: intervalEnd.date.formatted(date: .abbreviated, time: .omitted))
        }
        if let error = run.error.valueOrNil {
          PaymentFactRow(label: "Error", value: error)
        }
        if let file = run.result.valueOrNil {
          PaymentFactRow(label: "File", value: file.id)
          PaymentFactRow(label: "Size", value: "\(file.size) bytes")
        }
      }

      downloadSection(run)
    }
  }

  @ViewBuilder
  private func downloadSection(_ run: ReportingReportRun) -> some View {
    Section("Export") {
      switch download {
      case .idle:
        if let url = resultURL(run) {
          // Download first; the ShareLink appears only once the bytes are
          // in Documents, so "Saved" always describes a file that exists.
          Button {
            Task { await prepareFile(run, url: url) }
          } label: {
            Label("Download CSV", systemImage: "arrow.down.circle")
          }
          .accessibilityIdentifier("payments.report.download")
        } else {
          Label(
            "No downloadable file. Stripe's file URLs are short-lived; run "
              + "the report again to generate a fresh one.",
            systemImage: "arrow.down.circle.slash")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("payments.report.noURL")
          Button("Download") {}
            .disabled(true)
            .accessibilityIdentifier("payments.report.download")
        }
      case .downloading:
        HStack {
          ProgressView()
          Text("Downloading…").foregroundStyle(.secondary)
        }
      case .ready(let url):
        ShareLink(item: url, preview: SharePreview(fileName(run)))
          .accessibilityIdentifier("payments.report.share")
        Text("Saved as \(fileName(run)). Share it to the Files app.")
          .font(.footnote)
          .foregroundStyle(.secondary)
          .accessibilityIdentifier("payments.report.saved")
      case .failed(let message):
        Label(message, systemImage: "exclamationmark.triangle")
          .font(.footnote)
          .foregroundStyle(.secondary)
          .accessibilityIdentifier("payments.report.downloadError")
        Button("Try again") {
          Task { await downloadFile(run) }
        }
        .accessibilityIdentifier("payments.report.download")
      }
    }
  }

  /// The run's result URL, with the UI-test override applied last.
  private func resultURL(_ run: ReportingReportRun) -> URL? {
    if let override = ReportRunDownloader.launchArgumentOverride { return override }
    guard let file = run.result.valueOrNil else { return nil }
    return file.url.valueOrNil.flatMap(URL.init(string:))
  }

  private func fileName(_ run: ReportingReportRun) -> String {
    ReportRunDownloader.fileName(reportType: run.reportType, runID: run.id)
  }

  /// Prepares the file in Documents, then flips to `.ready` so the
  /// ShareLink hands the real file to the share sheet.
  private func prepareFile(_ run: ReportingReportRun, url: URL) async {
    download = .downloading
    do {
      let target = try await fetchAndWrite(run, url: url)
      download = .ready(target)
    } catch {
      download = .failed(String(describing: error))
    }
  }

  private func downloadFile(_ run: ReportingReportRun) async {
    guard let url = resultURL(run) else {
      download = .failed(ReportRunDownloadError.missingURL.localizedDescription)
      return
    }
    await prepareFile(run, url: url)
  }

  /// Fetches the bytes (real HTTP, the account's key as bearer) and writes
  /// them to Documents under the deterministic file name.
  private func fetchAndWrite(_ run: ReportingReportRun, url: URL) async throws -> URL {
    guard let file = run.result.valueOrNil else {
      throw ReportRunDownloadError.missingURL
    }
    let data = try await downloader.fetch(
      file: file, bearerToken: bearerToken, urlOverride: url)
    let directory = FileManager.default.urls(
      for: .documentDirectory, in: .userDomainMask
    ).first!
    let target = directory.appendingPathComponent(fileName(run))
    try data.write(to: target, options: .atomic)
    return target
  }

  /// Runs the same report type again over the same interval, behind the
  /// management gate, then reloads to pick up the new run.
  private func runAgain(_ run: ReportingReportRun) async {
    guard let writer else { return }
    do {
      _ = try await writer.createReportRun(
        reportType: run.reportType,
        intervalStart: run.parameters.intervalStart?.seconds,
        intervalEnd: run.parameters.intervalEnd?.seconds,
        summary: "Run report \(run.reportType)")
      writeResult = WriteResult(
        title: "Report started",
        message: "The report is running. Reload this list in a moment to see its result.")
      await load()
    } catch {
      writeResult = WriteResult(title: "Couldn't run report", message: writeErrorMessage(error))
    }
  }

  private func load() async {
    phase = .loading
    download = .idle
    do {
      let run = try await backend.retrieveReportRun(id: runID)
      phase = .loaded(run)
    } catch {
      phase = .failed(String(describing: error))
    }
  }
}
