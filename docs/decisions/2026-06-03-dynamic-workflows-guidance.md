# Dynamic Workflows: Guidance as an Always-Active Rule

## Context
Claude Code shipped **dynamic workflows** — Claude writes a JavaScript script that orchestrates tens to hundreds of subagents in the background and returns one synthesized answer. The feature is powerful (repo-wide audits, large migrations, cross-checked research, multi-angle planning) but token-heavy: a single run can cost far more than doing the same task in conversation, and `ultracode` mode turns *every* substantive task into one or more workflows. Prometheus teammates need a default policy that both the agent and the team follow.

## Decision
Guidance lives in `rules/workflows.md` as an always-active rule, alongside the constitution and spec. Rules are the only channel that shapes the agent's behavior every session, and they double as team documentation. Registered in the skill-bundle-spec install table and Rules section.

Policy:
- **Workflows are not the default.** Normal conversation or a single subagent handles almost everything. Start a workflow only when the task genuinely needs many coordinated agents *and* the teammate has opted in (said "use a workflow"/"ultracode", invoked a saved workflow, or is in an `ultracode` session).
- **Dynamic vs saved ("static"):** one-off scripts written for a single task vs scripts saved as reusable `/commands` (parameterized via `args`). Save once the same one-off has run more than a couple of times — mirrors the constitution's code-per-run-when-recurring rule.
- **Cost discipline:** pilot on a slice first, mind the per-agent model, respect that runs count toward plan usage; the concurrency/total-agent caps are a backstop, not a target.
- **Confirmation:** the constitution's rules still apply to what a workflow *does* — confirm before workflows that mutate prod, post externally, or are hard to reverse; read-only and PR-gated workflows stay autonomous.

The user's "static workflow" framing maps to Anthropic's "saved/reusable workflow" — same runtime, the difference is whether the orchestration is written fresh each run or kept as a command. The rule names both so the terminology is clear.
