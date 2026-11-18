# Home dashboard metrics: definitions and data sources

Research note for milestone M3. Written from Stripe's documentation as of
2026-11-17, against API version `2026-10-28.endive` (the pinned spec).
Sources are listed at the end.

The home screen shows, per account and per selected period and currency:
balances, volume, net, refunds, disputes, fees, successful and failed
payments, new customers, upcoming payouts, and recent activity. This note
fixes exactly where each figure comes from and how it is computed, so the
implementation and its fixtures follow one definition.

## Design rules

1. **Money figures come from the balance-transaction ledger, not from
   charges.** A balance transaction is the ledger entry Stripe itself
   writes when money moves; its `amount` is the gross movement in the
   currency's smallest unit, `fee` the Stripe fee, and `net` the amount
   after the fee. Summing ledger entries is the same arithmetic the
   dashboard does, and it is correct for partial captures (the ledger
   entry carries the captured amount) and for charges created outside the
   app.
2. **Classification uses `reporting_category` first, `type` as fallback.**
   Every balance transaction carries a `reporting_category` string
   (`charge`, `refund`, `fee`, `dispute`, `payout`, `adjustment`, and
   others). The category is the stable classification; the `type`
   enumeration is finer-grained and is only used when a category is
   missing or unrecognized.
3. **Counts (payments, customers) come from the object lists**, because
   the ledger does not record failed payments (a failed charge never
   settles, so it has no balance transaction).
4. **Balances are shown as Stripe reports them.** `GET /v1/balance`
   returns `available` and `pending` as arrays of `{amount, currency}`;
   the app displays those values directly and does not recompute them.
5. **All sums are per currency.** Amounts in different currencies are
   never added together; the currency picker selects which currency's
   figures are shown, and the balance section lists every currency.
6. **Display divides by 100 except for the no-divide set.** The
   Currencies section below lists the 15 currencies whose `amount` is
   the currency unit itself; every other currency divides by 100.

## Endpoints and parameters

| Figure | Endpoint | Parameters | Notes |
| --- | --- | --- | --- |
| Balances | `GET /v1/balance` | none | `available[]`, `pending[]` per currency |
| Volume, net, refunds, disputes, fees, chart series | `GET /v1/balance_transactions` | `created[gte]`, `created[lt]`, `currency`, `limit=100`, `starting_after` | paginate to the end of the period |
| Successful/failed payments | `GET /v1/charges` | `created[gte]`, `created[lt]`, `limit=100`, `starting_after` | count `status` client-side; the list has no server-side `status` filter |
| New customers | `GET /v1/customers` | `created[gte]`, `created[lt]`, `limit=100`, `starting_after` | count of customers created in the period |
| Upcoming payouts | `GET /v1/payouts` | `status=pending`, `limit=10` | `arrival_date`, `amount`, `currency`, `status` |
| Recent activity | `GET /v1/events` | `limit=20` | newest first; events are retained for 30 days |
| Search | `GET /v1/{charges,customers,invoices,payment_intents,prices,products,subscriptions}/search` | `query`, `limit`, `page` | see Search section |

All list endpoints use cursor pagination (`starting_after` /
`ending_before`); the client follows `has_more` until it is false. The
`created` filter is a timestamp interval object (`gt`, `gte`, `lt`, `lte`)
in Unix seconds. The Search API is rate-limited to 20 read requests/second
per account, so search calls are made on user action, not on refresh.

## Figure definitions

Let the period be the half-open interval `[start, end)` in UTC, and let
`T` be the set of balance transactions in the period for the selected
currency. Each figure is a sum over the ledger entries whose
`reporting_category` is in the figure's category set.

- **Gross volume** = `sum(amount)` over `T` where
  `reporting_category` is in `{charge, partial_capture_reversal}`.
  Charge entries are positive; a `partial_capture_reversal` entry is
  negative and reverses the uncaptured part of an authorization, so
  summing both yields the captured amount (the money actually taken in),
  which is what the reporting-categories page says to count against the
  sale.
