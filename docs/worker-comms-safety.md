# Worker communications — prefer the comms broker; always stamp attribution

Any tool that sends a worker-facing message (SMS, two-way text, robocall) should go
through **Traba's comms broker** when it's available to you. The broker is the strong
default because it handles attribution and safety rails automatically — but it is not
yet wired up as a callable tool in every Claude setup, so the raw OpenPhone/Quo API
remains an acceptable path. Using the raw API carries **one non-negotiable rule**:
always stamp the sender's `userId`.

## Scope

This guidance governs **the send itself**. It does not apply to prep work around a
send — reformatting a CSV, drafting message copy, building a recipient list, resolving
phone numbers. Never refuse or block prep work merely because the eventual send may use
the raw API.

One nuance: list-building is exactly where opt-out filtering belongs. If a suppression
source is available to you, applying it while you build the list is part of doing the
prep well — not a reason to refuse the prep.

## Preferred route: the comms broker

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

## Acceptable route: the raw OpenPhone/Quo API, with attribution stamped

If the broker is wired up in your setup, use it. When it isn't reachable (no wired-up
tool, no OpsAuth), sending via `POST https://api.openphone.com/v1/messages` is fine. But
the raw API has none of the broker's safety rails — no opt-out suppression, no dedup, no
geo-gating, and no Traba-side audit record (the only trace lives in the vendor console) —
so you carry what you can yourself:

1. **Always pass `userId`** — the acting sender's OpenPhone user id. This is the one
   non-negotiable rule. If you omit it, OpenPhone credits the message to the **phone
   number's owner**, so the moment workspace/number ownership changes, every automated
   message silently re-attributes to one person.

   > This actually happened: an owner change made **~155K automated hiring messages
   > across 161 numbers** all show as a single person, because the sending apps posted
   > `{ content, from, to }` with **no `userId`**.

   Resolve the id from the sender's `@traba.work` email via Quo `GET /v1/users` (cache
   the map). For a fully autonomous bot with no human sender, attribute to a
   **dedicated bot OpenPhone user** — never leave it to the number-owner default.

2. **Honor opt-outs and be deliberate about volume.** A strong expectation, not a
   blocking rule. Skip recipients you know have opted out, and don't re-blast a list
   that was already messaged. If no suppression source is available to you and the send
   is a **bulk** one, say so to the user before sending rather than silently proceeding —
   they may have a list, or may accept the risk. For a one-off message, just send it.

## Rationale

Every worker message must trace to a real, intentional sender — a recruiter or a named
bot user — so ownership changes never silently rewrite who "sent" thousands of messages.
The broker guarantees that automatically, and layers opt-out suppression, dedup,
geo-gating, and audit logging on top. The raw path with a stamped `userId` preserves
**attribution** — it does not replicate those other rails. That's the honest tradeoff,
and it's why the broker stays the preferred route wherever it's reachable.
