# Dynamic Workflows: Guidance as an Always-Active Rule

## Context
Claude Code shipped **dynamic workflows** — Claude writes a JavaScript script that orchestrates tens to hundreds of subagents in the background and returns one synthesized answer. The feature is powerful (repo-wide audits, large migrations, cross-checked research, multi-angle planning) but token-heavy: a single run can cost far more than doing the same task in conversation, and `ultracode` mode turns *every* substantive task into one or more workflows.

Prometheus operators are non-technical and build under a simplicity-first constitution. Left unguided, Claude could reach for workflows by default and quietly burn an operator's plan usage, or operators could turn on `ultracode` without understanding the cost. We needed a default policy that both the agent and the team follow.

## Approaches Considered

### Option 1: Always-active rule (`rules/workflows.md`)
Add a rule alongside the constitution and spec. Installed into every operator's `~/.claude/rules/`, loaded every session, and readable prose in the repo for the team.

Tradeoff: one more always-active rule to maintain. But it's the only channel that actually shapes the agent's behavior in every session, and it doubles as team documentation — the same dual-use the constitution and spec already have.

### Option 2: Engineer-only doc (`docs/workflows.md`)
Document the feature for the team in `docs/`, which isn't installed.

Problem: `docs/` doesn't change what Claude does in an operator's session — it only informs engineers reading the repo. The ask was to advise *the agent and the team*; a non-installed doc only does the latter.

### Option 3: Fold into the constitution's "Recurring Tasks and Token Cost" section
That section already reasons about LLM-per-run vs code-per-run cost, which is adjacent.

Problem: workflow guidance is enough material (when-to-use decision table, dynamic vs saved, cost discipline, confirmation rules) to bloat the constitution. Keeping it a sibling rule preserves the constitution's focus while cross-referencing its principle hierarchy.

## Decision
Option 1. Added `rules/workflows.md` as a new always-active rule, registered in the skill-bundle-spec install table and Rules section.

Core policy encoded in the rule:
- **Workflows are not the default.** Normal conversation or a single subagent handles almost everything. Start a workflow only when the task genuinely needs many coordinated agents *and* the operator has opted in (said "use a workflow"/"ultracode", invoked a saved workflow, or is in an `ultracode` session).
- **Dynamic vs saved ("static"):** one-off scripts written for a single task vs scripts saved as reusable `/commands` (parameterized via `args`). Save once the same one-off has run more than a couple of times — mirrors the constitution's code-per-run-when-recurring rule.
- **Cost discipline:** pilot on a slice first, mind the per-agent model, respect that runs count toward plan usage; the concurrency/total-agent caps are a backstop, not a target.
- **Confirmation:** the constitution's rules still apply to what a workflow *does* — confirm before workflows that mutate prod, post externally, or are hard to reverse; read-only and PR-gated workflows stay autonomous.

The user's "static workflow" framing maps to Anthropic's "saved/reusable workflow" — same runtime, the difference is whether the orchestration is written fresh each run or kept as a command. The rule names both so the team isn't confused by the terminology.