- **Fees** = `sum(amount)` over `T` where
  `reporting_category == "fee"` (positive amounts). This is the Stripe
  fee category only; `network_cost`, `tax`, and `platform_earning` are
  separate categories and are not folded into the fees figure.
- **Refunds** = `abs(sum(amount))` over `T` where
  `reporting_category` is in `{refund, refund_failure}`. Refund entries
  are negative; a `refund_failure` entry is positive (the money came
  back because the refund failed), so the sum is the net refund and the
  figure is shown as a positive number.
- **Disputes** = `abs(sum(amount))` over `T` where
  `reporting_category` is in `{dispute, dispute_reversal}`. Dispute
  entries (lost disputes) are negative; a `dispute_reversal` entry is
  positive (the dispute was won back), so the sum is the net dispute and
  the figure is shown as a positive number.
- **Net** = gross volume − fees − refunds − disputes. This is the
  money the account keeps from the period's sales flow. It is derived
  from the same ledger entries as the other figures, so the four
  components always add up to the displayed net.
- **Successful payments** = count of charges in the period with
  `status == "succeeded"`; **failed payments** = count with
  `status == "failed"`. Charges with other statuses (`pending`,
  `expired`) are not counted in either figure.
- **New customers** = count of customers with `created` in the period.
- **Upcoming payouts** = payouts with `status == "pending"` (scheduled,
  not yet sent), shown as `arrival_date` and amount in the payout
  currency. Payouts in `in_transit` are listed separately when present.
- **Recent activity** = the 20 newest events, each shown as its type
  (e.g. `charge.succeeded`), the object it concerns, and its creation
  time. Events are only available for the last 30 days; the section is
  labeled as such.
- **Chart** = daily gross volume for the period: one bar per UTC day,
  `sum(amount)` of the volume-category ledger entries whose `created`
  falls in that day. Days with no entries are zero.

### Reporting categories (pinned spec)

The `reporting_category` field is a plain string on the
`BalanceTransaction` object. The pinned spec (`2026-10-28.endive`)
documents these category values (from the Reporting API's category
enum, which enumerates the same set):

`advance`, `advance_funding`, `anticipation_repayment`, `charge`,
`charge_failure`, `climate_order_purchase`, `climate_order_refund`,
`connect_collection_transfer`, `connect_reserved_funds`,
`contribution`, `dispute`, `dispute_reversal`, `fee`,
`financing_paydown`, `financing_paydown_reversal`, `financing_payout`,
`financing_payout_reversal`, `issuing_authorization_hold`,
`issuing_authorization_release`, `issuing_dispute`,
`issuing_transaction`, `network_cost`, `other_adjustment`,
`partial_capture_reversal`, `payout`, `payout_reversal`,
`platform_earning`, `platform_earning_refund`, `refund`,
`refund_failure`, `risk_reserved_funds`, `tax`, `topup`,
`topup_reversal`, `transfer`, `transfer_reversal`,
`unreconciled_customer_funds`

Only `charge`, `partial_capture_reversal`, `fee`, `refund`,
`refund_failure`, `dispute`, and `dispute_reversal` feed the home
figures; every other category is excluded (it moves money between the
account and its bank or between accounts, and counting it as volume
would double-count).

### Category fallback

`reporting_category` is always present on the object, but if it is
empty or not one of the documented values, classify by `type` instead.
The mapping below follows the reporting-categories page's
type→category table; anything not listed is excluded from all figures:

| `type` values | Treated as |
| --- | --- |
| `charge`, `payment` | charge (volume) |
| `refund`, `payment_refund` | refund |
| `payment_failure_refund` | refund |
| `payment_reversal` | dispute |
| `stripe_fee` | fee |
| `payout`, `payout_cancel`, `payout_failure` | payout (excluded from net) |
| `transfer`, `transfer_cancel`, `transfer_failure`, `recipient_transfer`, `recipient_transfer_cancel`, `recipient_transfer_failure` | transfer (excluded) |
| `application_fee`, `application_fee_refund` | platform earning (excluded) |
| `adjustment` | excluded (ambiguous without `reporting_category`) |
| anything else | excluded from all figures |

## Currencies

