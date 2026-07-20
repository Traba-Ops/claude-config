---
name: neo-demo-autopilot
description: Fire-and-forget. Build a complete, verified Neo demo from a single use-case brief with no human in the loop — runs planning → building → humanize → critique end to end, auto-answering every question with the recommended default and spawning subagents on the right model for each job. Use when the user says "autopilot a Neo demo", "build me a Neo demo for <prospect> hands-off", "run the whole demo pipeline", or invokes /neo-demo-autopilot.
---

# Neo demo autopilot

This is the hands-off entry point to the Neo demo pipeline. The user hands you **one thing** — a brief about the demo use case — and you drive plan → build → humanize → critique all the way to a ready demo, without stopping to ask anything. The only two places the run halts are honest ones: a brief too thin to build a credible demo (abort gate), or Chrome not connected (browser preflight).

**This skill is a thin orchestrator.** It does NOT re-implement the pipeline. It reuses the three existing skills (`neo-demo-planning`, `neo-demo-building`, `neo-demo-critiquing`) and `humanize` for all the substantive work, and layers on top of them: an **autopilot decision policy** (how to answer every question a human would normally answer), **phase transitions**, **per-phase model assignment**, and four **planning reinforcements** that stand in for the human's judgment. When a phase's logic is needed, point a subagent at that skill's `SKILL.md` and tell it to execute under the autopilot policy — don't paste the logic in here.

Reference build for everything: **`apps/neo-platform/src/demo-mode/sets/cascade-3pl/`** (the dashboards + mock-agents reference). Not `cascade-3pl-finance`.

## The autopilot decision policy (the core)

Every sub-skill is written to interact with a human — audience checks, `AskUserQuestion` iterations, model-switch prompts, sign-off gates, commit-timing control. In autopilot there is no human to answer, so replace each interaction mechanically:

