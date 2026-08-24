# 2026-08-10 — Block raw OpenPhone/Quo and Twilio sends; require the worker-outreach API

## Context

The comms platform team shipped two node-backend (ops console API, OpsAuth) endpoints
for worker texting: `POST /v1/worker-outreach/request` for sends and
`GET /v1/worker-communications/openphone-replies` for reading a conversation's replies.
Until now the raw OpenPhone/Quo API was an accepted fallback because the broker had no
way to read replies — projects that needed two-way conversations had to touch the
vendor API anyway.

## Decision

With replies readable programmatically, the gap the raw paths filled is gone. Raw
vendor-API sends — OpenPhone/Quo **and** direct Twilio (`api.twilio.com` / the `twilio`
SDK) — are now **blocked** rather than "acceptable with `userId` stamped": the
constitution's comms rule, the worker-comms-safety doc, and the deploy-preflight
blocker all flip from prefer-the-broker to broker-only. Same reasoning for both
vendors: no opt-out suppression, blocked-number handling, dedup, geo-gating, or
Traba-side audit outside the broker. Projects that texted from their own Twilio number
send through the broker instead — the shared two-way number if they only send, an
OpenPhone line (`outboundPhoneNumber`) if they also need to read replies. Broker
gaps (unsupported message types, no OpsAuth path) go to the comms-platform team in
#claudecodestuff instead of justifying a raw send.

## Consequences

- Existing raw senders must migrate to the worker-outreach API; while a migration is in
  flight, the old floor still applies — honor known opt-outs and flag unchecked bulk
  sends for either vendor, plus stamp `userId` on legacy OpenPhone sends (Twilio has
  no such parameter).
- Every project registers a `sourceType` topic, so sends become attributable
  per-project, not just per-user.
- Deploy preflight treats any `api.openphone.com/v1/messages` or Twilio-SDK/API send in
  deployed code as a blocker whose fix is migration, not attribution stamping.
