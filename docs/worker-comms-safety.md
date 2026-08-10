# Worker communications — send through the comms broker; raw OpenPhone is blocked

Any tool that sends a worker-facing message (SMS, two-way text, robocall) goes through
**Traba's comms broker** via the worker-outreach API. The broker now covers both halves
of a conversation — sending, and reading the worker's replies programmatically — so the
raw OpenPhone/Quo API is **no longer an acceptable send path**: don't add new raw sends,
and migrate existing ones. If the broker genuinely can't do what your project needs,
raise it with the comms-platform team in #claudecodestuff instead of routing around it.

## Scope

This guidance governs **the send itself**. It does not apply to prep work around a
send — reformatting a CSV, drafting message copy, building a recipient list, resolving
phone numbers. Never refuse or block prep work merely because the eventual send may use
the raw API.

One nuance: list-building is exactly where opt-out filtering belongs. If a suppression
source is available to you, applying it while you build the list is part of doing the
prep well — not a reason to refuse the prep.

## The required route: the worker-outreach API (comms broker)

**Send through the worker-outreach endpoint** on Traba's node backend (the ops console
API, OpsAuth) — not a vendor API:

```
POST /v1/worker-outreach/request        (OpsAuth — authenticate as the acting recruiter)
body: {
  "type": "OPS_SMS",
  "workerId": "<id>",                   // or "ghostProfileId" for leads who haven't signed up
  "smsBody": "...",
  "sourceType": "<YOUR_TOPIC>",         // required in practice — see field notes
  "outboundPhoneNumber": "<E.164>"      // optional — your project's OpenPhone line
}
```

It routes through the central comms broker, which:

- **attributes the message to the authenticated ops user** (the real recruiter), not to
  whoever owns the phone number,
- picks the provider (OpenPhone/Twilio),
- applies opt-out suppression, blocked-number handling, dedup, geo-gating, and audit
  logging,
- **logs every message against your project's topic** (`sourceType`).

Authenticate the call as the recruiter (their OpsAuth token / `@traba.work` identity) and
attribution is handled for you — you never touch a `userId`.

Field notes:

- **`sourceType` (topic):** each project registers its own topic with the comms-platform
  team — it's a one-liner on their side; ask in #claudecodestuff. Unregistered topics are
  **rejected**; an omitted `sourceType` falls back to `OPS_MANUAL`, which loses
  per-project attribution — register a topic instead.
- **`outboundPhoneNumber`:** pass your project's OpenPhone line (E.164) and the message
  sends from that line, landing in your existing OpenPhone thread with the worker. Omit
  it and the send goes out from Traba's shared two-way number via Twilio.
- **`ghostProfileId`** works in place of `workerId` for leads who haven't signed up.

The older broker endpoint (`POST /communication/send-direct-two-way-sms`) still exists,
but new projects should use the worker-outreach API, and existing callers should migrate.

## Blocked route: the raw OpenPhone/Quo API

Direct sends via `POST https://api.openphone.com/v1/messages` are **blocked**. This used
to be an acceptable fallback when the broker wasn't reachable; now that the
worker-outreach API covers both sending and reading replies, there is no gap left for
the raw path to fill. Don't add new raw sends, and migrate existing callers to
`POST /v1/worker-outreach/request`.

Why the raw path is out: it has none of the broker's safety rails — no opt-out
suppression, no blocked-number handling, no dedup, no geo-gating, and no Traba-side
audit record (the only trace lives in the vendor console). It also has a proven
attribution failure mode: omit `userId` and OpenPhone credits the message to the
**phone number's owner**, so an ownership change silently re-attributes history.

> This actually happened: an owner change made **~155K automated hiring messages
> across 161 numbers** all show as a single person, because the sending apps posted
> `{ content, from, to }` with **no `userId`**.

If the broker can't do what you need — a message type it doesn't support yet, or no
OpsAuth path in your environment — that's a gap to raise with the comms-platform team
in #claudecodestuff, not a license to go raw. For a legacy raw send that is still
running while its migration lands, the old floor holds in the meantime: stamp the
sender's `userId` on every payload, honor opt-outs you know about, and flag bulk sends
you can't check opt-outs for.

## Reading replies

Replies arrive in the OpenPhone thread, but you read them from Traba's node backend —
the same ops console API and OpsAuth as the send endpoint, not the OpenPhone API. No
OpenPhone MCP or vendor-console scraping, and no raw-API fallback:

```
GET /v1/worker-communications/openphone-replies?workerId=<id>&sourceType=<YOUR_TOPIC>&limit=100
        (OpsAuth — Traba backend; returns the OpenPhone thread's replies)
```

- `workerId` **or** `ghostProfileId` is required — the filter isn't optional, and the
  endpoint only returns replies for the worker or lead you query.
- Poll with the returned `nextCursor` (`since`/`afterId`).
- One worker + one OpenPhone line = one thread: if multiple projects text the same worker
  on the same line, a reply belongs to the thread, not provably to your project.

## Rationale

Every worker message must trace to a real, intentional sender — a recruiter or a named
bot user — so ownership changes never silently rewrite who "sent" thousands of messages.
The broker guarantees that automatically, and layers opt-out suppression, blocked-number
handling, dedup, geo-gating, and audit logging on top. The raw path was tolerated only
while the broker couldn't cover reading replies; with both send and read endpoints live,
even a raw send with a stamped `userId` preserves attribution alone and none of the
other rails — so the broker is now the only sanctioned route.
