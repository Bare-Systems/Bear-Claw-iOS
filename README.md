# BearClaw iOS

The iOS client app for securely interacting with your home-deployed BearClaw agent and integrated Bare Systems (Polar, Koala, Kodiak).

Current MVP security behavior:
- Bearer token persisted in Keychain (not `UserDefaults`).
- Remote gateway URLs must use `https://` (plain `http://` only allowed for localhost development).
- Chat client targets `POST /v1/chat` and surfaces typed auth/network error states.
- Pairing supports copy/paste payload import (`JSON` or `tardi1:` code) containing endpoint/token/cert fingerprint.
- TLS trust uses pinned cert SHA-256 fingerprint from pairing payload (no system-wide cert install required in app flow).
