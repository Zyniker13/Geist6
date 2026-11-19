# M4c-5: Filter design

## Context

M4c-5 adds filtering to the Payments list views. The ROADMAP specifies five filter dimensions:
status, amount, date, customer, method. Each segment (Intents, Charges, Refunds, Setup,
Methods, Links) supports a different subset of these dimensions, and a given dimension
may be implementable server-side (via the Stripe list API parameters) or only
client-side (after fetching the page).

## Decision

### 1. Filter model (`PaymentsFilter` in GeistData)

A single `struct PaymentsFilter: Equatable, Sendable` with optional fields:

```swift
public struct PaymentsFilter: Equatable, Sendable {
    public var dateStart: Date?
    public var dateEnd: Date?
    public var customer: String?
    public var status: String?          // raw value
    public var amountMin: Int?          // cents
    public var amountMax: Int?          // cents
    public var methodType: String?
    public var isEmpty: Bool { ... }
    public var createdInterval: DateInterval? { ... }
}
```

### 2. Per-object matching (`PaymentsFilter.matches(_:)`)

Extension on `PaymentsFilter` with one `matches` method per object type:

```swift
public extension PaymentsFilter {
    func matches(_ intent: PaymentIntent) -> Bool
    func matches(_ charge: Charge) -> Bool
    func matches(_ refund: Refund) -> Bool
    func matches(_ setup: SetupIntent) -> Bool
    func matches(_ method: PaymentMethod) -> Bool
    func matches(_ link: PaymentLink) -> Bool
}
```

Each applies only the dimensions that the object type has (e.g. `methodType` on a charge
checks `paymentMethodDetails?.type`; `status` on a refund checks the raw string;
`amount` checks the `amount` field). An empty filter matches everything.

**Why client-side for all dimensions:** The loaded list is at most 100 items per page
(default Stripe limit), so client-side filtering is fast and uniform. For segments that
support server-side date/customer, the model also passes those to the backend API so
the server-side and client-side filters work together (double-filtering is harmless).

### 3. Server-side parameter mapping

| Segment | Server-side | Client-side only |
|---|---|---|
| Intents | `created` range, `customer` | status, amount, methodType |
| Charges | `created` range, `customer` | status, amount, methodType |
| Refunds | — | date, status (string), amount |
| Setup | `created` range, `customer` | status, methodType |
| Methods | `customer`, `type` | date (created on object) |
| Links | `active` (Bool) | methodType (paymentMethodTypes) |

### 4. UI: `PaymentsFilterSheet`

A single sheet with controls per segment:

- **Date:** two optional DatePickers (from/to). For segments with server-side date,
  these are passed to the API as `created[gte]`/`created[lt]`.
- **Customer:** text field (intents, charges, methods server-side; others client-side).
- **Status:** picker with the relevant enum cases for the segment.
  - Intents: canceled, processing, requiresAction, requiresCapture, requiresConfirmation,
    requiresPaymentMethod, succeeded.
  - Charges: failed, pending, succeeded.
  - Refunds: raw string input (succeeded, failed, pending).
  - Setup: same as intents.
  - Methods: not available (no `status` field in the generated model).
  - Links: toggle for `active`.
- **Amount:** min/max numeric fields (intents, charges, refunds).
- **Method:** text field (intents, charges, methods). For links, a picker of the
  available paymentMethodTypes from the first link (or text field).

A "Filter" toolbar button with an active indicator (badge or "Filtered" tag) when the
filter is non-empty. A "Clear" button to reset.

### 5. Where logic lives

- `PaymentsFilter` + `matches(_:)` in **GeistData** (pure, swift-testable).
- `PaymentsModel.load(segment:filter:)` applies the filter after fetching.
- UI in **App** target (`PaymentsFilterSheet`, toolbar button).
- Unit tests in **TestsApp** (model-level) and **TestsApp** (filter logic via swift test).

### 6. Tests

- **GeistData unit tests:** `PaymentsFilterTests` — each `matches` method, each dimension,
  empty filter matches everything, boundary conditions (amount inclusive, date start
  inclusive / end exclusive).
- **Model tests:** verify the model passes the right server-side params per segment.
- **UI tests:** set a filter, verify the list narrows; verify the filter button indicator;
  verify clear resets the list.

## Consequences

- **Pros:** single filter model, testable pure logic, server-side + client-side for best
  accuracy, one sheet handles all segments.
- **Cons:** the status picker varies per segment (needs a segment-aware factory); method
  filter for links uses the first link's paymentMethodTypes (a heuristic).
- **Risk:** the generated PaymentMethod model has no `status` field (the pinned spec3 SDK
  omits it). The Methods segment status filter is simply not available.
