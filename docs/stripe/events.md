# Events, activity, and what a client app can receive

Research note from milestone M0. Written from Stripe's documentation as of
2026-11-16, against API version 2026-10-28.endive (spec release v2600).
Sources are listed at the end.

## The two event worlds

Stripe emits two event shapes:

- **Snapshot events** (`/v1`): the event's `data.object` carries a full
  snapshot of the affected API object, rendered at the version in force when
  the event was created. Most `/v1` resources emit these.
- **Thin events**: a minimal, unversioned payload naming what happened; the
  consumer fetches the object itself. All `/v2` resources emit thin events,
  and some `/v1` resources do too. The event's `data` carries related-object
  context (`related_object`, `reason`), not a full snapshot.

The Events API exposes both kinds through `GET /v1/events` and
`GET /v1/events/{id}` (retrievable for 30 days), which is what a serverless
client app uses.

## Why the app polls instead of listening

Webhook endpoints and v2 event destinations must be **publicly reachable
HTTPS URLs**. An iPad app has no server, no fixed address, and no inbound
TLS; Stripe offers no push channel for unhosted clients. So:

- While the app is open, the activity feed polls `GET /v1/events` on an
  interval, filtered by the account and mode it is viewing (Connect platforms
  get connected-account events tagged with `account`).
- Background refresh (BGAppRefresh tasks) polls less often and evaluates
  alert rules (M11) against what it finds; notifications are local
  notifications raised by the app, and the UI says plainly that background
  alerts can be late.
- The poller de-duplicates by event ID, keeps its cursor per account and
  mode, and treats the 30-day retention window as the feed's maximum history.

Thin events are handled by fetching the referenced object on demand, which
keeps the feed uniform.

## What this means for alert latency

Stripe's own guidance for delayed consumers is to use the Events API
timestamps and de-duplicate by ID; delivery order is not guaranteed, and
`created` (seconds) can collide. Alert rules therefore compare against the
event cursor's stored position, not wall-clock order, and the widget's
"disputes due" tile reads dispute objects directly (their `deadline` is
source-of-truth data) rather than depending on event arrival.

## Event destinations the user may already have

Users who run their own servers register webhook endpoints or v2 event
destinations on the account (up to 16). The app can list and show these
(tier 2 in the matrix) and show their delivery health only through what the
API exposes; it never needs one of its own.

## Sources

- `https://docs.stripe.com/api-v2-overview.md` — thin events, `/v2` event behavior
- `https://docs.stripe.com/events/how-events-work.md` — event formats (snapshot vs thin), event destinations
- `https://docs.stripe.com/webhooks.md` — public HTTPS URL requirement, retry windows, ordering caveats
- `https://docs.stripe.com/api/events.md` — Events API endpoints and the 30-day retrieval window
- `https://docs.stripe.com/api/events/types.md` — event type catalog used for feed filtering and alert-rule pickers
