# Worker communications — use the comms broker, not the raw OpenPhone/Quo API

Any tool that sends a worker-facing message (SMS, two-way text, robocall) must go
through **Traba's comms broker**, not the raw OpenPhone/Quo API. This is a hard default,
not a style preference — the raw API silently breaks attribution and bypasses every
safety rail.

## Default rule

**Send through the comms broker endpoint** on the Traba backend:

```
POST /communication/send-direct-two-way-sms        (OpsAuth — authenticate as the acting recruiter)
body: { phoneNumber, message, fromPhoneNumber? }
```

It routes through the central `CommunicationService`, which:

- **attributes the message to the authenticated ops user** (the real recruiter), not to
  whoever owns the phone number,
- picks the provider (OpenPhone/Twilio),
- applies opt-out suppression, dedup, geo-gating, and audit logging.

Authenticate the call as the recruiter (their OpsAuth token / `@traba.work` identity) and
attribution is handled for you — you never touch a `userId`.

## Why the raw OpenPhone/Quo API is dangerous

`POST https://api.openphone.com/v1/messages` has **no safety rails**, and its attribution
is a trap: if you omit `userId`, OpenPhone credits the message to the **phone number's
owner**. So the moment workspace/number ownership changes, every automated message
silently re-attributes to one person.

> This actually happened: an owner change made **~155K automated hiring messages across
> 161 numbers** all show as a single person, because the sending apps posted
> `{ content, from, to }` with **no `userId`**.

It also bypasses opt-outs, dedup, geo-gating, and audit — none of which the vendor API
enforces.

## Raw OpenPhone API = last resort

Only reach for the raw API when the broker genuinely cannot do the job (a vendor-specific
feature), and only after confirming with the comms owner. When you do, you **must**:

- **Always pass `userId`** — the acting recruiter's OpenPhone user id. Never omit it;
  omission defaults to the number owner.
- Resolve it from the recruiter's `@traba.work` email via Quo `GET /v1/users` (cache the
  map).
- For a fully autonomous bot with no human sender, attribute to a **dedicated bot
  OpenPhone user** — never leave it to the number-owner default.

## Rationale

Every worker message must trace to a real, intentional sender — a recruiter or a named
bot user — so ownership changes never silently rewrite who "sent" thousands of messages,
and so opt-outs / compliance / audit always apply. The broker is the one place that
guarantees this; the raw API guarantees none of it.
