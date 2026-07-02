# 2026-07-02 — Scheduled worker + Claude API, not an interactive Claude routine

## Context

The grammar check needs judgment on each run, which the `scheduling` skill says
points toward a **Claude routine** (a saved Claude session that runs on Anthropic's
cloud). We needed to decide between that and a deterministic worker that calls the
Claude API for just the grammar judgment.

## Options

1. **Claude routine.** A scheduled Claude session pulls Freshdesk replies, judges
   grammar itself, and posts to Slack via connectors.
   - Pro: no Anthropic API key; uses the Slack connector; native judgment.
   - Con: draws down subscription usage per run; hourly minimum cadence; runs in a
     cloud clone of a repo, so Freshdesk credentials + state still need handling;
     harder to unit-test; less control over cost and output shape.
2. **Deterministic worker calling the Claude API (chosen).** A one-pass bun/TS
   script fetches replies, calls `POST /v1/messages` for a bounded grammar check,
   posts to Slack, and persists dedupe state.
   - Pro: cheap (Haiku), controllable, testable (pure filter + JSON-parse logic have
     unit tests), portable (LaunchAgent locally or Railway cron), sub-hourly cadence.
   - Con: needs an Anthropic API key and a Slack bot token as secrets.

## Decision

Option 2. The judgment is narrow and well-bounded (proofread one reply, return JSON
issues), which is a great fit for a single API call rather than a full agentic
session. It keeps cost predictable, lets us unit-test the deterministic parts, and
runs anywhere a scheduler can invoke a script.

## Consequences

- Requires three secrets (Freshdesk, Anthropic, Slack) instead of one.
- If we later want richer, multi-step reasoning per reply (e.g. cross-referencing
  macros or tone guidelines), revisit the routine approach.
