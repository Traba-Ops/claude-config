# Trim always-on instruction bloat: move niche rules off the per-session path

**Date:** 2026-06-03

## Context

Prometheus ships three kinds of content, but only one taxes every session:

- **Rules** (`rules/*.md`) — injected into every session, every project, regardless of task.
- **Skills** (`skills/*/SKILL.md`) — only the short frontmatter `description` is always-on; the body loads on-demand when Claude invokes the skill.
- **Docs** (`docs/*.md`) — never auto-load; pure reference.

The always-on rule payload had grown to ~3,900 words (~5.2k tokens) on every session:

| Rule | Words |
|---|---|
| `traba-constitution.md` | 1,112 |
| `teammate-collab.md` | 1,213 |
| `workflows.md` | 807 |
| `teammate-calibration.md` | 393 |
| `traba-spec.md` | 364 |

(`design-system.md` is path-scoped to frontend files and not always-on.)

`teammate-collab` + `workflows` together were **52% of the always-on payload** — yet both govern scenarios most sessions never hit: two operators co-working on one project via a shared Slack thread, and the opt-in, token-heavy dynamic-workflows feature. `workflows.md` was also the most recent rule added (#13), which is what surfaced the bloat concern.

## The principle we're adopting

**A rule earns an always-on slot only if it must fire even when the user never mentions the topic.**

- Security invariants, the simplicity/autonomy/defer-to-ops posture, calibration, and doc-maintenance must hold silently → they stay in `rules/`.
- Anything triggered by an explicit signal (the user says "co-working," names a teammate, says "use a workflow," or starts a deploy) belongs in a **skill** (procedural, invokable) or a **doc** (reference) — it doesn't need to ride along in every session.

This principle lives here, in a decision record, rather than in the constitution — putting framework-maintenance guidance into the always-on constitution would itself be bloat.

## Options considered

1. **Leave it.** Simplest, but the payload keeps growing every time someone adds a rule for a niche scenario, and every session pays for it.
2. **Aggressively rewrite the constitution.** High risk of changing behavior/meaning for little word savings; invites bikeshedding in review.
3. **Move the two niche, signal-triggered rules off the always-on path; dedup the rest.** (Chosen.) Biggest reduction, lowest risk — the structural moves are mechanical and capability-preserving.

## Decision

1. **`teammate-collab.md` → `skills/teammate-collab/SKILL.md`.** Converted to a skill with a trigger-bearing `description`. Its own opening line already read like a skill trigger ("kicks in any time the operator says they're co-working…"). The constitution keeps its one-paragraph "Co-Working" pointer, updated to say *invoke the teammate-collab skill*.
2. **`workflows.md` → `docs/workflows.md`.** The full guidance becomes reference. The single operative guardrail (don't start a workflow unless scale needs many coordinated agents **and** the operator opted in) folds into the constitution's "Recurring Tasks and Token Cost" section, where the token-cost trade-off already lives.
3. **Constitution `## Security` dedup.** Removed the "Name Railway projects descriptively" and "Monitor every deploy until healthy" bullets — both already exist in the deployment skill (which fires exactly when deploying). Left a one-line note pointing there. Kept all true invariants (no hardcoded secrets, no `.env` commits, Traba-Ops org, Traba Railway team, no deploy without auth).
4. **`skill-bundle-spec.md` updated** to match: workflows moved out of the always-active rules list, teammate-collab added as a skill (it had never been listed).

## Result

Always-on rule payload: **~3,900 → ~1,950 words (~50% reduction)**, with zero capability loss — teammate-collab is now invoked on the co-working signal, workflow detail is read when authoring a workflow, and deploy-discipline fires from the deployment skill.

## Relationship to prior records

Supersedes the delivery choice in [2026-06-03-dynamic-workflows-guidance.md](2026-06-03-dynamic-workflows-guidance.md), which put workflows guidance in `rules/workflows.md` as an always-active rule. That record's reasoning ("rules are the only channel that shapes the agent's behavior every session") held for the *guardrail*, which is why the guardrail stays in the constitution — but the full reference did not need to be always-on.