Amounts are integers in the currency's smallest unit as the API
represents them. The display rule is: divide by 100 unless the currency
is in the "no-divide" set below.

The currencies page lists 16 zero-decimal currencies with general API
support, as of 2026-11-17:

`BIF CLP DJF GNF JPY KMF KRW MGA PYG RWF UGX VND VUV XAF XOF XPF`

For most of these the `amount` is the currency unit itself (500 JPY is
`amount: 500`). Two of them are exceptions, per the page's "Special
cases" section: **UGX** and **ISK** "transitioned to zero-decimal but
backward compatibility requires you to represent them as a two-decimal
value, where the decimal amount is always 00" — to charge 5 UGX the API
takes `amount: 500`. So UGX and ISK are divided by 100 for display.

**HUF** and **TWD** are charged as two-decimal amounts (a HUF 10.45
balance is `amount: 1045`), so they are also divided by 100.

The resulting **no-divide set** (display the integer as-is) is the 15
currencies:

`BIF CLP DJF GNF JPY KMF KRW MGA PYG RWF VND VUV XAF XOF XPF`

The app keeps this set in one place (a constant in the domain layer) so
display, fixtures, and tests agree. Every other currency divides by 100.

## Periods

The period picker offers: **Today**, **7 days**, **30 days**, **90 days**.
"Today" is the current UTC day; the others are the trailing N UTC days
including today. The interval is `[startOfTodayUTC − (N−1) days,
endOfTodayUTC + 1 day)` in Unix seconds, computed once per refresh.
Stripe's list filters accept the interval directly, so no client-side
date filtering is needed for the ledger figures; the chart still groups
by UTC day.

## Search

The Search API exists for charges, customers, invoices, payment intents,
prices, products, and subscriptions; for other resources the app falls
back to the list endpoint with its documented filters. Search is
eventually consistent (Stripe says not to use it in read-after-write
flows) and is rate-limited to 20 read requests/second per account, so
search calls are made on user action, not on refresh.

### Query language (from the Search Query Language page)

- `field:value` exact match, case-insensitive; string values need
  quotes, numeric values may omit them.
- `field~"value"` substring match, case-insensitive, minimum 3
  characters; string-type fields only.
- `field>value`, `field<value`, `field>=value`, `field<=value` for
  numeric fields.
- `AND` / `OR` to combine clauses, `-field:value` to negate,
  `field:null` to test for absence.
- Field types: **token** (exact match only), **string** (exact and
  substring), **numeric** (exact and comparison). Using an operator a
  type does not support returns an error.

### Supported query fields per resource

| Resource | Fields (type) |
| --- | --- |
| Charges | `amount` (numeric), `created` (numeric), `currency` (token), `customer` (token), `status` (token), `disputed` (token `true`/`false`), `refunded` (token `true`/`false`/`null`), `billing_details.address.postal_code` (token), `payment_method_details.{source}.{last4,exp_month,exp_year,brand,fingerprint,reader,location}` (token), `metadata` |
| Customers | `created` (numeric), `email` (string), `name` (string), `phone` (string), `metadata` |
| Invoices | `created` (numeric), `total` (numeric), `currency` (token), `customer` (token), `status` (string), `number` (string), `receipt_number` (string), `subscription` (string), `last_finalization_error_code` (token), `last_finalization_error_type` (token), `metadata` |
| Payment intents | `amount` (numeric), `created` (numeric), `currency` (token), `customer` (token), `status` (token), `metadata` |
| Prices | `active` (token), `currency` (token), `type` (token), `lookup_key` (string), `product` (string), `metadata` |
| Products | `active` (token), `shippable` (token), `name` (string), `description` (string), `url` (string), `metadata` |
| Subscriptions | `created` (numeric), `canceled_at` (numeric), `status` (token), `metadata` |

**No resource supports an `id` query field.** An object ID can therefore
never be found through the Search API; opening an object by ID always
goes through the direct `retrieve*` endpoint (see Open by ID).

### Query construction for the global search box

The box inspects the input shape and builds one query per resource:

