# Authoring Rules: what earns a slot in every session

Read this before adding to or editing anything in `rules/`. It's the bar a rule must clear, and the reasoning behind it. Goal: keep the always-on framework short, prescriptive, and actually followed.

## Why this matters (the evidence)

Adding rules is not free. Instruction adherence **degrades** as you add more — and the rules you already have get followed *less*, not just the new one.

- All frontier models drop below ~90% adherence somewhere between **150–250 simultaneous instructions**; whole-prompt compliance collapses far earlier (one benchmark: 0.94 → 0.21 going from 1 to 10 instructions). [IFScale](https://arxiv.org/abs/2507.11538), [ManyIFEval](https://arxiv.org/abs/2509.21051)
- Long context is itself a tax ("context rot"): recall and instruction-following degrade as tokens grow, and similar-but-irrelevant text actively misleads. [Chroma](https://www.trychroma.com/research/context-rot)
- Anthropic says it directly: **"Bloated CLAUDE.md files cause Claude to ignore your actual instructions"**; important rules "get lost in the noise." Target **under ~200 lines** per always-on file, and prune ruthlessly. [Claude Code best practices](https://code.claude.com/docs/en/best-practices), [memory](https://code.claude.com/docs/en/memory)
- Earlier instructions are followed better (primacy). Order matters.

The takeaway: every low-value always-on line statistically dilutes a load-bearing one — like the security gates. Discipline here is a safety feature, not just tidiness.

## The keep test — all three, or it doesn't go always-on

1. **Universal** — applies to *every* session, not just when building, deploying, co-working, or doing one kind of task. Conditional guidance fails this.
2. **Non-inferable** — Claude gets it wrong without it. Not something a linter enforces, not what the base model already does, not a self-evident practice ("write clean code").
3. **Instruction, not documentation** — a directive Claude acts on, not an explanation of how a feature works or why. Rationale belongs only on genuine judgment calls.

Fail any one → it's not an always-on rule. Route it:

| If it's… | Put it in… |
|---|---|
| A procedure triggered by a situation (co-working, a specific workflow) | a **skill** (`skills/<name>/SKILL.md`) — loads on its trigger |
| Guidance for one file type or path | a **path-scoped rule** (`paths:` frontmatter, like `design-system.md`) |
| Reference / explanation / "how the feature works" | a **doc** (`docs/*.md`) — read on demand, never auto-loaded |
| Something a linter, hook, or CI can enforce | the **tool**, not prose |

Note: imports (`@path`) do **not** save context — imported files still load in full at launch. Moving content to a skill or doc is what actually removes it from the per-session budget.

## Writing the rules that do stay

- **Imperative, not prose.** "Write a script" beats a paragraph explaining LLM-vs-script trade-offs. One rule per line.
- **Specific and testable.** "Default to the prescribed stack (TypeScript · Hono · React/Vite · bun)" beats "use modern tooling."
- **Highest-priority first.** Lead with the priority hierarchy and security; primacy means those get the best adherence. Reference-y sections go lower.
- **Positive imperatives** where possible — "do X" is followed more reliably than tracking a list of "never Y." Reserve "never" for hard gates (security), where it belongs.
- **Pointers, not copies.** Link to the skill/doc/`file:line` that holds the detail; don't inline it into every session.
- **Rationale only on judgment calls.** A mechanical rule needs none; a "use your judgment about X" rule needs the why so Claude can resolve cases the rule didn't name.
- **Emphasis is scarce.** `IMPORTANT` / `YOU MUST` raise adherence but only while rare. Don't bold half the file.

## The per-line test, and a check

For each line, ask Anthropic's question: **"Would removing this cause Claude to make mistakes? If not, cut it."**

After editing, open a fresh session and ask Claude to summarize the always-on rules. If it can't, they're too long — keep cutting.

## Sources

[IFScale](https://arxiv.org/abs/2507.11538) · [ManyIFEval](https://arxiv.org/abs/2509.21051) · [Chroma "Context Rot"](https://www.trychroma.com/research/context-rot) · [Claude Code best practices](https://code.claude.com/docs/en/best-practices) · [Claude Code memory](https://code.claude.com/docs/en/memory) · [Effective context engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)
