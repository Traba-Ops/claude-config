# Remove Dynamic Workflows Guidance Entirely

## Context
We shipped dynamic-workflows guidance as an always-active rule ([2026-06-03-dynamic-workflows-guidance.md](2026-06-03-dynamic-workflows-guidance.md)), then trimmed it to a one-line constitution guardrail plus an on-demand reference doc ([2026-06-03-trim-always-on-instruction-bloat.md](2026-06-03-trim-always-on-instruction-bloat.md)). Even trimmed, the feature itself is a massive token sink: a single dynamic-workflow run fans out tens to hundreds of subagents and can cost far more than doing the same task in conversation, and any guidance that keeps the option on the table invites runs we don't want. Subagents on their own are fine — the cost problem is specifically the dynamic-workflows orchestration layer.

## Decision
Remove all guidance for dynamic workflows from the bundle. Concretely:
- Delete `docs/workflows.md` (the reference doc) — it no longer ships to `~/.claude` on install.
- Drop the dynamic-workflows guardrail sentence and reference link from the constitution; rename the section "Recurring Tasks & Workflows" → "Recurring Tasks" (the script-vs-routine rule stays).
- Remove the Workflows row from the skill-bundle-spec install table and the dynamic-workflows clauses from the constitution summary bullet and the on-demand note.

Single subagents and the recurring-task script/routine guidance are unchanged. This is a removal of the dynamic-workflows feature guidance only.

The two prior decision records are left intact as append-only history of what was tried; this record supersedes both for current behavior.
