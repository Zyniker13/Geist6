# Coverage matrix

One row for every operation on every resource in [`api-inventory.md`](api-inventory.md) (built from the same pinned spec, API version 2026-10-28.endive). Tiers of support are defined in [ROADMAP.md](../../ROADMAP.md#tiers-of-support): tier 1 crafted screens, tier 2 generated structured views, tier 3 the API Explorer. The restricted-key permission column uses the names documented in Stripe's permissions reference; "unlisted" resources are granted through the Dashboard key picker, and the app probes access before showing a feature. Every write row is subject to the roadmap's Keys and Safety rules: an idempotency key, a confirmation that restates amount, currency, account, and mode for money-moving or irreversible actions, a visible live-mode marker, and an audit-log entry — and no write of any kind is sendable in Dashboard mode, which the client enforces. Regenerate with `swift run inventory gen`.

| Resource | Operation | HTTP | Path | Tier | Milestone | Screen or flow | Restricted-key permission |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Account | delete | DELETE | /v1/accounts/{account} | 1 | M2 | Account screens (M8); setup and account details (M2) | connected_account_read |
|  | retrieve | GET | /v1/account | 1 | M2 | Account screens (M8); setup and account details (M2) | connected_account_read |
|  | list | GET | /v1/accounts | 1 | M2 | Account screens (M8); setup and account details (M2) | connected_account_read |
|  | retrieve | GET | /v1/accounts/{account} | 1 | M2 | Account screens (M8); setup and account details (M2) | connected_account_read |
|  | capabilities | GET | /v1/accounts/{account}/capabilities | 1 | M2 | Account screens (M8); setup and account details (M2) | connected_account_read |
|  | persons | GET | /v1/accounts/{account}/persons | 1 | M2 | Account screens (M8); setup and account details (M2) | connected_account_read |
|  | create | POST | /v1/accounts | 1 | M2 | Account screens (M8); setup and account details (M2) | connected_account_read |
|  | update | POST | /v1/accounts/{account} | 1 | M2 | Account screens (M8); setup and account details (M2) | connected_account_read |
|  | reject | POST | /v1/accounts/{account}/reject | 1 | M2 | Account screens (M8); setup and account details (M2) | connected_account_read |
|  | unreject | POST | /v1/accounts/{account}/unreject | 1 | M2 | Account screens (M8); setup and account details (M2) | connected_account_read |
| AccountLink | create | POST | /v1/account_links | 2 | M8 | Generated list, detail, and edit views | account_link_write |
| AccountSession | create | POST | /v1/account_sessions | 2 | M8 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| ApplePayDomain | delete | DELETE | /v1/apple_pay/domains/{domain} | 2 | M10 | Generated list, detail, and edit views | apple_pay_domain_write |
|  | list | GET | /v1/apple_pay/domains | 2 | M10 | Generated list, detail, and edit views | apple_pay_domain_read |
|  | retrieve | GET | /v1/apple_pay/domains/{domain} | 2 | M10 | Generated list, detail, and edit views | apple_pay_domain_read |
|  | create | POST | /v1/apple_pay/domains | 2 | M10 | Generated list, detail, and edit views | apple_pay_domain_write |
| ApplicationFee | list | GET | /v1/application_fees | 2 | M8 | Generated list, detail, and edit views | application_fee_read |
|  | retrieve | GET | /v1/application_fees/{id} | 2 | M8 | Generated list, detail, and edit views | application_fee_read |
| Balance | retrieve | GET | /v1/balance | 1 | M3 | Home dashboard (M3) | balance_read |
| BalanceSettings | retrieve | GET | /v1/balance_settings | 2 | M7 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | update | POST | /v1/balance_settings | 2 | M7 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| BalanceTransaction | list | GET | /v1/balance_transactions | 1 | M4 | Payment timeline (M4); balances screens (M7); home metrics (M3) | balance_transaction_source_read |
|  | retrieve | GET | /v1/balance_transactions/{id} | 1 | M4 | Payment timeline (M4); balances screens (M7); home metrics (M3) | balance_transaction_source_read |
| BankAccount | delete | DELETE | /v1/accounts/{account}/external_accounts/{id} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | delete | DELETE | /v1/customers/{customer}/sources/{id} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | update | POST | /v1/accounts/{account}/external_accounts/{id} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | update | POST | /v1/customers/{customer}/sources/{id} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | verify | POST | /v1/customers/{customer}/sources/{id}/verify | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| Capability | list | GET | /v1/accounts/{account}/capabilities | 2 | M8 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | list | GET | /v1/accounts/{account}/capabilities | 2 | M8 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/accounts/{account}/capabilities/{capability} | 2 | M8 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/accounts/{account}/capabilities/{capability} | 2 | M8 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | update | POST | /v1/accounts/{account}/capabilities/{capability} | 2 | M8 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| Card | delete | DELETE | /v1/accounts/{account}/external_accounts/{id} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | delete | DELETE | /v1/customers/{customer}/sources/{id} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | update | POST | /v1/accounts/{account}/external_accounts/{id} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | update | POST | /v1/customers/{customer}/sources/{id} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| CashBalance | retrieve | GET | /v1/customers/{customer}/cash_balance | 2 | M7 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | update | POST | /v1/customers/{customer}/cash_balance | 2 | M7 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| Charge | list | GET | /v1/charges | 1 | M4 | Payments screens (M4) | charge_read |
|  | retrieve | GET | /v1/charges/{charge} | 1 | M4 | Payments screens (M4) | charge_read |
|  | search | GET | /v1/charges/search | 1 | M4 | Payments screens (M4) | charge_read |
|  | create | POST | /v1/charges | 1 | M4 | Payments screens (M4) | charge_write |
|  | update | POST | /v1/charges/{charge} | 1 | M4 | Payments screens (M4) | charge_write |
|  | capture | POST | /v1/charges/{charge}/capture | 1 | M4 | Payments screens (M4) | charge_write |
| ConfirmationToken | retrieve | GET | /v1/confirmation_tokens/{confirmation_token} | 2 | M4 | Generated list, detail, and edit views | confirmation_token_read |
|  | create | POST | /v1/test_helpers/confirmation_tokens | 2 | M4 | Generated list, detail, and edit views | confirmation_token_read |
| CountrySpec | list | GET | /v1/country_specs | 2 | M7 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/country_specs/{country} | 2 | M7 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| Coupon | delete | DELETE | /v1/coupons/{coupon} | 2 | M6 | Generated list, detail, and edit views | coupon_write |
|  | list | GET | /v1/coupons | 2 | M6 | Generated list, detail, and edit views | coupon_read |
|  | retrieve | GET | /v1/coupons/{coupon} | 2 | M6 | Generated list, detail, and edit views | coupon_read |
|  | create | POST | /v1/coupons | 2 | M6 | Generated list, detail, and edit views | coupon_write |
|  | update | POST | /v1/coupons/{coupon} | 2 | M6 | Generated list, detail, and edit views | coupon_write |
| CreditNote | list | GET | /v1/credit_notes | 2 | M6 | Generated list, detail, and edit views | credit_note_read |
|  | retrieve | GET | /v1/credit_notes/{id} | 2 | M6 | Generated list, detail, and edit views | credit_note_read |
|  | preview | GET | /v1/credit_notes/preview | 2 | M6 | Generated list, detail, and edit views | credit_note_read |
|  | preview_lines | GET | /v1/credit_notes/preview/lines | 2 | M6 | Generated list, detail, and edit views | credit_note_read |
|  | create | POST | /v1/credit_notes | 2 | M6 | Generated list, detail, and edit views | credit_note_write |
|  | update | POST | /v1/credit_notes/{id} | 2 | M6 | Generated list, detail, and edit views | credit_note_write |
|  | void_credit_note | POST | /v1/credit_notes/{id}/void | 2 | M6 | Generated list, detail, and edit views | credit_note_write |
| CreditNoteLineItem | list | GET | /v1/credit_notes/{credit_note}/lines | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | list | GET | /v1/credit_notes/{credit_note}/lines | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| Customer | delete | DELETE | /v1/customers/{customer} | 1 | M5 | Customers screens (M5); home metrics (M3) | customer_write |
|  | delete_discount | DELETE | /v1/customers/{customer}/discount | 1 | M5 | Customers screens (M5); home metrics (M3) | customer_write |
|  | list | GET | /v1/customers | 1 | M5 | Customers screens (M5); home metrics (M3) | customer_read |
|  | retrieve | GET | /v1/customers/{customer} | 1 | M5 | Customers screens (M5); home metrics (M3) | customer_read |
|  | balance_transactions | GET | /v1/customers/{customer}/balance_transactions | 1 | M5 | Customers screens (M5); home metrics (M3) | customer_read |
|  | list_payment_methods | GET | /v1/customers/{customer}/payment_methods | 1 | M5 | Customers screens (M5); home metrics (M3) | customer_read |
|  | retrieve_payment_method | GET | /v1/customers/{customer}/payment_methods/{payment_method} | 1 | M5 | Customers screens (M5); home metrics (M3) | customer_read |
|  | search | GET | /v1/customers/search | 1 | M5 | Customers screens (M5); home metrics (M3) | customer_read |
|  | create | POST | /v1/customers | 1 | M5 | Customers screens (M5); home metrics (M3) | customer_write |
|  | update | POST | /v1/customers/{customer} | 1 | M5 | Customers screens (M5); home metrics (M3) | customer_write |
|  | create_funding_instructions | POST | /v1/customers/{customer}/funding_instructions | 1 | M5 | Customers screens (M5); home metrics (M3) | customer_write |
|  | fund_cash_balance | POST | /v1/test_helpers/customers/{customer}/fund_cash_balance | 1 | M5 | Customers screens (M5); home metrics (M3) | customer_write |
| CustomerBalanceTransaction | list | GET | /v1/customers/{customer}/balance_transactions | 2 | M5 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | list | GET | /v1/customers/{customer}/balance_transactions | 2 | M5 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/customers/{customer}/balance_transactions/{transaction} | 2 | M5 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/customers/{customer}/balance_transactions/{transaction} | 2 | M5 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | create | POST | /v1/customers/{customer}/balance_transactions | 2 | M5 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | create | POST | /v1/customers/{customer}/balance_transactions | 2 | M5 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | update | POST | /v1/customers/{customer}/balance_transactions/{transaction} | 2 | M5 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| CustomerCashBalanceTransaction | list | GET | /v1/customers/{customer}/cash_balance_transactions | 2 | M5 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | list | GET | /v1/customers/{customer}/cash_balance_transactions | 2 | M5 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/customers/{customer}/cash_balance_transactions/{transaction} | 2 | M5 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/customers/{customer}/cash_balance_transactions/{transaction} | 2 | M5 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| CustomerSession | create | POST | /v1/customer_sessions | 2 | M6 | Generated list, detail, and edit views | customer_session_write |
| Dispute | list | GET | /v1/disputes | 2 | M10 | Generated list, detail, and edit views | dispute_read |
|  | retrieve | GET | /v1/disputes/{dispute} | 2 | M10 | Generated list, detail, and edit views | dispute_read |
|  | update | POST | /v1/disputes/{dispute} | 2 | M10 | Generated list, detail, and edit views | dispute_write |
|  | close | POST | /v1/disputes/{dispute}/close | 2 | M10 | Generated list, detail, and edit views | dispute_write |
| EphemeralKey | delete | DELETE | /v1/ephemeral_keys/{key} | 3 | M10 | API Explorer | unlisted (Dashboard key picker) |
|  | create | POST | /v1/ephemeral_keys | 3 | M10 | API Explorer | unlisted (Dashboard key picker) |
| Event | list | GET | /v1/events | 1 | M3 | Activity feed (M3; full filters M11) | event_read |
|  | retrieve | GET | /v1/events/{id} | 1 | M3 | Activity feed (M3; full filters M11) | event_read |
| ExchangeRate | list | GET | /v1/exchange_rates | 2 | M7 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/exchange_rates/{rate_id} | 2 | M7 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| ExternalAccount | delete | DELETE | /v1/accounts/{account}/external_accounts/{id} | 2 | M8 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | list | GET | /v1/accounts/{account}/external_accounts | 2 | M8 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | list | GET | /v1/accounts/{account}/external_accounts | 2 | M8 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/accounts/{account}/external_accounts/{id} | 2 | M8 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/accounts/{account}/external_accounts/{id} | 2 | M8 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | create | POST | /v1/accounts/{account}/external_accounts | 2 | M8 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | create | POST | /v1/accounts/{account}/external_accounts | 2 | M8 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | update | POST | /v1/accounts/{account}/external_accounts/{id} | 2 | M8 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| FeeRefund | retrieve | GET | /v1/application_fees/{fee}/refunds/{id} | 2 | M8 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/application_fees/{fee}/refunds/{id} | 2 | M8 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | list | GET | /v1/application_fees/{id}/refunds | 2 | M8 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | list | GET | /v1/application_fees/{id}/refunds | 2 | M8 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | update | POST | /v1/application_fees/{fee}/refunds/{id} | 2 | M8 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | create | POST | /v1/application_fees/{id}/refunds | 2 | M8 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | create | POST | /v1/application_fees/{id}/refunds | 2 | M8 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| File | list | GET | /v1/files | 2 | M10 | Generated list, detail, and edit views | file_read |
|  | retrieve | GET | /v1/files/{file} | 2 | M10 | Generated list, detail, and edit views | file_read |
|  | create | POST | /v1/files | 2 | M10 | Generated list, detail, and edit views | file_write |
| FileLink | list | GET | /v1/file_links | 2 | M10 | Generated list, detail, and edit views | file_read |
|  | retrieve | GET | /v1/file_links/{link} | 2 | M10 | Generated list, detail, and edit views | file_read |
|  | create | POST | /v1/file_links | 2 | M10 | Generated list, detail, and edit views | file_write |
|  | update | POST | /v1/file_links/{link} | 2 | M10 | Generated list, detail, and edit views | file_write |
| Invoice | delete | DELETE | /v1/invoices/{invoice} | 1 | M6 | Billing screens (M6) | invoice_write |
|  | list | GET | /v1/invoices | 1 | M6 | Billing screens (M6) | invoice_read |
|  | retrieve | GET | /v1/invoices/{invoice} | 1 | M6 | Billing screens (M6) | invoice_read |
|  | search | GET | /v1/invoices/search | 1 | M6 | Billing screens (M6) | invoice_read |
|  | create | POST | /v1/invoices | 1 | M6 | Billing screens (M6) | invoice_write |
|  | update | POST | /v1/invoices/{invoice} | 1 | M6 | Billing screens (M6) | invoice_write |
|  | add_lines | POST | /v1/invoices/{invoice}/add_lines | 1 | M6 | Billing screens (M6) | invoice_write |
|  | attach_payment | POST | /v1/invoices/{invoice}/attach_payment | 1 | M6 | Billing screens (M6) | invoice_write |
|  | finalize_invoice | POST | /v1/invoices/{invoice}/finalize | 1 | M6 | Billing screens (M6) | invoice_write |
|  | mark_uncollectible | POST | /v1/invoices/{invoice}/mark_uncollectible | 1 | M6 | Billing screens (M6) | invoice_write |
|  | pay | POST | /v1/invoices/{invoice}/pay | 1 | M6 | Billing screens (M6) | invoice_write |
|  | remove_lines | POST | /v1/invoices/{invoice}/remove_lines | 1 | M6 | Billing screens (M6) | invoice_write |
|  | send_invoice | POST | /v1/invoices/{invoice}/send | 1 | M6 | Billing screens (M6) | invoice_write |
|  | update_lines | POST | /v1/invoices/{invoice}/update_lines | 1 | M6 | Billing screens (M6) | invoice_write |
|  | void_invoice | POST | /v1/invoices/{invoice}/void | 1 | M6 | Billing screens (M6) | invoice_write |
|  | create_preview | POST | /v1/invoices/create_preview | 1 | M6 | Billing screens (M6) | invoice_write |
| InvoiceItem | delete | DELETE | /v1/invoiceitems/{invoiceitem} | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | list | GET | /v1/invoiceitems | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/invoiceitems/{invoiceitem} | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | create | POST | /v1/invoiceitems | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | update | POST | /v1/invoiceitems/{invoiceitem} | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| InvoiceLineItem | list | GET | /v1/invoices/{invoice}/lines | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | list | GET | /v1/invoices/{invoice}/lines | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | update | POST | /v1/invoices/{invoice}/lines/{line_item_id} | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| InvoicePayment | list | GET | /v1/invoice_payments | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/invoice_payments/{invoice_payment} | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| InvoiceRenderingTemplate | list | GET | /v1/invoice_rendering_templates | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/invoice_rendering_templates/{template} | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | archive | POST | /v1/invoice_rendering_templates/{template}/archive | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | unarchive | POST | /v1/invoice_rendering_templates/{template}/unarchive | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| LoginLink | create | POST | /v1/accounts/{account}/login_links | 2 | M8 | Generated list, detail, and edit views | edit_link_write |
| Mandate | retrieve | GET | /v1/mandates/{mandate} | 2 | M4 | Generated list, detail, and edit views | mandate_read |
| PaymentAttemptRecord | list | GET | /v1/payment_attempt_records | 2 | M10 | Generated list, detail, and edit views | payment_records_read |
|  | retrieve | GET | /v1/payment_attempt_records/{id} | 2 | M10 | Generated list, detail, and edit views | payment_records_read |
| PaymentIntent | list | GET | /v1/payment_intents | 1 | M4 | Payments screens (M4) | payment_intent_read |
|  | retrieve | GET | /v1/payment_intents/{intent} | 1 | M4 | Payments screens (M4) | payment_intent_read |
|  | search | GET | /v1/payment_intents/search | 1 | M4 | Payments screens (M4) | payment_intent_read |
|  | create | POST | /v1/payment_intents | 1 | M4 | Payments screens (M4) | payment_intent_write |
|  | update | POST | /v1/payment_intents/{intent} | 1 | M4 | Payments screens (M4) | payment_intent_write |
|  | apply_customer_balance | POST | /v1/payment_intents/{intent}/apply_customer_balance | 1 | M4 | Payments screens (M4) | payment_intent_write |
|  | cancel | POST | /v1/payment_intents/{intent}/cancel | 1 | M4 | Payments screens (M4) | payment_intent_write |
|  | capture | POST | /v1/payment_intents/{intent}/capture | 1 | M4 | Payments screens (M4) | payment_intent_write |
|  | confirm | POST | /v1/payment_intents/{intent}/confirm | 1 | M4 | Payments screens (M4) | payment_intent_write |
|  | increment_authorization | POST | /v1/payment_intents/{intent}/increment_authorization | 1 | M4 | Payments screens (M4) | payment_intent_write |
|  | verify_microdeposits | POST | /v1/payment_intents/{intent}/verify_microdeposits | 1 | M4 | Payments screens (M4) | payment_intent_write |
| PaymentIntentAmountDetailsLineItem | list | GET | /v1/payment_intents/{intent}/amount_details_line_items | 2 | M4 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| PaymentLink | list | GET | /v1/payment_links | 1 | M4 | Payments screens (M4) | payment_links_read |
|  | retrieve | GET | /v1/payment_links/{payment_link} | 1 | M4 | Payments screens (M4) | payment_links_read |
|  | list_line_items | GET | /v1/payment_links/{payment_link}/line_items | 1 | M4 | Payments screens (M4) | payment_links_read |
|  | create | POST | /v1/payment_links | 1 | M4 | Payments screens (M4) | payment_links_write |
|  | update | POST | /v1/payment_links/{payment_link} | 1 | M4 | Payments screens (M4) | payment_links_write |
| PaymentMethod | list | GET | /v1/payment_methods | 1 | M4 | Payments screens (M4); customer payment methods (M5) | payment_method_read |
|  | retrieve | GET | /v1/payment_methods/{payment_method} | 1 | M4 | Payments screens (M4); customer payment methods (M5) | payment_method_read |
|  | create | POST | /v1/payment_methods | 1 | M4 | Payments screens (M4); customer payment methods (M5) | payment_method_write |
|  | update | POST | /v1/payment_methods/{payment_method} | 1 | M4 | Payments screens (M4); customer payment methods (M5) | payment_method_write |
|  | attach | POST | /v1/payment_methods/{payment_method}/attach | 1 | M4 | Payments screens (M4); customer payment methods (M5) | payment_method_write |
|  | detach | POST | /v1/payment_methods/{payment_method}/detach | 1 | M4 | Payments screens (M4); customer payment methods (M5) | payment_method_write |
| PaymentMethodConfiguration | list | GET | /v1/payment_method_configurations | 2 | M10 | Generated list, detail, and edit views | payment_method_configurations_read |
|  | retrieve | GET | /v1/payment_method_configurations/{configuration} | 2 | M10 | Generated list, detail, and edit views | payment_method_configurations_read |
|  | create | POST | /v1/payment_method_configurations | 2 | M10 | Generated list, detail, and edit views | payment_method_configurations_write |
|  | update | POST | /v1/payment_method_configurations/{configuration} | 2 | M10 | Generated list, detail, and edit views | payment_method_configurations_write |
| PaymentMethodDomain | list | GET | /v1/payment_method_domains | 2 | M10 | Generated list, detail, and edit views | payment_method_domain_read |
|  | retrieve | GET | /v1/payment_method_domains/{payment_method_domain} | 2 | M10 | Generated list, detail, and edit views | payment_method_domain_read |
|  | create | POST | /v1/payment_method_domains | 2 | M10 | Generated list, detail, and edit views | payment_method_domain_write |
|  | update | POST | /v1/payment_method_domains/{payment_method_domain} | 2 | M10 | Generated list, detail, and edit views | payment_method_domain_write |
|  | validate | POST | /v1/payment_method_domains/{payment_method_domain}/validate | 2 | M10 | Generated list, detail, and edit views | payment_method_domain_write |
| PaymentRecord | list | GET | /v1/payment_records | 2 | M10 | Generated list, detail, and edit views | payment_records_read |
|  | retrieve | GET | /v1/payment_records/{id} | 2 | M10 | Generated list, detail, and edit views | payment_records_read |
|  | report_payment_attempt | POST | /v1/payment_records/{id}/report_payment_attempt | 2 | M10 | Generated list, detail, and edit views | payment_records_write |
|  | report_payment_attempt_canceled | POST | /v1/payment_records/{id}/report_payment_attempt_canceled | 2 | M10 | Generated list, detail, and edit views | payment_records_write |
|  | report_payment_attempt_failed | POST | /v1/payment_records/{id}/report_payment_attempt_failed | 2 | M10 | Generated list, detail, and edit views | payment_records_write |
|  | report_payment_attempt_guaranteed | POST | /v1/payment_records/{id}/report_payment_attempt_guaranteed | 2 | M10 | Generated list, detail, and edit views | payment_records_write |
|  | report_payment_attempt_informational | POST | /v1/payment_records/{id}/report_payment_attempt_informational | 2 | M10 | Generated list, detail, and edit views | payment_records_write |
|  | report_refund | POST | /v1/payment_records/{id}/report_refund | 2 | M10 | Generated list, detail, and edit views | payment_records_write |
|  | report_payment | POST | /v1/payment_records/report_payment | 2 | M10 | Generated list, detail, and edit views | payment_records_write |
| PaymentSource | list | GET | /v1/customers/{customer}/sources | 2 | M5 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | list | GET | /v1/customers/{customer}/sources | 2 | M5 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/customers/{customer}/sources/{id} | 2 | M5 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/customers/{customer}/sources/{id} | 2 | M5 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | create | POST | /v1/customers/{customer}/sources | 2 | M5 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | create | POST | /v1/customers/{customer}/sources | 2 | M5 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| Payout | list | GET | /v1/payouts | 1 | M7 | Payouts screens (M7) | payout_read |
|  | retrieve | GET | /v1/payouts/{payout} | 1 | M7 | Payouts screens (M7) | payout_read |
|  | create | POST | /v1/payouts | 1 | M7 | Payouts screens (M7) | payout_write |
|  | update | POST | /v1/payouts/{payout} | 1 | M7 | Payouts screens (M7) | payout_write |
|  | cancel | POST | /v1/payouts/{payout}/cancel | 1 | M7 | Payouts screens (M7) | payout_write |
|  | reverse | POST | /v1/payouts/{payout}/reverse | 1 | M7 | Payouts screens (M7) | payout_write |
| Person | delete | DELETE | /v1/accounts/{account}/persons/{person} | 2 | M8 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | list | GET | /v1/accounts/{account}/persons | 2 | M8 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | list | GET | /v1/accounts/{account}/persons | 2 | M8 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/accounts/{account}/persons/{person} | 2 | M8 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/accounts/{account}/persons/{person} | 2 | M8 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | create | POST | /v1/accounts/{account}/persons | 2 | M8 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | create | POST | /v1/accounts/{account}/persons | 2 | M8 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | update | POST | /v1/accounts/{account}/persons/{person} | 2 | M8 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| Plan | delete | DELETE | /v1/plans/{plan} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | list | GET | /v1/plans | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/plans/{plan} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | create | POST | /v1/plans | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | update | POST | /v1/plans/{plan} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| Price | list | GET | /v1/prices | 1 | M6 | Catalog screens (M6) | plan_read |
|  | retrieve | GET | /v1/prices/{price} | 1 | M6 | Catalog screens (M6) | plan_read |
|  | search | GET | /v1/prices/search | 1 | M6 | Catalog screens (M6) | plan_read |
|  | create | POST | /v1/prices | 1 | M6 | Catalog screens (M6) | plan_write |
|  | update | POST | /v1/prices/{price} | 1 | M6 | Catalog screens (M6) | plan_write |
| Product | delete | DELETE | /v1/products/{id} | 1 | M6 | Catalog screens (M6) | product_write |
|  | list | GET | /v1/products | 1 | M6 | Catalog screens (M6) | product_read |
|  | retrieve | GET | /v1/products/{id} | 1 | M6 | Catalog screens (M6) | product_read |
|  | search | GET | /v1/products/search | 1 | M6 | Catalog screens (M6) | product_read |
|  | create | POST | /v1/products | 1 | M6 | Catalog screens (M6) | product_write |
|  | update | POST | /v1/products/{id} | 1 | M6 | Catalog screens (M6) | product_write |
| ProductFeature | delete | DELETE | /v1/products/{product}/features/{id} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | list | GET | /v1/products/{product}/features | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/products/{product}/features/{id} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | create | POST | /v1/products/{product}/features | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| PromotionCode | list | GET | /v1/promotion_codes | 2 | M6 | Generated list, detail, and edit views | promotion_code_read |
|  | retrieve | GET | /v1/promotion_codes/{promotion_code} | 2 | M6 | Generated list, detail, and edit views | promotion_code_read |
|  | create | POST | /v1/promotion_codes | 2 | M6 | Generated list, detail, and edit views | promotion_code_write |
|  | update | POST | /v1/promotion_codes/{promotion_code} | 2 | M6 | Generated list, detail, and edit views | promotion_code_write |
| Quote | list | GET | /v1/quotes | 2 | M6 | Generated list, detail, and edit views | quote_read |
|  | retrieve | GET | /v1/quotes/{quote} | 2 | M6 | Generated list, detail, and edit views | quote_read |
|  | list_computed_upfront_line_items | GET | /v1/quotes/{quote}/computed_upfront_line_items | 2 | M6 | Generated list, detail, and edit views | quote_read |
|  | list_line_items | GET | /v1/quotes/{quote}/line_items | 2 | M6 | Generated list, detail, and edit views | quote_read |
|  | create | POST | /v1/quotes | 2 | M6 | Generated list, detail, and edit views | quote_write |
|  | update | POST | /v1/quotes/{quote} | 2 | M6 | Generated list, detail, and edit views | quote_write |
|  | accept | POST | /v1/quotes/{quote}/accept | 2 | M6 | Generated list, detail, and edit views | quote_write |
|  | cancel | POST | /v1/quotes/{quote}/cancel | 2 | M6 | Generated list, detail, and edit views | quote_write |
|  | finalize_quote | POST | /v1/quotes/{quote}/finalize | 2 | M6 | Generated list, detail, and edit views | quote_write |
|  | pdf | GET | /v1/quotes/{quote}/pdf | 2 | M6 | Generated list, detail, and edit views | quote_read |
| Refund | list | GET | /v1/charges/{charge}/refunds | 1 | M4 | Payments screens (M4) | charge_read |
|  | retrieve | GET | /v1/charges/{charge}/refunds/{refund} | 1 | M4 | Payments screens (M4) | charge_read |
|  | list | GET | /v1/refunds | 1 | M4 | Payments screens (M4) | charge_read |
|  | retrieve | GET | /v1/refunds/{refund} | 1 | M4 | Payments screens (M4) | charge_read |
|  | create | POST | /v1/refunds | 1 | M4 | Payments screens (M4) | charge_write |
|  | update | POST | /v1/refunds/{refund} | 1 | M4 | Payments screens (M4) | charge_write |
|  | cancel | POST | /v1/refunds/{refund}/cancel | 1 | M4 | Payments screens (M4) | charge_write |
|  | expire | POST | /v1/test_helpers/refunds/{refund}/expire | 1 | M4 | Payments screens (M4) | charge_write |
| Review | list | GET | /v1/reviews | 2 | M9 | Generated list, detail, and edit views | review_read |
|  | retrieve | GET | /v1/reviews/{review} | 2 | M9 | Generated list, detail, and edit views | review_read |
|  | approve | POST | /v1/reviews/{review}/approve | 2 | M9 | Generated list, detail, and edit views | review_write |
| SetupAttempt | list | GET | /v1/setup_attempts | 3 | M10 | API Explorer | unlisted (Dashboard key picker) |
| SetupIntent | list | GET | /v1/setup_intents | 1 | M4 | Payments screens (M4) | setup_intent_read |
|  | retrieve | GET | /v1/setup_intents/{intent} | 1 | M4 | Payments screens (M4) | setup_intent_read |
|  | create | POST | /v1/setup_intents | 1 | M4 | Payments screens (M4) | setup_intent_write |
|  | update | POST | /v1/setup_intents/{intent} | 1 | M4 | Payments screens (M4) | setup_intent_write |
|  | cancel | POST | /v1/setup_intents/{intent}/cancel | 1 | M4 | Payments screens (M4) | setup_intent_write |
|  | confirm | POST | /v1/setup_intents/{intent}/confirm | 1 | M4 | Payments screens (M4) | setup_intent_write |
|  | verify_microdeposits | POST | /v1/setup_intents/{intent}/verify_microdeposits | 1 | M4 | Payments screens (M4) | setup_intent_write |
| ShippingRate | list | GET | /v1/shipping_rates | 2 | M10 | Generated list, detail, and edit views | shipping_rate_read |
|  | retrieve | GET | /v1/shipping_rates/{shipping_rate_token} | 2 | M10 | Generated list, detail, and edit views | shipping_rate_read |
|  | create | POST | /v1/shipping_rates | 2 | M10 | Generated list, detail, and edit views | shipping_rate_write |
|  | update | POST | /v1/shipping_rates/{shipping_rate_token} | 2 | M10 | Generated list, detail, and edit views | shipping_rate_write |
| Source | detach | DELETE | /v1/customers/{customer}/sources/{id} | 3 | M10 | API Explorer | source_write |
|  | retrieve | GET | /v1/sources/{source} | 3 | M10 | API Explorer | source_read |
|  | source_transactions | GET | /v1/sources/{source}/source_transactions | 3 | M10 | API Explorer | source_read |
|  | create | POST | /v1/sources | 3 | M10 | API Explorer | source_write |
|  | update | POST | /v1/sources/{source} | 3 | M10 | API Explorer | source_write |
|  | verify | POST | /v1/sources/{source}/verify | 3 | M10 | API Explorer | source_write |
| Subscription | cancel | DELETE | /v1/subscriptions/{subscription_exposed_id} | 1 | M6 | Billing screens (M6) | subscription_write |
|  | delete_discount | DELETE | /v1/subscriptions/{subscription_exposed_id}/discount | 1 | M6 | Billing screens (M6) | subscription_write |
|  | list | GET | /v1/subscriptions | 1 | M6 | Billing screens (M6) | subscription_read |
|  | retrieve | GET | /v1/subscriptions/{subscription_exposed_id} | 1 | M6 | Billing screens (M6) | subscription_read |
|  | search | GET | /v1/subscriptions/search | 1 | M6 | Billing screens (M6) | subscription_read |
|  | create | POST | /v1/subscriptions | 1 | M6 | Billing screens (M6) | subscription_write |
|  | migrate | POST | /v1/subscriptions/{subscription}/migrate | 1 | M6 | Billing screens (M6) | subscription_write |
|  | pause | POST | /v1/subscriptions/{subscription}/pause | 1 | M6 | Billing screens (M6) | subscription_write |
|  | resume | POST | /v1/subscriptions/{subscription}/resume | 1 | M6 | Billing screens (M6) | subscription_write |
|  | update | POST | /v1/subscriptions/{subscription_exposed_id} | 1 | M6 | Billing screens (M6) | subscription_write |
| SubscriptionItem | delete | DELETE | /v1/subscription_items/{item} | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | list | GET | /v1/subscription_items | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/subscription_items/{item} | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | create | POST | /v1/subscription_items | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | update | POST | /v1/subscription_items/{item} | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| SubscriptionSchedule | list | GET | /v1/subscription_schedules | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/subscription_schedules/{schedule} | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | create | POST | /v1/subscription_schedules | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | update | POST | /v1/subscription_schedules/{schedule} | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | cancel | POST | /v1/subscription_schedules/{schedule}/cancel | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | release | POST | /v1/subscription_schedules/{schedule}/release | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| TaxCode | list | GET | /v1/tax_codes | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/tax_codes/{id} | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| TaxId | delete | DELETE | /v1/customers/{customer}/tax_ids/{id} | 2 | M5 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | delete | DELETE | /v1/tax_ids/{id} | 2 | M5 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | list | GET | /v1/customers/{customer}/tax_ids | 2 | M5 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | list | GET | /v1/customers/{customer}/tax_ids | 2 | M5 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/customers/{customer}/tax_ids/{id} | 2 | M5 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/customers/{customer}/tax_ids/{id} | 2 | M5 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | list | GET | /v1/tax_ids | 2 | M5 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/tax_ids/{id} | 2 | M5 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | create | POST | /v1/customers/{customer}/tax_ids | 2 | M5 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | create | POST | /v1/customers/{customer}/tax_ids | 2 | M5 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | create | POST | /v1/tax_ids | 2 | M5 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| TaxRate | list | GET | /v1/tax_rates | 2 | M6 | Generated list, detail, and edit views | tax_rate_read |
|  | retrieve | GET | /v1/tax_rates/{tax_rate} | 2 | M6 | Generated list, detail, and edit views | tax_rate_read |
|  | create | POST | /v1/tax_rates | 2 | M6 | Generated list, detail, and edit views | tax_rate_write |
|  | update | POST | /v1/tax_rates/{tax_rate} | 2 | M6 | Generated list, detail, and edit views | tax_rate_write |
| Token | retrieve | GET | /v1/tokens/{token} | 3 | M10 | API Explorer | token_read |
|  | create | POST | /v1/tokens | 3 | M10 | API Explorer | token_write |
| Topup | list | GET | /v1/topups | 2 | M7 | Generated list, detail, and edit views | top_up_read |
|  | retrieve | GET | /v1/topups/{topup} | 2 | M7 | Generated list, detail, and edit views | top_up_read |
|  | create | POST | /v1/topups | 2 | M7 | Generated list, detail, and edit views | top_up_write |
|  | update | POST | /v1/topups/{topup} | 2 | M7 | Generated list, detail, and edit views | top_up_write |
|  | cancel | POST | /v1/topups/{topup}/cancel | 2 | M7 | Generated list, detail, and edit views | top_up_write |
| Transfer | list | GET | /v1/transfers | 2 | M7 | Generated list, detail, and edit views | transfer_read |
|  | retrieve | GET | /v1/transfers/{transfer} | 2 | M7 | Generated list, detail, and edit views | transfer_read |
|  | create | POST | /v1/transfers | 2 | M7 | Generated list, detail, and edit views | transfer_write |
|  | update | POST | /v1/transfers/{transfer} | 2 | M7 | Generated list, detail, and edit views | transfer_write |
| TransferReversal | list | GET | /v1/transfers/{id}/reversals | 2 | M7 | Generated list, detail, and edit views | transfer_read |
|  | list | GET | /v1/transfers/{id}/reversals | 2 | M7 | Generated list, detail, and edit views | transfer_read |
|  | retrieve | GET | /v1/transfers/{transfer}/reversals/{id} | 2 | M7 | Generated list, detail, and edit views | transfer_read |
|  | retrieve | GET | /v1/transfers/{transfer}/reversals/{id} | 2 | M7 | Generated list, detail, and edit views | transfer_read |
|  | create | POST | /v1/transfers/{id}/reversals | 2 | M7 | Generated list, detail, and edit views | transfer_write |
|  | create | POST | /v1/transfers/{id}/reversals | 2 | M7 | Generated list, detail, and edit views | transfer_write |
|  | update | POST | /v1/transfers/{transfer}/reversals/{id} | 2 | M7 | Generated list, detail, and edit views | transfer_write |
| WebhookEndpoint | delete | DELETE | /v1/webhook_endpoints/{webhook_endpoint} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | list | GET | /v1/webhook_endpoints | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/webhook_endpoints/{webhook_endpoint} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | create | POST | /v1/webhook_endpoints | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | update | POST | /v1/webhook_endpoints/{webhook_endpoint} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| Install | list | GET | /v1/apps/installs | 3 | M10 | API Explorer | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/apps/installs/{id} | 3 | M10 | API Explorer | unlisted (Dashboard key picker) |
|  | create | POST | /v1/apps/installs | 3 | M10 | API Explorer | unlisted (Dashboard key picker) |
|  | update | POST | /v1/apps/installs/{id} | 3 | M10 | API Explorer | unlisted (Dashboard key picker) |
|  | uninstall | POST | /v1/apps/installs/{id}/uninstall | 3 | M10 | API Explorer | unlisted (Dashboard key picker) |
| Secret | list | GET | /v1/apps/secrets | 3 | M10 | API Explorer | unlisted (Dashboard key picker) |
|  | find | GET | /v1/apps/secrets/find | 3 | M10 | API Explorer | unlisted (Dashboard key picker) |
|  | create | POST | /v1/apps/secrets | 3 | M10 | API Explorer | unlisted (Dashboard key picker) |
|  | delete_where | POST | /v1/apps/secrets/delete | 3 | M10 | API Explorer | unlisted (Dashboard key picker) |
| Alert | list | GET | /v1/billing/alerts | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/billing/alerts/{id} | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | create | POST | /v1/billing/alerts | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | activate | POST | /v1/billing/alerts/{id}/activate | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | archive | POST | /v1/billing/alerts/{id}/archive | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | deactivate | POST | /v1/billing/alerts/{id}/deactivate | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| CreditBalanceSummary | retrieve | GET | /v1/billing/credit_balance_summary | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| CreditBalanceTransaction | list | GET | /v1/billing/credit_balance_transactions | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/billing/credit_balance_transactions/{id} | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| CreditGrant | list | GET | /v1/billing/credit_grants | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/billing/credit_grants/{id} | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | create | POST | /v1/billing/credit_grants | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | update | POST | /v1/billing/credit_grants/{id} | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | expire | POST | /v1/billing/credit_grants/{id}/expire | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | void_grant | POST | /v1/billing/credit_grants/{id}/void | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| FeedbackOption | list | GET | /v1/billing/feedback_options | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/billing/feedback_options/{id} | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | create | POST | /v1/billing/feedback_options | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | update | POST | /v1/billing/feedback_options/{id} | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | deactivate | POST | /v1/billing/feedback_options/{id}/deactivate | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| Meter | list | GET | /v1/billing/meters | 2 | M6 | Generated list, detail, and edit views | billing_meter_read |
|  | retrieve | GET | /v1/billing/meters/{id} | 2 | M6 | Generated list, detail, and edit views | billing_meter_read |
|  | create | POST | /v1/billing/meters | 2 | M6 | Generated list, detail, and edit views | billing_meter_write |
|  | update | POST | /v1/billing/meters/{id} | 2 | M6 | Generated list, detail, and edit views | billing_meter_write |
|  | deactivate | POST | /v1/billing/meters/{id}/deactivate | 2 | M6 | Generated list, detail, and edit views | billing_meter_write |
|  | reactivate | POST | /v1/billing/meters/{id}/reactivate | 2 | M6 | Generated list, detail, and edit views | billing_meter_write |
| MeterEvent | create | POST | /v1/billing/meter_events | 2 | M6 | Generated list, detail, and edit views | billing_meter_event_write |
| MeterEventAdjustment | create | POST | /v1/billing/meter_event_adjustments | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| MeterEventSummary | list | GET | /v1/billing/meters/{id}/event_summaries | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| Configuration | list | GET | /v1/billing_portal/configurations | 2 | M6 | Generated list, detail, and edit views | customer_portal_read |
|  | retrieve | GET | /v1/billing_portal/configurations/{configuration} | 2 | M6 | Generated list, detail, and edit views | customer_portal_read |
|  | create | POST | /v1/billing_portal/configurations | 2 | M6 | Generated list, detail, and edit views | customer_portal_write |
|  | update | POST | /v1/billing_portal/configurations/{configuration} | 2 | M6 | Generated list, detail, and edit views | customer_portal_write |
| Session | create | POST | /v1/billing_portal/sessions | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| Session | list | GET | /v1/checkout/sessions | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/checkout/sessions/{session} | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | list_line_items | GET | /v1/checkout/sessions/{session}/line_items | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | create | POST | /v1/checkout/sessions | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | update | POST | /v1/checkout/sessions/{session} | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | expire | POST | /v1/checkout/sessions/{session}/expire | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| Order | list | GET | /v1/climate/orders | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/climate/orders/{order} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | create | POST | /v1/climate/orders | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | update | POST | /v1/climate/orders/{order} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | cancel | POST | /v1/climate/orders/{order}/cancel | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| Product | list | GET | /v1/climate/products | 1 | M6 | Catalog screens (M6) | product_read |
|  | retrieve | GET | /v1/climate/products/{product} | 1 | M6 | Catalog screens (M6) | product_read |
| Supplier | list | GET | /v1/climate/suppliers | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/climate/suppliers/{supplier} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| ActiveEntitlement | list | GET | /v1/entitlements/active_entitlements | 2 | M10 | Generated list, detail, and edit views | entitlement_read |
|  | retrieve | GET | /v1/entitlements/active_entitlements/{id} | 2 | M10 | Generated list, detail, and edit views | entitlement_read |
| Feature | list | GET | /v1/entitlements/features | 2 | M10 | Generated list, detail, and edit views | entitlement_read |
|  | retrieve | GET | /v1/entitlements/features/{id} | 2 | M10 | Generated list, detail, and edit views | entitlement_read |
|  | create | POST | /v1/entitlements/features | 2 | M10 | Generated list, detail, and edit views | entitlement_read |
|  | update | POST | /v1/entitlements/features/{id} | 2 | M10 | Generated list, detail, and edit views | entitlement_read |
| Account | list | GET | /v1/financial_connections/accounts | 1 | M2 | Account screens (M8); setup and account details (M2) | connected_account_read |
|  | retrieve | GET | /v1/financial_connections/accounts/{account} | 1 | M2 | Account screens (M8); setup and account details (M2) | connected_account_read |
|  | list_owners | GET | /v1/financial_connections/accounts/{account}/owners | 1 | M2 | Account screens (M8); setup and account details (M2) | connected_account_read |
|  | disconnect | POST | /v1/financial_connections/accounts/{account}/disconnect | 1 | M2 | Account screens (M8); setup and account details (M2) | connected_account_read |
|  | refresh | POST | /v1/financial_connections/accounts/{account}/refresh | 1 | M2 | Account screens (M8); setup and account details (M2) | connected_account_read |
|  | subscribe | POST | /v1/financial_connections/accounts/{account}/subscribe | 1 | M2 | Account screens (M8); setup and account details (M2) | connected_account_read |
|  | unsubscribe | POST | /v1/financial_connections/accounts/{account}/unsubscribe | 1 | M2 | Account screens (M8); setup and account details (M2) | connected_account_read |
| Session | retrieve | GET | /v1/financial_connections/sessions/{session} | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | create | POST | /v1/financial_connections/sessions | 2 | M6 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| Transaction | list | GET | /v1/financial_connections/transactions | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/financial_connections/transactions/{transaction} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| Request | list | GET | /v1/forwarding/requests | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/forwarding/requests/{id} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | create | POST | /v1/forwarding/requests | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| VerificationReport | list | GET | /v1/identity/verification_reports | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/identity/verification_reports/{report} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| VerificationSession | list | GET | /v1/identity/verification_sessions | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/identity/verification_sessions/{session} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | create | POST | /v1/identity/verification_sessions | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | update | POST | /v1/identity/verification_sessions/{session} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | cancel | POST | /v1/identity/verification_sessions/{session}/cancel | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | redact | POST | /v1/identity/verification_sessions/{session}/redact | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| Authorization | list | GET | /v1/issuing/authorizations | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/issuing/authorizations/{authorization} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | update | POST | /v1/issuing/authorizations/{authorization} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | approve | POST | /v1/issuing/authorizations/{authorization}/approve | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | decline | POST | /v1/issuing/authorizations/{authorization}/decline | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | create | POST | /v1/test_helpers/issuing/authorizations | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | capture | POST | /v1/test_helpers/issuing/authorizations/{authorization}/capture | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | expire | POST | /v1/test_helpers/issuing/authorizations/{authorization}/expire | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | finalize_amount | POST | /v1/test_helpers/issuing/authorizations/{authorization}/finalize_amount | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | respond | POST | /v1/test_helpers/issuing/authorizations/{authorization}/fraud_challenges/respond | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | increment | POST | /v1/test_helpers/issuing/authorizations/{authorization}/increment | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | reverse | POST | /v1/test_helpers/issuing/authorizations/{authorization}/reverse | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| Card | list | GET | /v1/issuing/cards | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/issuing/cards/{card} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | create | POST | /v1/issuing/cards | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | update | POST | /v1/issuing/cards/{card} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | deliver_card | POST | /v1/test_helpers/issuing/cards/{card}/shipping/deliver | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | fail_card | POST | /v1/test_helpers/issuing/cards/{card}/shipping/fail | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | return_card | POST | /v1/test_helpers/issuing/cards/{card}/shipping/return | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | ship_card | POST | /v1/test_helpers/issuing/cards/{card}/shipping/ship | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | submit_card | POST | /v1/test_helpers/issuing/cards/{card}/shipping/submit | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| Cardholder | list | GET | /v1/issuing/cardholders | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/issuing/cardholders/{cardholder} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | create | POST | /v1/issuing/cardholders | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | update | POST | /v1/issuing/cardholders/{cardholder} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| Dispute | list | GET | /v1/issuing/disputes | 2 | M10 | Generated list, detail, and edit views | dispute_read |
|  | retrieve | GET | /v1/issuing/disputes/{dispute} | 2 | M10 | Generated list, detail, and edit views | dispute_read |
|  | create | POST | /v1/issuing/disputes | 2 | M10 | Generated list, detail, and edit views | dispute_write |
|  | update | POST | /v1/issuing/disputes/{dispute} | 2 | M10 | Generated list, detail, and edit views | dispute_write |
|  | submit | POST | /v1/issuing/disputes/{dispute}/submit | 2 | M10 | Generated list, detail, and edit views | dispute_write |
| PersonalizationDesign | list | GET | /v1/issuing/personalization_designs | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/issuing/personalization_designs/{personalization_design} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | create | POST | /v1/issuing/personalization_designs | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | update | POST | /v1/issuing/personalization_designs/{personalization_design} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | activate | POST | /v1/test_helpers/issuing/personalization_designs/{personalization_design}/activate | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | deactivate | POST | /v1/test_helpers/issuing/personalization_designs/{personalization_design}/deactivate | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | reject | POST | /v1/test_helpers/issuing/personalization_designs/{personalization_design}/reject | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| PhysicalBundle | list | GET | /v1/issuing/physical_bundles | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/issuing/physical_bundles/{physical_bundle} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| Token | list | GET | /v1/issuing/tokens | 3 | M10 | API Explorer | token_read |
|  | retrieve | GET | /v1/issuing/tokens/{token} | 3 | M10 | API Explorer | token_read |
|  | update | POST | /v1/issuing/tokens/{token} | 3 | M10 | API Explorer | token_write |
| Transaction | list | GET | /v1/issuing/transactions | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/issuing/transactions/{transaction} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | update | POST | /v1/issuing/transactions/{transaction} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | refund | POST | /v1/test_helpers/issuing/transactions/{transaction}/refund | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | create_force_capture | POST | /v1/test_helpers/issuing/transactions/create_force_capture | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | create_unlinked_refund | POST | /v1/test_helpers/issuing/transactions/create_unlinked_refund | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| TrialOffer | list | GET | /v1/product_catalog/trial_offers | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/product_catalog/trial_offers/{id} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | create | POST | /v1/product_catalog/trial_offers | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | update | POST | /v1/product_catalog/trial_offers/{id} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| EarlyFraudWarning | list | GET | /v1/radar/early_fraud_warnings | 2 | M9 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/radar/early_fraud_warnings/{early_fraud_warning} | 2 | M9 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| PaymentEvaluation | create | POST | /v1/radar/payment_evaluations | 2 | M9 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| ValueList | delete | DELETE | /v1/radar/value_lists/{value_list} | 2 | M9 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | list | GET | /v1/radar/value_lists | 2 | M9 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/radar/value_lists/{value_list} | 2 | M9 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | create | POST | /v1/radar/value_lists | 2 | M9 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | update | POST | /v1/radar/value_lists/{value_list} | 2 | M9 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| ValueListItem | delete | DELETE | /v1/radar/value_list_items/{item} | 2 | M9 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | list | GET | /v1/radar/value_list_items | 2 | M9 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/radar/value_list_items/{item} | 2 | M9 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | create | POST | /v1/radar/value_list_items | 2 | M9 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| ReportRun | list | GET | /v1/reporting/report_runs | 2 | M7 | Generated list, detail, and edit views | report_runs_and_report_types_read |
|  | retrieve | GET | /v1/reporting/report_runs/{report_run} | 2 | M7 | Generated list, detail, and edit views | report_runs_and_report_types_read |
|  | create | POST | /v1/reporting/report_runs | 2 | M7 | Generated list, detail, and edit views | report_runs_and_report_types_read |
| ReportType | list | GET | /v1/reporting/report_types | 2 | M7 | Generated list, detail, and edit views | report_runs_and_report_types_read |
|  | retrieve | GET | /v1/reporting/report_types/{report_type} | 2 | M7 | Generated list, detail, and edit views | report_runs_and_report_types_read |
| ScheduledQueryRun | list | GET | /v1/sigma/scheduled_query_runs | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/sigma/scheduled_query_runs/{scheduled_query_run} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| Association | find | GET | /v1/tax/associations/find | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| Calculation | retrieve | GET | /v1/tax/calculations/{calculation} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | list_line_items | GET | /v1/tax/calculations/{calculation}/line_items | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | create | POST | /v1/tax/calculations | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| Location | list | GET | /v1/tax/locations | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/tax/locations/{location} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | create | POST | /v1/tax/locations | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| Registration | list | GET | /v1/tax/registrations | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/tax/registrations/{id} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | create | POST | /v1/tax/registrations | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | update | POST | /v1/tax/registrations/{id} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| Settings | retrieve | GET | /v1/tax/settings | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | update | POST | /v1/tax/settings | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| Transaction | retrieve | GET | /v1/tax/transactions/{transaction} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | list_line_items | GET | /v1/tax/transactions/{transaction}/line_items | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | create_from_calculation | POST | /v1/tax/transactions/create_from_calculation | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | create_reversal | POST | /v1/tax/transactions/create_reversal | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| Configuration | delete | DELETE | /v1/terminal/configurations/{configuration} | 2 | M6 | Generated list, detail, and edit views | customer_portal_write |
|  | list | GET | /v1/terminal/configurations | 2 | M6 | Generated list, detail, and edit views | customer_portal_read |
|  | retrieve | GET | /v1/terminal/configurations/{configuration} | 2 | M6 | Generated list, detail, and edit views | customer_portal_read |
|  | create | POST | /v1/terminal/configurations | 2 | M6 | Generated list, detail, and edit views | customer_portal_write |
|  | update | POST | /v1/terminal/configurations/{configuration} | 2 | M6 | Generated list, detail, and edit views | customer_portal_write |
| ConnectionToken | create | POST | /v1/terminal/connection_tokens | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| Location | delete | DELETE | /v1/terminal/locations/{location} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | list | GET | /v1/terminal/locations | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/terminal/locations/{location} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | create | POST | /v1/terminal/locations | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | update | POST | /v1/terminal/locations/{location} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| OnboardingLink | create | POST | /v1/terminal/onboarding_links | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| Reader | delete | DELETE | /v1/terminal/readers/{reader} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | list | GET | /v1/terminal/readers | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/terminal/readers/{reader} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | create | POST | /v1/terminal/readers | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | update | POST | /v1/terminal/readers/{reader} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | cancel_action | POST | /v1/terminal/readers/{reader}/cancel_action | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | collect_inputs | POST | /v1/terminal/readers/{reader}/collect_inputs | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | collect_payment_method | POST | /v1/terminal/readers/{reader}/collect_payment_method | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | confirm_payment_intent | POST | /v1/terminal/readers/{reader}/confirm_payment_intent | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | process_payment_intent | POST | /v1/terminal/readers/{reader}/process_payment_intent | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | process_setup_intent | POST | /v1/terminal/readers/{reader}/process_setup_intent | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | refund_payment | POST | /v1/terminal/readers/{reader}/refund_payment | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | set_reader_display | POST | /v1/terminal/readers/{reader}/set_reader_display | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | present_payment_method | POST | /v1/test_helpers/terminal/readers/{reader}/present_payment_method | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | succeed_input_collection | POST | /v1/test_helpers/terminal/readers/{reader}/succeed_input_collection | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | timeout_input_collection | POST | /v1/test_helpers/terminal/readers/{reader}/timeout_input_collection | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| TestClock | delete | DELETE | /v1/test_helpers/test_clocks/{test_clock} | 2 | M6 | Generated list, detail, and edit views test mode only | billing_clock_write |
|  | list | GET | /v1/test_helpers/test_clocks | 2 | M6 | Generated list, detail, and edit views test mode only | billing_clock_read |
|  | retrieve | GET | /v1/test_helpers/test_clocks/{test_clock} | 2 | M6 | Generated list, detail, and edit views test mode only | billing_clock_read |
|  | create | POST | /v1/test_helpers/test_clocks | 2 | M6 | Generated list, detail, and edit views test mode only | billing_clock_write |
|  | advance | POST | /v1/test_helpers/test_clocks/{test_clock}/advance | 2 | M6 | Generated list, detail, and edit views test mode only | billing_clock_write |
| Authentication | list | GET | /v1/three_d_secure/authentications | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/three_d_secure/authentications/{authentication} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | create | POST | /v1/three_d_secure/authentications | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | cancel | POST | /v1/three_d_secure/authentications/{authentication}/cancel | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | submit | POST | /v1/three_d_secure/authentications/{authentication}/submit | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| CreditReversal | list | GET | /v1/treasury/credit_reversals | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/treasury/credit_reversals/{credit_reversal} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | create | POST | /v1/treasury/credit_reversals | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| DebitReversal | list | GET | /v1/treasury/debit_reversals | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/treasury/debit_reversals/{debit_reversal} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | create | POST | /v1/treasury/debit_reversals | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| FinancialAccount | list | GET | /v1/treasury/financial_accounts | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/treasury/financial_accounts/{financial_account} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve_features | GET | /v1/treasury/financial_accounts/{financial_account}/features | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | create | POST | /v1/treasury/financial_accounts | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | update | POST | /v1/treasury/financial_accounts/{financial_account} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | close | POST | /v1/treasury/financial_accounts/{financial_account}/close | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | update_features | POST | /v1/treasury/financial_accounts/{financial_account}/features | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| InboundTransfer | list | GET | /v1/treasury/inbound_transfers | 3 | M10 | API Explorer | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/treasury/inbound_transfers/{id} | 3 | M10 | API Explorer | unlisted (Dashboard key picker) |
|  | fail | POST | /v1/test_helpers/treasury/inbound_transfers/{id}/fail | 3 | M10 | API Explorer | unlisted (Dashboard key picker) |
|  | return_inbound_transfer | POST | /v1/test_helpers/treasury/inbound_transfers/{id}/return | 3 | M10 | API Explorer | unlisted (Dashboard key picker) |
|  | succeed | POST | /v1/test_helpers/treasury/inbound_transfers/{id}/succeed | 3 | M10 | API Explorer | unlisted (Dashboard key picker) |
|  | create | POST | /v1/treasury/inbound_transfers | 3 | M10 | API Explorer | unlisted (Dashboard key picker) |
|  | cancel | POST | /v1/treasury/inbound_transfers/{inbound_transfer}/cancel | 3 | M10 | API Explorer | unlisted (Dashboard key picker) |
| OutboundPayment | list | GET | /v1/treasury/outbound_payments | 3 | M10 | API Explorer | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/treasury/outbound_payments/{id} | 3 | M10 | API Explorer | unlisted (Dashboard key picker) |
|  | update | POST | /v1/test_helpers/treasury/outbound_payments/{id} | 3 | M10 | API Explorer | unlisted (Dashboard key picker) |
|  | fail | POST | /v1/test_helpers/treasury/outbound_payments/{id}/fail | 3 | M10 | API Explorer | unlisted (Dashboard key picker) |
|  | post | POST | /v1/test_helpers/treasury/outbound_payments/{id}/post | 3 | M10 | API Explorer | unlisted (Dashboard key picker) |
|  | return_outbound_payment | POST | /v1/test_helpers/treasury/outbound_payments/{id}/return | 3 | M10 | API Explorer | unlisted (Dashboard key picker) |
|  | create | POST | /v1/treasury/outbound_payments | 3 | M10 | API Explorer | unlisted (Dashboard key picker) |
|  | cancel | POST | /v1/treasury/outbound_payments/{id}/cancel | 3 | M10 | API Explorer | unlisted (Dashboard key picker) |
| OutboundTransfer | list | GET | /v1/treasury/outbound_transfers | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/treasury/outbound_transfers/{outbound_transfer} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | update | POST | /v1/test_helpers/treasury/outbound_transfers/{outbound_transfer} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | fail | POST | /v1/test_helpers/treasury/outbound_transfers/{outbound_transfer}/fail | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | post | POST | /v1/test_helpers/treasury/outbound_transfers/{outbound_transfer}/post | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | return_outbound_transfer | POST | /v1/test_helpers/treasury/outbound_transfers/{outbound_transfer}/return | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | create | POST | /v1/treasury/outbound_transfers | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | cancel | POST | /v1/treasury/outbound_transfers/{outbound_transfer}/cancel | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| ReceivedCredit | list | GET | /v1/treasury/received_credits | 3 | M10 | API Explorer | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/treasury/received_credits/{id} | 3 | M10 | API Explorer | unlisted (Dashboard key picker) |
|  | create | POST | /v1/test_helpers/treasury/received_credits | 3 | M10 | API Explorer | unlisted (Dashboard key picker) |
| ReceivedDebit | list | GET | /v1/treasury/received_debits | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/treasury/received_debits/{id} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | create | POST | /v1/test_helpers/treasury/received_debits | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| Transaction | list | GET | /v1/treasury/transactions | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/treasury/transactions/{id} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| TransactionEntry | list | GET | /v1/treasury/transaction_entries | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v1/treasury/transaction_entries/{id} | 2 | M10 | Generated list, detail, and edit views | unlisted (Dashboard key picker) |
| MeterEvent | create_stream | POST | /v2/billing/meter_event_stream | 2 | M10 | Generated list, detail, and edit views v2 namespace: JSON bodies, page tokens, thin events | billing_meter_event_write |
|  | create | POST | /v2/billing/meter_events | 2 | M10 | Generated list, detail, and edit views v2 namespace: JSON bodies, page tokens, thin events | billing_meter_event_write |
| MeterEventAdjustment | create | POST | /v2/billing/meter_event_adjustments | 2 | M10 | Generated list, detail, and edit views v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
| MeterEventSession | create | POST | /v2/billing/meter_event_session | 3 | M10 | API Explorer v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
| ProductCatalogImport | list | GET | /v2/commerce/product_catalog/imports | 3 | M10 | API Explorer v2 namespace: JSON bodies, page tokens, thin events | product_catalog_import_read |
|  | create | POST | /v2/commerce/product_catalog/imports | 3 | M10 | API Explorer v2 namespace: JSON bodies, page tokens, thin events | product_catalog_import_write |
|  | retrieve | GET | /v2/commerce/product_catalog/imports/{id} | 3 | M10 | API Explorer v2 namespace: JSON bodies, page tokens, thin events | product_catalog_import_read |
| Account | list | GET | /v2/core/accounts | 2 | M8 | Generated list, detail, and edit views v2 namespace: JSON bodies, page tokens, thin events; accounts v2 is GA for Connect platforms and preview otherwise | connected_account_read |
|  | create | POST | /v2/core/accounts | 2 | M8 | Generated list, detail, and edit views v2 namespace: JSON bodies, page tokens, thin events; accounts v2 is GA for Connect platforms and preview otherwise | connected_account_read |
|  | retrieve | GET | /v2/core/accounts/{id} | 2 | M8 | Generated list, detail, and edit views v2 namespace: JSON bodies, page tokens, thin events; accounts v2 is GA for Connect platforms and preview otherwise | connected_account_read |
|  | update | POST | /v2/core/accounts/{id} | 2 | M8 | Generated list, detail, and edit views v2 namespace: JSON bodies, page tokens, thin events; accounts v2 is GA for Connect platforms and preview otherwise | connected_account_read |
|  | close | POST | /v2/core/accounts/{id}/close | 2 | M8 | Generated list, detail, and edit views v2 namespace: JSON bodies, page tokens, thin events; accounts v2 is GA for Connect platforms and preview otherwise | connected_account_read |
| AccountLink | create | POST | /v2/core/account_links | 2 | M8 | Generated list, detail, and edit views v2 namespace: JSON bodies, page tokens, thin events; accounts v2 is GA for Connect platforms and preview otherwise | account_link_write |
| AccountPerson | list | GET | /v2/core/accounts/{account_id}/persons | 2 | M8 | Generated list, detail, and edit views v2 namespace: JSON bodies, page tokens, thin events; accounts v2 is GA for Connect platforms and preview otherwise | unlisted (Dashboard key picker) |
|  | create | POST | /v2/core/accounts/{account_id}/persons | 2 | M8 | Generated list, detail, and edit views v2 namespace: JSON bodies, page tokens, thin events; accounts v2 is GA for Connect platforms and preview otherwise | unlisted (Dashboard key picker) |
|  | delete | DELETE | /v2/core/accounts/{account_id}/persons/{id} | 2 | M8 | Generated list, detail, and edit views v2 namespace: JSON bodies, page tokens, thin events; accounts v2 is GA for Connect platforms and preview otherwise | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v2/core/accounts/{account_id}/persons/{id} | 2 | M8 | Generated list, detail, and edit views v2 namespace: JSON bodies, page tokens, thin events; accounts v2 is GA for Connect platforms and preview otherwise | unlisted (Dashboard key picker) |
|  | update | POST | /v2/core/accounts/{account_id}/persons/{id} | 2 | M8 | Generated list, detail, and edit views v2 namespace: JSON bodies, page tokens, thin events; accounts v2 is GA for Connect platforms and preview otherwise | unlisted (Dashboard key picker) |
| AccountPersonToken | create | POST | /v2/core/accounts/{account_id}/person_tokens | 2 | M8 | Generated list, detail, and edit views v2 namespace: JSON bodies, page tokens, thin events; accounts v2 is GA for Connect platforms and preview otherwise | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v2/core/accounts/{account_id}/person_tokens/{id} | 2 | M8 | Generated list, detail, and edit views v2 namespace: JSON bodies, page tokens, thin events; accounts v2 is GA for Connect platforms and preview otherwise | unlisted (Dashboard key picker) |
| AccountToken | create | POST | /v2/core/account_tokens | 2 | M8 | Generated list, detail, and edit views v2 namespace: JSON bodies, page tokens, thin events; accounts v2 is GA for Connect platforms and preview otherwise | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v2/core/account_tokens/{id} | 2 | M8 | Generated list, detail, and edit views v2 namespace: JSON bodies, page tokens, thin events; accounts v2 is GA for Connect platforms and preview otherwise | unlisted (Dashboard key picker) |
| Event | list | GET | /v2/core/events | 2 | M11 | Generated list, detail, and edit views v2 namespace: JSON bodies, page tokens, thin events; accounts v2 is GA for Connect platforms and preview otherwise | event_read |
|  | retrieve | GET | /v2/core/events/{id} | 2 | M11 | Generated list, detail, and edit views v2 namespace: JSON bodies, page tokens, thin events; accounts v2 is GA for Connect platforms and preview otherwise | event_read |
| EventDestination | list | GET | /v2/core/event_destinations | 2 | M11 | Generated list, detail, and edit views v2 namespace: JSON bodies, page tokens, thin events; accounts v2 is GA for Connect platforms and preview otherwise | unlisted (Dashboard key picker) |
|  | create | POST | /v2/core/event_destinations | 2 | M11 | Generated list, detail, and edit views v2 namespace: JSON bodies, page tokens, thin events; accounts v2 is GA for Connect platforms and preview otherwise | unlisted (Dashboard key picker) |
|  | delete | DELETE | /v2/core/event_destinations/{id} | 2 | M11 | Generated list, detail, and edit views v2 namespace: JSON bodies, page tokens, thin events; accounts v2 is GA for Connect platforms and preview otherwise | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v2/core/event_destinations/{id} | 2 | M11 | Generated list, detail, and edit views v2 namespace: JSON bodies, page tokens, thin events; accounts v2 is GA for Connect platforms and preview otherwise | unlisted (Dashboard key picker) |
|  | update | POST | /v2/core/event_destinations/{id} | 2 | M11 | Generated list, detail, and edit views v2 namespace: JSON bodies, page tokens, thin events; accounts v2 is GA for Connect platforms and preview otherwise | unlisted (Dashboard key picker) |
|  | disable | POST | /v2/core/event_destinations/{id}/disable | 2 | M11 | Generated list, detail, and edit views v2 namespace: JSON bodies, page tokens, thin events; accounts v2 is GA for Connect platforms and preview otherwise | unlisted (Dashboard key picker) |
|  | enable | POST | /v2/core/event_destinations/{id}/enable | 2 | M11 | Generated list, detail, and edit views v2 namespace: JSON bodies, page tokens, thin events; accounts v2 is GA for Connect platforms and preview otherwise | unlisted (Dashboard key picker) |
|  | ping | POST | /v2/core/event_destinations/{id}/ping | 2 | M11 | Generated list, detail, and edit views v2 namespace: JSON bodies, page tokens, thin events; accounts v2 is GA for Connect platforms and preview otherwise | unlisted (Dashboard key picker) |
| GbBankAccount | list | GET | /v2/core/vault/gb_bank_accounts | 3 | M8 | API Explorer v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
|  | create | POST | /v2/core/vault/gb_bank_accounts | 3 | M8 | API Explorer v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v2/core/vault/gb_bank_accounts/{id} | 3 | M8 | API Explorer v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
|  | archive | POST | /v2/core/vault/gb_bank_accounts/{id}/archive | 3 | M8 | API Explorer v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
|  | unarchive | POST | /v2/core/vault/gb_bank_accounts/{id}/unarchive | 3 | M8 | API Explorer v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
| UsBankAccount | list | GET | /v2/core/vault/us_bank_accounts | 3 | M8 | API Explorer v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
|  | create | POST | /v2/core/vault/us_bank_accounts | 3 | M8 | API Explorer v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v2/core/vault/us_bank_accounts/{id} | 3 | M8 | API Explorer v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
|  | update | POST | /v2/core/vault/us_bank_accounts/{id} | 3 | M8 | API Explorer v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
|  | archive | POST | /v2/core/vault/us_bank_accounts/{id}/archive | 3 | M8 | API Explorer v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
|  | confirm_microdeposits | POST | /v2/core/vault/us_bank_accounts/{id}/confirm_microdeposits | 3 | M8 | API Explorer v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
|  | send_microdeposits | POST | /v2/core/vault/us_bank_accounts/{id}/send_microdeposits | 3 | M8 | API Explorer v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
|  | unarchive | POST | /v2/core/vault/us_bank_accounts/{id}/unarchive | 3 | M8 | API Explorer v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
| Adjustment | list | GET | /v2/money_management/adjustments | 3 | M10 | API Explorer v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v2/money_management/adjustments/{id} | 3 | M10 | API Explorer v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
| FinancialAccount | list | GET | /v2/money_management/financial_accounts | 2 | M10 | Generated list, detail, and edit views v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v2/money_management/financial_accounts/{id} | 2 | M10 | Generated list, detail, and edit views v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
|  | update | POST | /v2/money_management/financial_accounts/{id} | 2 | M10 | Generated list, detail, and edit views v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
| FinancialAddress | list | GET | /v2/money_management/financial_addresses | 3 | M10 | API Explorer v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
|  | create | POST | /v2/money_management/financial_addresses | 3 | M10 | API Explorer v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v2/money_management/financial_addresses/{id} | 3 | M10 | API Explorer v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
| FinancialAddressCreditSimulation | credit | POST | /v2/money_management/test_helpers/financial_addresses/{id}/credit | 3 | M10 | API Explorer v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
| InboundTransfer | list | GET | /v2/money_management/inbound_transfers | 3 | M10 | API Explorer v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
|  | create | POST | /v2/money_management/inbound_transfers | 3 | M10 | API Explorer v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v2/money_management/inbound_transfers/{id} | 3 | M10 | API Explorer v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
| OutboundPayment | list | GET | /v2/money_management/outbound_payments | 3 | M10 | API Explorer v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
|  | create | POST | /v2/money_management/outbound_payments | 3 | M10 | API Explorer v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v2/money_management/outbound_payments/{id} | 3 | M10 | API Explorer v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
|  | cancel | POST | /v2/money_management/outbound_payments/{id}/cancel | 3 | M10 | API Explorer v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
| OutboundSetupIntent | list | GET | /v2/money_management/outbound_setup_intents | 3 | M10 | API Explorer v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
|  | create | POST | /v2/money_management/outbound_setup_intents | 3 | M10 | API Explorer v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v2/money_management/outbound_setup_intents/{id} | 3 | M10 | API Explorer v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
|  | update | POST | /v2/money_management/outbound_setup_intents/{id} | 3 | M10 | API Explorer v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
|  | cancel | POST | /v2/money_management/outbound_setup_intents/{id}/cancel | 3 | M10 | API Explorer v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
| PayoutIntent | list | GET | /v2/money_management/payout_intents | 3 | M10 | API Explorer v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
|  | create | POST | /v2/money_management/payout_intents | 3 | M10 | API Explorer v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v2/money_management/payout_intents/{id} | 3 | M10 | API Explorer v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
|  | update | POST | /v2/money_management/payout_intents/{id} | 3 | M10 | API Explorer v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
|  | cancel | POST | /v2/money_management/payout_intents/{id}/cancel | 3 | M10 | API Explorer v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
|  | confirm | POST | /v2/money_management/payout_intents/{id}/confirm | 3 | M10 | API Explorer v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
|  | refresh_fx_quote | POST | /v2/money_management/payout_intents/{id}/refresh_fx_quote | 3 | M10 | API Explorer v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
|  | refresh_recipient_verification | POST | /v2/money_management/payout_intents/{id}/refresh_recipient_verification | 3 | M10 | API Explorer v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
| PayoutMethod | list | GET | /v2/money_management/payout_methods | 3 | M10 | API Explorer v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v2/money_management/payout_methods/{id} | 3 | M10 | API Explorer v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
|  | archive | POST | /v2/money_management/payout_methods/{id}/archive | 3 | M10 | API Explorer v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
|  | unarchive | POST | /v2/money_management/payout_methods/{id}/unarchive | 3 | M10 | API Explorer v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
| PayoutMethodsBankAccountSpec | retrieve | GET | /v2/money_management/payout_methods_bank_account_spec | 3 | M10 | API Explorer v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
| ReceivedCredit | list | GET | /v2/money_management/received_credits | 3 | M10 | API Explorer v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v2/money_management/received_credits/{id} | 3 | M10 | API Explorer v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
| RecipientVerification | create | POST | /v2/money_management/recipient_verifications | 3 | M10 | API Explorer v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v2/money_management/recipient_verifications/{id} | 3 | M10 | API Explorer v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
|  | acknowledge | POST | /v2/money_management/recipient_verifications/{id}/acknowledge | 3 | M10 | API Explorer v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
|  | recipient_verifications | POST | /v2/test_helpers/money_management/recipient_verifications | 3 | M10 | API Explorer v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
| Transaction | list | GET | /v2/money_management/transactions | 2 | M10 | Generated list, detail, and edit views v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v2/money_management/transactions/{id} | 2 | M10 | Generated list, detail, and edit views v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
|  | update | POST | /v2/money_management/transactions/{id} | 2 | M10 | Generated list, detail, and edit views v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
|  | refresh_regulatory_receipt | POST | /v2/money_management/transactions/{id}/refresh_regulatory_receipt | 2 | M10 | Generated list, detail, and edit views v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
| TransactionEntry | list | GET | /v2/money_management/transaction_entries | 2 | M10 | Generated list, detail, and edit views v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
|  | retrieve | GET | /v2/money_management/transaction_entries/{id} | 2 | M10 | Generated list, detail, and edit views v2 namespace: JSON bodies, page tokens, thin events | unlisted (Dashboard key picker) |
