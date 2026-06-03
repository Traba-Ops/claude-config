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

Sumeet's framing (the trigger for this work) is sharper than "save tokens": **the more rules we add — and the longer/sloppier they are — the less reliably Claude follows any of them.** Bloat is an *adherence* problem, not just a cost problem. So the bar isn't "fewer tokens," it's "every always-on rule is short, clearly an instruction (not documentation), and earns its slot." He flagged both rules by name: teammate-collab as "possibly a single sentence within the existing constitution," and workflows as "mostly documentation… should be handled by base Claude anyways, not us."

## The principle we're adopting

**A rule earns an always-on slot only if it must fire even when the user never mentions the topic — and only as a short instruction, not documentation.** Reference material and signal-triggered SOPs do not qualify; they go to docs or skills.

- Security invariants, the simplicity/autonomy/defer-to-ops posture, calibration, and doc-maintenance must hold silently → they stay in `rules/`.
- Anything triggered by an explicit signal (the user says "co-working," names a teammate, says "use a workflow," or starts a deploy) belongs in a **skill** (procedural, invokable) or a **doc** (reference) — it doesn't need to ride along in every session.

This principle lives here, in a decision record, rather than in the constitution — putting framework-maintenance guidance into the always-on constitution would itself be bloat.

## Options considered

1. **Leave it.** Simplest, but the payload keeps growing every time someone adds a rule for a niche scenario, and every session pays for it.
2. **Aggressively rewrite the constitution.** High risk of changing behavior/meaning for little word savings; invites bikeshedding in review.
3. **Move the two niche, signal-triggered rules off the always-on path; dedup the rest.** (Chosen.) Biggest reduction, lowest risk — the structural moves are mechanical and capability-preserving.

## Decision

1. **`teammate-collab.md` → `skills/teammate-collab/SKILL.md`.** Converted to a skill with a trigger-bearing `description`. Its own opening line already read like a skill trigger ("kicks in any time the operator says they're co-working…"). The constitution's "Co-Working" section is cut to **a single sentence** that points at the skill — matching Sumeet's "possibly a single sentence within the existing constitution." We keep the SOP as a skill rather than deleting it: it's zero always-on cost (only the description loads, on the co-working signal) and the procedure is real institutional knowledge, but if it proves unused it can be deleted outright with no further change to the constitution.
2. **`workflows.md` → `docs/workflows.md`.** The full guidance becomes reference (read on-demand when authoring a workflow). In the constitution, the workflows guardrail is **one sentence** appended to the existing "Recurring Tasks and Token Cost" rule: opt-in and token-heavy, don't start one unless the operator asked. Base Claude's own tooling already explains *how* workflows work and that they're token-heavy; we keep only the one-line Traba posture (conservative by default), not a re-explanation of the feature.
3. **Constitution `## Security` dedup.** Removed the "Name Railway projects descriptively" and "Monitor every deploy until healthy" bullets — both already exist in the deployment skill (which fires exactly when deploying). Left a one-line note pointing there. Kept all true invariants (no hardcoded secrets, no `.env` commits, Traba-Ops org, Traba Railway team, no deploy without auth).
4. **`skill-bundle-spec.md` updated** to match: workflows moved out of the always-active rules list, teammate-collab added as a skill (it had never been listed).

## Result

Always-on rule payload: **~3,900 → ~1,830 words (~53% reduction)**, with zero capability loss — teammate-collab is invoked on the co-working signal, workflow detail is read when authoring a workflow, and deploy-discipline fires from the deployment skill. More to the point of Sumeet's concern: the two topics he flagged now occupy **one sentence each** in the always-on context instead of ~2,000 words combined, so the rules that remain are short enough to actually be followed.

## Relationship to prior records

Supersedes the delivery choice in [2026-06-03-dynamic-workflows-guidance.md](2026-06-03-dynamic-workflows-guidance.md), which put workflows guidance in `rules/workflows.md` as an always-active rule. That record's reasoning ("rules are the only channel that shapes the agent's behavior every session") held for the *guardrail*, which is why the guardrail stays in the constitution — but the full reference did not need to be always-on.
