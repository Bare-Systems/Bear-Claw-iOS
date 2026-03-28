# Security Policy

BearClawiOS handles credentials and remote access to the BareSystems stack.

## Reporting

Report vulnerabilities privately with:

- device and iOS version
- pairing or auth flow involved
- expected versus actual trust or auth behavior
- whether credentials or session state are exposed

## Baseline Expectations

- Non-localhost remote endpoints must use HTTPS.
- Auth tokens belong in secure storage, not plain preferences.
- TLS trust behavior must be explicit and user-recoverable.
- Auth, pairing, and certificate changes must update this file and `README.md`.
