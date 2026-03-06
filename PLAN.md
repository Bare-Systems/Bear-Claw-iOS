# BearClaw iOS Product + Integration Plan

## Vision
BearClaw iOS (or simply iOS) is the unified iPhone control plane for your home BearClaw agent and connected personal systems:
- Polar: home weather station + public weather APIs
- Koala: home security cameras, events, and AI monitoring
- Kodiak: personal financial insights and bill tracking
- Future Bear apps via a common BearClaw tool/action contract

## Guiding Constraints
- Secure remote-first access over public internet (no local-network assumption)
- Manual approval controls for sensitive actions (locks, security, finance)
- Fast conversational UX first, rich dashboards second
- Every action auditable (who asked, what executed, result)

## Target Architecture
- Client 1: BearClaw Web App (Phase 1 MVP)
- Client 2: BearClaw iOS App (SwiftUI)
- Agent Core: BearClaw running at home
- Edge Gateway: public HTTPS endpoint that fronts BearClaw safely
- Integrations: Polar, Koala, Kodiak adapters exposed as BearClaw tools

## Security Baseline (applies to all phases)
- TLS everywhere
- OIDC/OAuth2 login + short-lived access tokens + refresh rotation
- Device binding/session tracking for mobile/web sessions
- Policy-driven action authorization (low/medium/high risk actions)
- Step-up auth for high-risk commands (biometrics + confirmation)
- Immutable audit log for prompts, tool calls, and side effects
- Rate limits, IP anomaly detection, and replay protection

## Phase 1 MVP (Web Chat over Public Internet)
Goal: from anywhere (e.g., downtown), securely chat with BearClaw at home.

### Scope
- [x] Web app with chat UI (send/receive messages)
- [ ] Public API gateway to BearClaw `/v1/chat`
- [ ] BearClaw tool invocation for at least:
  - [ ] lock/unlock status check
  - [ ] current home temperature
  - [ ] 7-day weather summary
  - [ ] package-at-door camera check (summary only)
  - [ ] last month electric bill comparison
- [ ] Command confirmation flow for sensitive operations

### Deliverables
- [x] `web-mvp/` frontend (starter scaffold included)
- [ ] Auth integration (OIDC provider + bearer tokens)
- [ ] BearClaw gateway service with:
  - [ ] auth middleware
  - [ ] request validation
  - [ ] tool routing
  - [ ] structured logging + audit events
- [ ] Basic ops dashboard (latency, failed commands, tool errors)

### Exit Criteria
- [ ] Remote login works from external network
- [ ] Chat command success rate >= 95% for supported intents
- [ ] P95 chat roundtrip under 2.5s for non-video tasks
- [ ] Security review completed for auth and action confirmation

## Phase 2 BearClaw iOS Foundation
Goal: native iPhone chat client + secure session handling.

### Scope
- [ ] SwiftUI app shell + auth onboarding
- [ ] Native chat UI with streaming responses
- [x] Shared API client (`PandaCore`, legacy module name) and typed models
- [ ] Push notifications for async task completion

### Deliverables
- [ ] iOS app project with environments (dev/staging/prod)
- [ ] Keychain-backed token storage
- [ ] Chat transcript view + quick actions
- [ ] Error recovery UX (session expired, offline retry)

### Exit Criteria
- [ ] Full parity with Phase 1 web chat
- [ ] TestFlight internal beta to trusted devices

## Phase 3 Polar Integration (Weather)
Goal: live weather intelligence in BearClaw iOS.

### Scope
- [ ] Polar adapter in BearClaw for home-station telemetry
- [ ] Public weather provider fallback and forecast merge
- [x] Weather dashboard in app

### iPhone Features
- [ ] Current conditions card (home + outside)
- [ ] Hourly/day forecasts
- [ ] Alerts (freeze, storm, high wind)
- [ ] Ask-in-chat + tap-to-action shortcuts

### Exit Criteria
- [ ] Home telemetry ingest reliability >= 99%
- [ ] Forecast update cadence and staleness checks in place

## Phase 4 Koala Integration (Security)
Goal: secure home monitoring and actionable security controls.

### Scope
- [ ] Koala adapter for camera metadata/events/live feed handoff
- [ ] Door/lock state + control endpoints with strict auth policy
- [ ] AI surveillance event summaries (person/package/vehicle)

### iPhone Features
- [ ] Live camera list + event timeline
- [ ] "Is a package at door?" quick workflow
- [ ] Lock/unlock flows with biometric step-up
- [ ] Critical alert notifications

### Exit Criteria
- [ ] Verified low-latency event delivery
- [ ] Strong abuse controls for door/lock actions

## Phase 5 Kodiak Integration (Finance)
Goal: personal finance visibility and assistant-driven summaries.

### Scope
- [ ] Kodiak adapter for account snapshots, bills, budgets
- [ ] Monthly deltas and anomaly detection pipeline
- [ ] Explainability layer for recommendations

### iPhone Features
- [x] Monthly spend and bill trend cards
- [ ] "Did electric bill go up?" one-tap check
- [ ] Plain-language chat explanation with source links

### Exit Criteria
- [ ] Data freshness SLA defined and monitored
- [ ] Redaction and privacy controls validated

## Phase 6 Unified Action Center + Automation
Goal: one place to operate all systems.

### Scope
- [ ] Cross-app action catalog and permission matrix
- [ ] Routines: "Night lock + arm + weather prep"
- [ ] Scheduled checks and proactive notifications

### iPhone Features
- [ ] Action Center tab with categorized operations
- [ ] Approval queue for high-risk automations
- [ ] Routine builder and execution history

## Phase 7 Hardening + Production Launch
Goal: stable, secure consumer-grade release.

### Scope
- [ ] Threat model, penetration test, and incident playbooks
- [ ] Offline behavior + degraded mode handling
- [ ] Performance tuning for chat and live data cards
- [ ] App Store prep, policy docs, support runbook

### Launch Criteria
- [ ] Security sign-off
- [ ] Reliability SLOs met for 30-day soak period
- [ ] On-call alerting and rollback path tested

## Engineering Workstreams
- Client UX: web + iOS product surfaces
- Platform API: auth, gateway, command contracts
- Agent Integrations: Polar/Koala/Kodiak adapters
- Security: IAM, policy engine, audit, key management
- Reliability: observability, retries, circuit breaking

## Suggested Initial Backlog (next 2 weeks)
1. [x] Define `v1/chat` request/response schema and error codes.
2. Implement BearClaw gateway with auth middleware and audit logging.
3. Wire two safe read-only tools first (`weather_now`, `security_status`).
4. Deploy gateway with HTTPS + domain + cert.
5. Connect `web-mvp` chat UI to real endpoint with token auth.
6. Add sensitive action confirmation contract (`requires_confirmation`).
7. Run external-network end-to-end test from mobile network.

## Current Starter Assets in This Repo
- Swift package core models/client in `Sources/PandaCore/` (legacy module path)
- iOS app scaffold in `ios/App/PandaApp/` (legacy project path)
- Web MVP scaffold in `web-mvp/`
