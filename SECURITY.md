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
- Auth tokens should remain device-local in Keychain with no sync/export path from the app.
- TLS trust behavior must be explicit and user-recoverable.
- Pairing import paths (`tardi1:` links, shared payload files, and QR imports) must apply the same endpoint/token/fingerprint validation before saving.
- Auth, pairing, and certificate changes must update this file and `README.md`.
