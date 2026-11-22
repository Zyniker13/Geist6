# Decision 0031: Report-run downloads against stripe-mock

## Context

M7's report types/report runs slice (ROADMAP line 166: report types and
report runs — "run, wait, and download") has a done-when requiring report
runs to "download and open in the Files app (UI test)". The generated client
surface already exists (create/list/retrieve for report runs and report
types, plus Files). Probes against stripe-mock 0.206.0 (bare and via the
decision 0029 overlay) established:

- All five reporting endpoints serve 200 with canned fixtures; create returns
  a `succeeded` run whose `result` File is embedded with `url: null`.
- `/v1/files/{id}/contents` is not in the OpenAPI spec stripe-mock serves and
  fails; `expand[]=url` and `expand[]=result.url` (list and retrieve) return
  HTTP 500 from the mock's response builder.
- stripe-mock's response builder strips every field its bundled spec does not
  know (stripe-mock-testing), so patching the fixture file's `url` cannot
  make a URL appear in any response.

So no mock-side path — fixture patch, overlay spec, or expand — can hand the
app a download URL. The stock file fixture also carries purpose
`dispute_evidence`, which is cosmetic for this slice (the model decodes the
purpose enum regardless).

## Decision

1. **Nil-URL graceful path.** The run detail treats `result.url == nil` as a
   normal state: the download action renders disabled with an explanation,
   and the decode tests assert the mock's actual canned response (embedded
   result file, `url` null).
2. **Production download path.** The download action takes the run's
   `result.url`, GETs it with the account's secret key as the bearer token
   (Stripe's report-file URLs are short-lived and returned by Stripe itself;
   the key is sent only to a URL Stripe handed out), writes the bytes to a
   file in the app's documents directory named
   `<report_type>_<run_id>.csv`, and presents a ShareLink so the user saves
   or opens it in the Files app.
3. **UI-test seam.** The app accepts one documented launch argument,
   `-g6FileDownloadOverride <url>`, which replaces the download URL for
   report files. Production leaves it unset; only UI tests set it. The UI
   test hosts a tiny in-process HTTP server (NWListener in the test runner)
   that serves a deterministic CSV, registers the override, and drives the
   whole done-when flow: download → share sheet → Save to Files → Save.
   No companion server in check.sh — the server lives inside the UI test
   process, so gate orchestration is unchanged.

## Consequences

- The done-when is exercised literally: a UI test downloads a report run's
  file and completes the Files save flow, with the bytes coming from a real
  HTTP fetch the app performs.
- Production code carries exactly one test hook (the launch-argument URL
  override), discoverable and documented here; the shipping default path is
  the plain `result.url` fetch.
- stripe-mock's gap is asserted, not worked around: the nil-URL behavior is
  what users would also see on a run whose file URL has expired (Stripe
  expires them), so the graceful path is a real-product behavior, not a
  test accommodation.
- No upstream mock bytes are committed and the mock-overlay tool stays as
  decision 0029/0030 left it.
