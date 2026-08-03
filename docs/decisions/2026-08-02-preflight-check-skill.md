# Preflight Check as a Deploy-Triggered Skill

**Date:** 2026-08-02
**Status:** Accepted

## Context

Deploy-time compliance rules were scattered: the constitution carried a few always-on gates, bq-auth and authentication carried path-specific rules, and nothing tied them into a check an operator's Claude actually runs before a deploy. The data team's org-wide governance scanner audits repos from the outside, after the fact; Prometheus apps should instead arrive at deploy time already audited.

## Decision

Ship a `preflight-check` skill: a runnable pre-deploy checklist built around four invariants (secrets never leave the perimeter; data access is always per-user; nothing is reachable without auth; infrastructure stays inside Traba's perimeter), with an app-profile preflight deciding which checks apply and every check tagged **[BLOCKER]** or **[advisory]**. The constitution keeps a one-line gate ("never deploy without … a clean compliance check"); the detail lives in the skill.

## Why

- **Skill, not always-on rule.** The checklist only matters when deploying — per authoring-rules.md, conditional procedure belongs in a skill with the constitution holding a pointer. The deployment skill and the bq-auth allowlist flow are the natural load points.
- **Invariants over a flat checklist.** Each section opens with the rule the agent can generalize from, so novel violations that no grep anticipates still get caught; the greps are evidence-gathering, not the definition of compliance.
- **Blockers vs advisories instead of a severity rubric.** An operator audience needs one decision (deploy or don't), not a four-level triage. Blockers breach an invariant; advisories are hygiene.
- **Scorecard rides the allowlist request.** Every BigQuery app already messages #data before deploying; attaching the per-invariant scorecard as the first threaded reply gives the gate-keeper audit evidence at the moment they need it, with no new process.

## Consequences

- The constitution's deploy gate and the eng runbook's Step 1 both reference the skill; engineers ask operators for the scorecard at promotion time.
- bq-auth's allowlist request template requires a CLEAR preflight result before it may be sent.
- The check audits the repo and its deploy only — Railway config drift, scheduled jobs outside the repo, and vendor consoles remain separate concerns, and the deterministic layers (gitleaks, CI, push protection) run alongside it.
