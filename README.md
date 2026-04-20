# BearClaw iOS

The iOS client app for securely interacting with your home-deployed BearClaw agent and integrated Bare Systems (Polar, Koala, Kodiak).

Current app behavior:
- Bearer tokens are stored in the iOS Keychain with a device-local accessibility policy instead of `UserDefaults`.
- Remote gateway URLs must use `https://` (plain `http://` only allowed for localhost development).
- Chat uses `POST /v1/chat/stream` and renders live SSE run events, run IDs, and final model output in the chat timeline.
- Pairing supports pasted payloads, QR-code image import, `tardi1:` deep links, and shared `.json` / text pairing files that carry endpoint, bearer token, and cert fingerprint.
- The Connection tab shows gateway reachability, last pairing source, token/pin status, and recent run/session state.
- TLS trust uses the pinned cert SHA-256 fingerprint from pairing (no system-wide cert install required in app flow).
