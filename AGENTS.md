# Working in This Repository

This guide is for anyone, human or agent, changing this repository. Read `ROADMAP.md` and `STATUS.md` first: they say what the project is and where the work stands.

## Priorities

Safety of the user's money and keys, then correctness, then privacy, then clarity, then breadth of features.

## Research Before Code

Milestone M0 checks this roadmap against Stripe's current documentation and API definition, writes the research notes in `docs/stripe/`, and reviews the plan over at least five passes before any app code is written. Later milestones may reopen the plan when the work shows it is wrong: change `ROADMAP.md`, record a decision, and go on.

## Rules

- Run `scripts/check.sh` before every push, once it exists (M1). It runs what CI runs; keep the two in step.
- Every change that alters behavior comes with tests (see `TESTING.md`), and every bug fix starts with a regression test.
- Keep logic in the Swift package, where `swift test` covers it, and keep the app target thin.
- Never hand-write a Stripe model that the generator can produce. Regenerate from the pinned spec instead.
- Every write request carries an idempotency key, and no write can be sent in Dashboard mode.
- Never put a Stripe key, real account data, or a real Stripe ID from a live account in the repository, a test fixture, a log, or a screenshot. Fixtures come from `stripe-mock` or are written by hand with obviously fake values.
- Write research notes in your own words, citing the Stripe page or spec version; never copy Stripe's documentation text into the repository.
- Record each significant decision in `docs/decisions/` (Context, Decision, Consequences), numbered in order.
- Keep `STATUS.md` current: current milestone, last done, next step, blocked on, and a log line.
- Work on `main` in small commits that keep CI green. Never force-push or rewrite pushed history.
- Prefer well-known, maintained dependencies, and record any security-relevant dependency in a decision record.
- Pin GitHub Actions to full commit SHAs and keep workflow permissions read-only.
- Versions follow `vA.B.C`: A for a major release or rewrite, B for a feature release, and C for a fix or small change.

## Public Repository

Everything here is public, but all rights are reserved (see `LICENSE`): never add an open-source license or invite outside contributions. Never commit secrets of any kind (Stripe keys, including test keys, signing keys, or anything that looks real), email addresses, hostnames, IP addresses, local paths outside the repository, or anything about the machines or services used to develop it. Test data uses obviously fake values (`alice`, `example.com`, `acct_test_123`). Commit messages describe the code only.
