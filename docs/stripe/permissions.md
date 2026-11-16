# Restricted-key permissions and the two recommended sets

Research note from milestone M0. Written from Stripe's documentation as of
2026-11-16, against API version 2026-10-28.endive (spec release v2600).
Sources are listed at the end.

## How restricted-key permissions work

A restricted API key (RAK) grants, per resource, one of three permissions:
**None**, **Read**, or **Write**. The mapping from HTTP verbs is documented:

- `GET` → read
- `POST` → write
- `DELETE` → write

Write implies read: a key that can write a resource can also read it. A key
without the needed permission gets an invalid-request error whose message
names the permission to add (the app relies on this in its permission map).
The Dashboard picker groups permissions into categories and offers a
connected-accounts permission column for Connect users.

Stripe's permissions reference (written for Stripe Apps, which generate RAKs
with the same permission model) names the permission per object, for example
`payment_intent_read` / `payment_intent_write`, `charge_read` /
`charge_write` (Charges and Refunds share one permission), `invoice_read` /
`invoice_write`, `connected_account_read` for Accounts, `event_read` for
Events, `file_read` / `file_write` for Files, and so on. The generated
`coverage-matrix.md` carries the documented permission name for every row.
Resources absent from that reference (Terminal, Issuing, Treasury, Identity,
Climate, Tax settings, Sigma, Webhook endpoints, balance settings, Radar value
lists, most `/v2` endpoints) are granted through the Dashboard key picker
under their resource names; the app treats them as unknown until a read
succeeds, and never probes with a write.

## No API, no pre-filled link

Two facts the setup flow depends on:

1. **Key management is Dashboard-only.** The pinned spec has no endpoints to
   create, list, edit, or revoke API keys. The app cannot create a RAK for
   the user.
2. **No pre-filled restricted-key link exists for general apps.** The Dashboard
   has no documented URL that opens the "Create restricted key" dialog with a
   name and permission set pre-selected. The only sanctioned mechanism is a
   Stripe App: an install link carries the app's declared permissions, and the
   user generates the pre-provisioned key from the app's settings page. That
   requires publishing an app (out of scope for v1.0.0; see `access.md`). Setup
   therefore links to `https://dashboard.stripe.com/apikeys` and lists exactly
   which boxes to tick for the chosen set.

## The two recommended permission sets

Both sets are read-first and follow least privilege. The exact tick-lists
below use the resource names as the Dashboard picker groups them; the
permission names on the right are Stripe's documented object-permission
names.

### Dashboard (read-only on everything the app shows)

Grants read on every resource the app can display, and nothing else. The
app's Dashboard mode never sends a write regardless, but a read-only key
bounds the damage a leaked key can do.

Core reads: Accounts (`connected_account_read`), Balance
(`balance_read`), Balance transaction sources
(`balance_transaction_source_read`), Charges and Refunds (`charge_read`),
Checkout Sessions (`checkout_session_read`), Customers (`customer_read`),
Disputes (`dispute_read`), Events (`event_read`), Files (`file_read`),
Invoices (`invoice_read`), Mandates (`mandate_read`), Payment intents
(`payment_intent_read`), Payment links (`payment_links_read`), Payment
methods (`payment_method_read`), Payment records (`payment_records_read`),
Prices (`plan_read`), Products (`product_read`), Promotion codes
(`promotion_code_read`), Quotes (`quote_read`), Setup intents
(`setup_intent_read`), Subscriptions (`subscription_read`), Tax rates
(`tax_rate_read`), Test clocks (`billing_clock_read`), Top-ups
(`top_up_read`), Transfers (`transfer_read`), Apple Pay domains
(`apple_pay_domain_read`), Payment method domains
(`payment_method_domain_read`), Payment method configurations
(`payment_method_configurations_read`), Shipping rates
(`shipping_rate_read`), Reports (`report_runs_and_report_types_read`),
Entitlements (`entitlement_read`), Customer sessions
(`customer_session_read`), Confirmation tokens (`confirmation_token_read`),
Billing meters (`billing_meter_read`) and meter events
(`billing_meter_event_read`), Credit notes (`credit_note_read`), Radar
reviews (`review_read`), Application fees (`application_fee_read`), Login
links (`edit_link_write` is a write-only creation; skip unless the user needs
Express login links).

Plus, through the Dashboard picker, read on: Terminal (readers, locations,
configurations), Issuing (cards, cardholders, authorizations, transactions,
disputes, tokens), Treasury (financial accounts, transactions), Identity
(verification sessions and reports), Climate (orders, products, suppliers),
Financial Connections (accounts, sessions, transactions), Sigma
(scheduled query runs), Webhook endpoints, Balance settings, Cash balances,
Exchange rates, Country specs, 3DS authentications.

### Management (read plus write on what the app can change)

Everything above with the matching write permissions added, restricted to the
actions the app offers: `charge_write` (refunds, captures), `payment_intent_write`
(confirm, cancel, capture), `customer_write`, `invoice_write`,
`subscription_write`, `product_write`, `plan_write`, `quote_write`,
`promotion_code_write`, `coupon_write`, `credit_note_write`,
`setup_intent_write`, `payment_method_write`, `top_up_write`,
`transfer_write`, `payout_write`, `dispute_write` (evidence and submission),
`review_write` (approve/refund), `customer_portal_write`, `tax_rate_write`,
`billing_clock_write`, `billing_meter_write`, `billing_meter_event_write`,
`file_write` (evidence uploads), `mandate_write`, plus picker-granted writes
for the same product areas as above. Connect platforms additionally grant the
connected-accounts write column for the resources they intend to manage on
connected accounts.

The app never assumes a set; the permission map learns what the key can do
and hides the rest with the message naming the missing permission.

## Sources

- `https://docs.stripe.com/keys/restricted-api-keys.md` — None/Read/Write, verb mapping, write implies read, error messages naming permissions
- `https://docs.stripe.com/keys.md` — RAKs recommended, agent keys, no IP restrictions (access policies)
- `https://docs.stripe.com/stripe-apps/reference/permissions.md` — documented object-permission names per resource
- `https://docs.stripe.com/stripe-apps/api-authentication/rak.md` — install links and pre-provisioned keys for Stripe Apps
- Pinned spec (release v2600): absence of key-management endpoints; per-resource operations behind each permission