- **Audience check** → never ask. Assume **silent-technical**: no jargon-gating, terse phase-boundary status only, and **auto-commit** (the non-technical commit behavior — there's no human to control commit timing).
- **Every `AskUserQuestion`** → pick the **recommended option** (the sub-skills always list it first). Never render the modal.
- **Planning Section 9 open questions** → resolve each from the brief with the most sensible default. **Defer nothing** — a deferred question has no one to catch it.
- **Sign-off gates** ("are we good on this act?", "one more pass?") → treat as "proceed", but only *after* the phase's own verification/fix loop has actually passed its checks. Autopilot means no human confirmation, not skipped verification.
- **Model-switch / restart prompts** → skip. Subagents are spawned on the right model (or its fallback); the main session's model was resolved in Step 0; Chrome is already confirmed (Step 0 preflight).

Every non-trivial choice this policy makes gets one line in the decision log (Step 7) with its reasoning — hands-off must never mean opaque.

## Model + thinking pipeline

The orchestrator runs on **Opus 4.8** (main session). It cannot switch the session model, so Step 0 checks it. Cross-model work runs as **subagents with explicit `model:` overrides**, chosen to balance quality against cost:

| Stage | Model | Runs as | Why this model |
| --- | --- | --- | --- |
| Orchestration, gap gate, phase transitions | Opus 4.8 | main session | the mandated spine; also what build + critique want |
| Brief extraction (Phase 0) | **Sonnet 5** | subagent, `model: "sonnet"` | near-mechanical structured pull — no reason to pay premium |
| Planning drafts ×2 (Phase 1) | **Fable 5** | 2 parallel subagents, `model: "fable"` | pure judgment; sets the ceiling for everything downstream |
| Judge + prospect red-team (Phase 1) | **Fable 5** | subagents, `model: "fable"` | selection + believability are the discriminating judgment |
| Building (Phase 2) | Opus 4.8 | main session | needs the browser + is coding work; no model hop |
| Humanize (Phase 2.5) | **Fable 5** | subagent, `model: "fable"` | voice quality is the whole point of the pass |
| Critique loop (Phase 3) | Opus 4.8 + its own Fable / fresh-Opus subagents | main session | the skill already stages its own models — let it |

Fable is used only in short, token-cheap bursts (drafts, judge, red-team, humanize). The token-heavy phases (build, critique) stay on Opus. Draft count is capped at **2** to hold the N-multiplier cost — bump to 3 only if the user asks.

**Model fallbacks (the user may not have every model):**
- **No Fable 5** → spawn the judgment subagents (planning drafts, judge, red-team, humanize) on **`model: "opus"`** and **force `ultrathink`** in their prompts — the extra reasoning budget stands in for Fable's judgment edge. Log the substitution in the decision log.
- **No Sonnet 5** → run brief extraction on **`model: "opus"`** (or Haiku 4.5 if present) — it's near-mechanical, so no effort bump needed.
- **No Opus 4.8** (orchestrator + build) → this is the one that hurts; run the whole main session on the strongest coding model available (Sonnet 5, else Haiku 4.5), warn in the first decision-log line that quality is capped, and keep going. Don't abort a hands-off run over a model gap.

**Thinking effort:** ultrathink instruction goes in the Fable (or Opus-fallback) judgment subagent prompts (planning drafts, judge, red-team, humanize — that's where judgment lives). Standard for the orchestrator's mechanical plumbing; think hard on the gap-gate decision and on any math the build or critique surfaces.

## Step 0 — Preflight (model + browser), before anything else

Browser is a hard gate; model is a preference with a fallback. Check both up front.

1. **Model.** Prefer the main session on **Opus 4.8**. If it's on a *higher* model (Fable 5), keep it. If the user *has* Opus 4.8 but isn't on it: "Autopilot runs best on Opus 4.8 — type `/model`, pick *Opus 4.8*, then re-invoke `/neo-demo-autopilot`." If the user simply doesn't have Opus 4.8, **don't stop** — apply the no-Opus fallback from the model pipeline above (strongest coding model available, quality-capped warning in the log) and continue. Judgment/extraction subagents follow their own fallbacks. Record whatever model the session actually is so the per-phase spawns pick the right overrides.
2. **Browser (unattended CDP bridge).** Build + critique drive a logged-in browser over **playwright-cdp** — a persistent bot Chrome profile (`neo-catalog` on `:9222`) that holds a Firebase session. Run `browser/preflight.sh` (in this skill dir); it **self-provisions** the driver deps, so a recipient who just unzipped the skills needs no manual setup:
   - `READY` → proceed fully unattended.
   - `NEEDS_SERVER` → start `pnpm start-dev-neo`, re-run.
   - `NEEDS_DEPS` → a dependency the preflight can't install itself is missing — either the `playwright-cdp-drive` sibling skill isn't in `~/.claude/skills` (unzip all folders), or `npm` isn't on PATH (install Node 22.22). The message says which. Fix and re-run.
   - `NEEDS_LOGIN` → the bot profile has never been logged in (or the session was revoked). This is the **one-time** human touch: a Chrome window is open on `:9222` at the login page — the user logs into neo-platform once (`@traba.work`, a dev-company account); Firebase's default `browserLocalPersistence` then persists it across restarts + auto-refresh, so every future run is `READY`. In true fire-and-forget with no user present, proceed with build-authoring and **defer the visual critique** (log it), rather than stop.

   The bridge (`browser/`): `preflight.sh` (deps+server+chrome+login health), `setup.sh` (idempotent one-time provisioning — verifies the `playwright-cdp-drive` sibling skill and installs `playwright-core` into `~/.chrome-cdp-profiles/.pw`; no browser download, the driver attaches to the user's existing Chrome), `launch-bot-chrome.sh` (idempotent bot Chrome via the `playwright-cdp-drive` launcher), `login-health.js` (LOGGED_IN/OUT probe), `drive-demo.js` (gate-adaptive walker — clicks Approve at `await-approval-resolved` gates, sends an affirmative at `await-user-prompt` gates, screenshots each step to disk, watches for backend POSTs). All scripts resolve `playwright-core` from `~/.chrome-cdp-profiles/.pw` via `os.homedir()`, so they're portable across machines.

Only when model + browser pass do you take the input.

## Step 1 — Locate the sibling skills + take the input

**Locate the reused skills.** They live beside this one. Find the absolute paths (search `~/.claude/skills`, `~/.config/claude/skills`, and any project `.claude/skills`), and record them:
- `neo-demo-planning/SKILL.md`
- `neo-demo-building/SKILL.md`
- `neo-demo-critiquing/SKILL.md` (+ its `rubric.md`)
- `humanize/SKILL.md`

You pass these absolute paths into subagent prompts ("read this file and execute it under the autopilot policy"). If any is missing, tell the user which one and stop — the pipeline can't run without it.

**Take the input.** The user gives one brief on the demo use case — a paste, a link (fetch if you have the MCP), or a file path. Same clean-doc rule as planning: it must be a single source dedicated to this one demo. Don't go hunting for it. This is the *only* input the run needs.

**Open the decision log** at `docs/demos/<slug>-autopilot-log.md` (slug derived once the prospect is known) and append to it at every phase boundary.

## Step 2 — Phase 0: Intake & gap gate

The one non-negotiable gate. Fire-and-forget dies on a thin brief, so bounce it fast rather than autopilot a fictional demo.

1. **Extract** — spawn a **Sonnet** subagent: pull the brief into a structured fact sheet — prospect, **annual revenue band**, pain points, the data source behind each pain point, personas, any stated punchline / time budget. Return it as structured markdown; flag every field it could not find.
2. **Gap-gate decision** (orchestrator, Opus, think hard). Two classes of essential, handled differently:
   - **Scale / identity anchor — prospect name + annual revenue band.** If **both** are missing, do **not** abort — **default to the Cascade 3PL persona**: ~$165M annual revenue, COO **Jordan Castillo**, 4 fulfillment centers (Indianapolis HQ, Atlanta, Reno, Charlotte), ~280 FTE, 68 DTC brand customers, ShipHero Enterprise + NetSuite + Google Workspace + Slack — the canonical mid-market 3PL that matches the built `sets/cascade-3pl/`. If only one of the two is present, keep it and fill the other from the Cascade default. Either way, log the default loudly and tag every number it anchors `[assumed: Cascade 3PL default]`.
   - **Use-case substance — ≥2 concrete pain points, each with a data source.** This is the real non-negotiable: it's what the demo is *about*, and nothing downstream can invent it honestly. If it's missing → **ABORT**, naming exactly what's absent ("only one pain point"; "no data source behind the returns pain point"). This is the sole early stop in the run.
   - **Persona** — use the brief's own if present, else Cascade's Jordan Castillo.
3. On pass (or Cascade default), write the fact sheet + any applied defaults into the decision log and proceed. Numbers the brief doesn't pin down are allowed downstream **only** as labeled assumptions (Phase 1 ledger), never as silent invention.

## Step 3 — Phase 1: Planning (the four reinforcements)

Reuse `neo-demo-planning/SKILL.md`, but only its substance — the 9-section structure, per-act detail template, scale-sanity check, talk-track separation, and heuristics. Skip its Steps 0/1/3/4 (audience check, intake, interactive walk, handoff) — those are the human shell the reinforcements replace.

1. **Best-of-2 drafts** — spawn **2 Fable subagents in parallel** (ultrathink). Each reads the planning skill + the fact sheet and drafts a full 9-section plan to its own scratch path (`<scratch>/<slug>-draft-1.md`, `-2.md`) — **not** the canonical path yet. Each also emits an **assumptions ledger**: every fact and number tagged `[from brief]` or `[assumed: <reasoning>]`. *(Replaces human iteration.)*
2. **Judge** — after both return, spawn a **Fable subagent** (ultrathink): read both drafts against the scale-sanity + story-arc bar, pick the stronger or synthesize the best of each, and write the winner to `docs/demos/<slug>.md`. Merge the winning ledger. *(Replaces the human reacting to the strawman.)*
3. **Prospect red-team** — spawn a **Fable subagent** (ultrathink, read-only): read the chosen plan **as the buyer named in the brief** ("VP Ops at a $X 3PL — what's the scale error, the story hole, the number I won't believe?"). Return findings only. *(Replaces the human's believability gut-check, before any code exists.)*
4. **Fix pass** — orchestrator (Opus) applies the red-team's findings to `docs/demos/<slug>.md`. Catching a scale/story miss here is ~10× cheaper than after it's built.

Log: which draft won and why, the merged assumptions ledger (flag any load-bearing `[assumed]`), and the red-team findings + fixes.

## Step 4 — Phase 2: Building

Run **in the main session** (Opus, has the browser — no subagent hop). Point yourself at `neo-demo-building/SKILL.md` and execute it under the autopilot policy: silent-technical, auto-commit per act, every act sign-off treated as "proceed" *after* its verification+fix loop passes. Build acts → insights → dashboards → agents exactly as the plan calls for. Hold `data.ts` as the single source of truth, run the math audit on every $-claim, and do the per-act browser verification for real (autopilot skips the *asking*, never the *checking*). Log any build-time decision the policy made (a resolved plan ambiguity, an element substitution).

## Step 5 — Phase 2.5: Humanize the script

Placed between build and critique on purpose — the critique loop then re-verifies voice, pacing, and numbers, so nothing the rewrite touches slips through.

Spawn a **Fable subagent**: read `humanize/SKILL.md` and apply it to the demo's **prose copy only** — `text-delta` / `text-block` bodies, closing cues, and `insights.ts` copy. It must **never** touch numbers, element structure, `proposalId`s, event order, or `delayMs`, and must keep the ops voice (short, concrete, no emoji, no slop). It returns edited copy; the orchestrator applies it, then re-runs typecheck + lint and spot-checks that no number changed. Log a one-line summary.

## Step 6 — Phase 3: Critique loop

Run `neo-demo-critiquing/SKILL.md` in the main session under the autopilot policy. It already stages its own models (Opus convergence + browser walk, one Fable fresh-eyes pass, a fresh-Opus verifier) — let it.

**Drive the browser walk with `browser/drive-demo.js` over CDP** (not claude-in-chrome). It's gate-adaptive and self-terminating: `SET_ID` + `TRIGGER` (+ optional `AFFIRM`, `MAX_STEPS`, `OUT_DIR`) → it fires the trigger, then at each pause clicks Approve (approval gate) or sends the affirmative (user-prompt gate), screenshots every step to disk, and stops at the first backend POST (script end / fall-through). This both produces the disk-screenshot evidence the critique rubric needs AND deterministically catches the "dropped to the real agent" class (a POST to `/neo/web-chat-init` mid-walk = fall-through). It also sidesteps the react-virtuoso scroll-follow blank-frame that makes claude-in-chrome unreliable (Playwright scrolls + queries the DOM directly). **Known real finding to check on every demo:** closer cues phrased as questions ("Want X?") at an `await-approval-resolved` gate — a demoer who *types* instead of clicking Approve falls through to the real agent; verify the cue points at the Approve action or the gate tolerates a typed prompt. The one autopilot change: its final **Tier-3 taste calls** are **auto-resolved** with best judgment (use the plan as the intent oracle) instead of escalated via `AskUserQuestion` — and each resolution, with its reasoning and evidence pointer, goes into the decision log. Let its Step 9 rubric self-update proposals surface in the log for the user to confirm later; don't apply durable rubric edits unattended.

## Step 7 — Decision log + handoff

Autopilot exits with the demo in a ready state and a single artifact the user can skim in ~2 minutes. Finalize `docs/demos/<slug>-autopilot-log.md` with, in order:

- **Intake** — the fact sheet + gap-gate verdict.
- **Assumptions ledger** — every `[assumed]` fact/number, load-bearing ones flagged.
- **Planning** — winning draft + why, red-team findings + fixes.
- **Autopilot choices** — every recommended-default and resolved-open-question the policy picked.
- **Tier-3 calls** — each auto-resolved taste call with reasoning + the frame it's based on.
- **Evidence** — pointers to the critique loop's readiness report, numbers worksheet, and per-act recordings.
- **For your review** — anything the user should sanity-check or override (load-bearing assumptions, close red-team/Tier-3 calls, any rubric self-update proposals).

Then report done with the log path and a two-line summary. This is hands-off, not a black box — the log is where the user reasserts control.

## Constraints

- **Never `--no-verify` on commits**, never skip hooks. Never commit on failing typecheck/lint — fix first.
- **Autopilot skips the asking, never the verifying.** Every browser walk, math audit, and fix loop the sub-skills prescribe still runs in full.
- **The two hard stops are sacred.** Abort a thin brief; stop on a missing browser. Never build on invented essentials to avoid stopping.
- **Never silently invent a load-bearing number.** Anything not in the brief is a labeled `[assumed]` entry in the ledger, surfaced for review.
- **Subagents that judge don't edit; the orchestrator edits.** Drafts, judge, red-team, humanize return artifacts/findings; code and plan edits land in the main session (or the humanize application step).
- **One prospect per run.** The branch model doesn't support two in parallel.
- **This skill's job ends at the local commits + decision log.** Sharing/deploy is out of scope.

## Pitfalls

- **Duplicating the sub-skills' logic into this file.** This skill carries policy, transitions, and models — not the 9-section structure or the rubric. If you're tempted to paste build/critique steps here, point a subagent at the real `SKILL.md` instead. The reused skills stay the source of truth (and stay usable interactively on their own).
- **Skipping Step 0 and discovering mid-run you're on the wrong model or have no browser.** Both are unrecoverable without a restart; check them before touching the brief.
- **Letting "fire-and-forget" erode into "unverified."** The value is in still running every check autonomously. A demo that autopiloted past its own math audit is worse than one that stopped.
- **Aborting on a missing scale anchor instead of defaulting.** Missing prospect + revenue is *not* an abort — it defaults to the Cascade 3PL persona (~$165M, Jordan Castillo). The only Phase 0 abort is missing **use-case substance**: fewer than two pain points, or a pain point with no data source. That's the one gap no downstream judgment can honestly recover.
- **Running the drafts serially or on Opus.** They're parallel Fable subagents; serial wastes wall-clock and Opus wastes the judgment edge Fable brings to planning.
- **Humanize touching numbers or structure.** Constrain it to prose. Then re-verify — a rewrite that "improved" a sentence into a different number is a credibility bug the critique loop shouldn't have to catch.
- **Burying the taste calls.** Tier-3 auto-resolution is a convenience, not a cover-up. Every one lands in the log with its reasoning so the user can override.

## Worked example

The three sub-skills' own worked examples apply. For the *shape of the output*, the fully-verified reference is Republic Services on the `neo-demo` branch; the reference for a set with dashboards + mock agents is `apps/neo-platform/src/demo-mode/sets/cascade-3pl/`. A completed autopilot run leaves both the usual per-slug artifacts (`docs/demos/<slug>.md`, `<slug>-verify.md`) and its own `docs/demos/<slug>-autopilot-log.md`.