- **Object ID pasted** (matches a known prefix such as `ch_`, `cus_`,
  `in_`, `pi_`, `price_`, `prod_`, `sub_`, `evt_`, `po_`, `re_`, `dp_`,
  `tr_`): the app retrieves that object directly by ID. No search query
  is run, because no resource has an `id` field.
- **Email** (contains `@`): customers `email:"<value>"` (exact) and, if
  the exact match returns nothing, `email~"<value>"` (substring, only
  when the value is at least 3 characters).
- **Amount** (digits only): charges `amount:<value>`, payment intents
  `amount:<value>`, invoices `total:<value>`. The value is interpreted
  in the selected currency's smallest unit, so `1000` in JPY means 1000
  yen and in USD means $10.00.
- **Free text** (3+ characters): customers `name~"<text>"`, products
  `name~"<text>" OR description~"<text>"`, prices `lookup_key~"<text>"`,
  invoices `number~"<text>" OR receipt_number~"<text>"`. Charges have no
  free-text field (no `customer_email` or `customer_name` field exists),
  so free text does not search charges.

The box runs the per-resource searches in parallel (bounded to the
20 rps limit by issuing at most a handful at once) and groups results by
resource. Each result row opens the object detail view by ID.

### Open by ID

Any Stripe object ID pasted anywhere (search box, or a dedicated field)
is parsed by its prefix (`ch_`, `cus_`, `in_`, `pi_`, `price_`, `prod_`,
`sub_`, `evt_`, `po_`, `re_`, `dp_`, `tr_`, and the full prefix table in
the generated models) and retrieved with the matching `retrieve*`
method. This is the only way to open an object by ID, since the Search
API has no `id` field. Unknown prefixes show an error naming the
prefix.

## Offline and staleness

Every section of the home screen carries the timestamp of the last
successful fetch. When a refresh fails (network down, API error), the
section keeps its last values and is marked **stale** with the age of the
data; the error is shown once, not per section. The app never shows a
zero figure for a failed fetch — zero is a real value and must be
distinguishable from "no data".

## Fixtures for the done-when check

Three hand-checked fixture accounts, one per currency, covering the
zero-decimal path:

1. **USD** (two-decimal): a period with 3 charges (one partially
   refunded, one disputed), 2 refunds, 1 fee, 1 payout, 1 failed charge,
   2 new customers. Expected figures computed by hand from the fixture
   ledger.
2. **EUR** (two-decimal): a period with 2 charges, 1 refund, 1 fee,
   1 dispute, 1 new customer.
3. **JPY** (zero-decimal): a period with 3 charges, 1 refund, 1 fee,
   1 new customer. Amounts are whole yen; display must not divide.

The fixtures are hand-written JSON with obviously fake values
(`acct_test_123`, `alice@example.com`, `bob@example.com`), decoded
through the same generated models the app uses, and the expected figures
are written out in the test file with the arithmetic shown. The tests
assert the computed figures equal the hand-computed ones, for every
figure on the home screen.

## Sources

- Balance object: `https://docs.stripe.com/api/balance/balance_object`
- Balance transactions: `https://docs.stripe.com/api/balance_transactions/object`,
  `https://docs.stripe.com/api/balance_transactions/list`
- Charges: `https://docs.stripe.com/api/charges/object`,
  `https://docs.stripe.com/api/charges/list`
- Customers: `https://docs.stripe.com/api/customers/list`
- Payouts: `https://docs.stripe.com/api/payouts/list`
- Events: `https://docs.stripe.com/api/events/list`
- Search API, query language, and per-resource query fields:
  `https://docs.stripe.com/search`; search endpoints:
  `https://docs.stripe.com/api/charges/search`,
  `https://docs.stripe.com/api/customers/search`
- Reporting categories: `https://docs.stripe.com/reports/reporting-categories`
- Currencies and zero-decimal list: `https://docs.stripe.com/currencies`
- Rate limits: `https://docs.stripe.com/api/limits` (see `docs/stripe/limits.md`)
- Pinned spec: `2026-10-28.endive` (see `docs/decisions/0004-pinned-api-version.md`)
