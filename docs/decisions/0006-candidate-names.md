# 0006: Candidate product names and how the app refers to Stripe

## Context

"Geist6" is the repository's working name. Stripe's Marks Usage Terms
(`docs/stripe/brand.md`) forbid using Stripe's marks in a product name,
domain, or trademark, forbid implying endorsement, and allow truthful
reference in text. The final name is a maintainer decision needed by M15.

## Decision

Candidate names for the shipped product (each checked against Stripe's rules;
final choice and any trademark/App Store collision check are maintainer
items):

- **Ledgerline**
- **Paydesk**
- **Tillside**
- **Countroom**
- **Openbook** (common word; highest collision risk)

In all app copy: the app refers to Stripe factually — "a dashboard for your
Stripe account", "connects directly to the Stripe API" — never in the name,
icon, or branding, never as the most prominent element, never with the Stripe
logo or badge as app branding, and always alongside the disclaimer "not
affiliated with or endorsed by Stripe" in the app's about screen and store
metadata. No ™ or ® next to Stripe's name.

## Consequences

- Marketing and store copy are written to these rules from the start, so the
  M15 brand check is a confirmation rather than a rewrite.
- If the maintainer later wants deeper use of Stripe brand assets (for
  example, a "Connect with Stripe" style affordance in onboarding), that
  requires Stripe's express permission (trademarks@stripe.com) and is not
  planned for v1.0.0.
