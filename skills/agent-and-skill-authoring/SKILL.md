---
name: agent-and-skill-authoring
description: |
  Patterns for writing `.claude/agents/*.md` sub-agent definitions and the skills they compose.
  Use when (1) creating a new sub-agent, (2) iterating on an existing agent's frontmatter, body, or
  skill set, (3) deciding what belongs in the agent body vs a skill it composes.
  Covers: frontmatter scope, the identity/mechanics boundary, voice + tightening, soft-gating
  agent-owned skills, "not a gate" closing notes, audit caution.
  Complements the always-loaded rule `agent-definition-edits` (template-first, imperatives, skip
  rationale, hardcode stable values) — this skill goes deeper on architecture and conventions.
version: 1.2.0
---

# Agent + skill authoring patterns

## Frontmatter `description:` is for the parent caller, NOT for describing the agent's internals

The `description:` field is what a *parent* reads to decide whether to dispatch this agent. It is
not where the architecture lives.

- **Test:** would a human invoking this agent need to know this detail to decide whether to call
  it? If no, it's an implementation leak — pull it out.
- **Implementation leaks to delete:** how many rounds the agent runs internally; which models /
  engines it composes; which sub-skills it loads; what its concurrency cap is.
- **Belongs in `description:`:** what the agent is for, when to call it, what to brief it with
  (the contract), what it returns.
- **Rule of thumb:** if changing the agent's internal architecture would force a `description:`
  edit, the description is leaking implementation detail.

## The identity / mechanics boundary

**Agents hold identity; skills hold workflows.** An agent's body says who-it-is and what its
contract with the parent is. The agent *calls into* skills for the mechanical work — specific
vocabularies, procedures, tables, prompt scaffolds. Skills do; agents route.

A sub-agent definition splits cleanly into two layers:

- **Agent body (system prompt)** — identity, briefing contract, role boundaries, output structure,
  voice. The "who am I and what's my contract with the parent" layer.
- **Composed skills** — the workflow mechanics: specific vocabularies, tables, four-bucket
  classifications, round-cap logic, prompt scaffolds. The "how the work gets done" layer.

**Mechanics don't hoist into the agent.** When tempted to move workflow vocabulary into the agent
body for visibility, don't — that's how agent bodies bloat and skills lose their reason to exist.
The right test on every candidate line: *does this define who I am, or how I work?* Identity stays;
mechanics move to the skill.

The agent body should be readable WITHOUT reading the skill files. The skill files should be
readable without reading the agent body. They compose; they don't share substance.

## Ahistorical — speak only of the current state

Agent definitions and skill bodies describe what the system *is*, not what it used to be or what
it will become. Migration notes, "pre-restructure / post-restructure" caveats, "this command is a
planned addition," "until X ships" — all of these belong in `plans/`, not in the asset.

- **No transitional path notes.** If a path will move, write the current path. When the move
  happens, update the path in one pass. Don't carry both.
- **No "planned" or "future" mentions.** Either the thing exists and the skill uses it, or it
  doesn't exist and the skill doesn't reference it.
- **No "this used to be X" caveats.** History lives in `git log` and `plans/`.
- **No conditional paths/branches based on rollout state.** Pick the one that's true now.

Test: would a fresh reader, with no prior knowledge of the project's history, learn anything
useful from the historical aside? If no, delete it. The asset is a description of the present,
not a changelog.

## Voice + tightening

- **Conciseness over completeness.** If a rule can be said in one sentence, don't write three.
  Length is a signal you haven't found the shape yet. Re-read every paragraph: which sentences
  earn their line? Drop the rest.
- **Imperatives, not paragraphs.** Each bullet says what to do. No "we should" or "you might."
- **Skip rationale.** If the template is correct, the *why* doesn't change behavior. Rationale
  belongs in a `decisions/` doc, not the agent def. (See `agent-definition-edits` rule.)
- **Hardcode stable values.** User IDs, channel IDs, paths, emails go in the template, not in a
  runtime lookup. Lookups only when the value genuinely changes over time.
- **Ratchet down layers of indirection.** Start with the simplest form (inline content). Add
  templates / scripts only when duplication becomes painful. Periodically check: can a layer be
  removed because the content has shrunk?
- **Tighten in passes.** A first draft is fine; later passes find the right length. "Do we need
  that second sentence?" is the right question to ask of every paragraph.
- **Use accurate language.** Soft factual claims over hard ones that aren't technically true. A
  skill says "should only be invoked by the X sub-agent" — *not* "is only invocable by X" (any
  caller can try; the constraint lives in convention, not enforcement).

## Soft-gating agent-owned skills

Skills that one agent should own (e.g. `damascus-plan-review` belongs to Damascus): put the
gate-by-convention into the skill's own `description:`:

> *"Should only be invoked by the X sub-agent. [Then the actual skill description.]"*

The mechanism is convention, not enforcement — the language matches the reality.

## "Not a gate" closing notes (for sharpening agents)

If an agent's purpose is **sharpening, not approval** (review, second opinion, devil's advocate),
state it explicitly in a closing-notes / parent-protocol section: this agent's sign-off does NOT
replace human review. The reminder lives in the agent body, not in any one skill, because it
applies across all of the agent's modes.

**One generic note covers all workflows.** Don't write per-workflow versions of the same reminder.
If you're tempted to specialize ("for code reviews, …; for plan reviews, …"), step back and write
the general principle instead.

## Boundaries — the "Don't" list

Be explicit about negative space. A short table in the agent body listing what this agent does NOT
do is high-signal — it's faster to read than reasoning the boundary out from scratch each invocation.

One row per "don't." Keep it imperative; no rationale column (the rationale is the agent's identity,
already established above).

## Skill composition (the agent ↔ skill mechanics)

- **Agent → skill (preload):** the agent's `skills:` frontmatter field loads skill content at
  startup as reference material. The agent's *body* remains the primary behavior driver.
- **Skill → agent (forked context):** a skill with `context: fork` (and optional `agent:`) hands
  its content to an agent as the task prompt — the OTHER direction.
- **Routing / decision logic lives in the agent body**, not in a skill. Skills hold reusable
  procedures that don't vary per invocation; per-invocation routing is the agent's job.
- For a thin orchestrator agent (Cyrano, Damascus, Plutarch): identify the existing skills it
  composes, list them in `skills:`, and the body's job is to *select* the right one and thread
  the inputs/outputs.

## Auditing existing agents — be careful

Audits that bundle multiple kinds of cuts (user-flagged + assistant-judged + style + dedup) get
reverted wholesale, because the bundling makes individual judgments hard to evaluate.

- **Separate user-flagged content from assistant-judged content.** Apply each cut individually so
  the parent can accept/reject per change.
- **Surface every cut.** Show what's being trimmed; don't silently make changes.
- **Default to "leave it" on assistant-judged style.** The bar for cutting assistant-judged content
  is higher than for cutting user-flagged content.
- One small, individually-approvable change beats a sweeping audit every time.

## Naming

Single-word evocative names with a metaphor that fits the role: Cyrano composes for others;
Courier delivers; Damascus sharpens; Plutarch chronicles individual lives one at a time. The name
should be pronounceable + memorable; it shows up in the title prompt the parent sees.

File slug = `<name>.md`. No surprises.
