# Name and brand rules for a third-party Stripe client

Research note from milestone M0. Written from Stripe's published Marks Usage
Terms and developer-facing wording as of 2026-11-16. The decision this note
feeds is decision 0006. Sources are listed at the end.

## What Stripe's Marks Usage Terms say

Stripe's Marks Usage Terms (last updated June 12, 2023, at
`https://stripe.com/marks/legal`) govern any use of Stripe's names, logos,
icons, design elements, and trade dress ("Marks"). The parts that bind a
third-party app:

- The permission is **non-exclusive, non-transferable, revocable at any
  time**, and Stripe may require changes and review usage.
- **Do**: use the Marks only on the portion of the app that directly relates
  to Stripe's services; follow any style guidelines Stripe gives; use the
  word mark unaltered in text to refer truthfully and accurately to Stripe or
  its services.
- **Don't**: modify the Marks (no shortening, plural, possessive, or
  translation); misrepresent the relationship or imply endorsement or
  sponsorship; use the Marks more prominently than the app's own; use them in
  the app's own **trademark, trade name, domain, or social-media handle**; add
  anything so close as to create a new mark; use the Marks on merchandise; or
  pair them with ™/®.

Applied to Geist6, this means:

1. The product name must not contain "Stripe" or any Stripe mark, and must
   not be confusingly similar to one.
2. The app may truthfully *describe* what it does in plain words — "a
   dashboard for your Stripe account", "connects to the Stripe API" — because
   that is accurate reference, not branding. Descriptions stay factual and
   secondary to the app's own name and icon.
3. The app does not use the Stripe logo, badge, or word mark as its icon or
   branding. Where a screen needs to identify the connected service, plain
   text is used.
4. A one-line disclaimer stays in the app and metadata: not affiliated with
   or endorsed by Stripe.
5. Screenshots for the App Store show the app's own UI, which may contain
   account data names ("Stripe balance") — the object names Stripe itself
   returns are factual references, not brand usage.

## Candidate product names

For decision 0006, candidates that pass the rules above (no Stripe marks, no
confusing similarity, no claim of endorsement), with the reasoning:

- **Ledgerline** — ledger imagery, neutral, unlikely to collide with Stripe
  product names (Stripe has no "Ledgerline").
- **Paydesk** — a desk for payments work; avoid if a major fintech uses it
  (checked at release time).
- **Tillside** — till (cash register) + a side/toponym feel; distinctive.
- **Countroom** — the room where counting happens; memorable, neutral.
- **Openbook** — open books/accounting; common word, so trademark screening
  matters more.
- **Stripe...** — ruled out; not a candidate.
- Working name "Geist6" stays the repository name; the shipped product gets
  one of the candidates. Choosing the final name is a maintainer item needed
  by M15 (App Store metadata), with a trademark/App Store collision check
  against existing apps at that time.

## Sources

- `https://stripe.com/marks/legal` — Stripe's Marks Usage Terms (do/don't list, quoted concepts summarized in our own words)
- `https://stripe.com/newsroom/information` — media assets page stating that all Stripe trademarks are subject to the Marks Usage Agreement
- `https://docs.stripe.com/stripe-apps/store/branding` family of pages — Stripe Apps naming rules echo the same "no confusion, no endorsement" principle for third-party integrations
