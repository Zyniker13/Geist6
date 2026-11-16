# Security

## Reporting a Vulnerability

Please report security problems privately through GitHub's [private vulnerability reporting](../../security/advisories/new) for this repository, not in a public issue. Include what triggers the problem and the version tag or commit you tested. Never include a real Stripe key in a report.

## What Counts

The app holds Stripe keys and can move money, so any of these is a security bug:

- a key that reaches anywhere other than the device's Keychain and Stripe (a file, log, cache, export, screenshot, or the clipboard after setup);
- a write request sent while an account is in Dashboard mode;
- a money-moving or irreversible action that runs without its confirmation;
- a request sent to any host other than Stripe's;
- a crash, hang, or unbounded memory or disk use caused by a response, file, link, or QR code.
