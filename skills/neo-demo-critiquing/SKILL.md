---
name: neo-demo-critiquing
description: The Neo demo verification LOOP. Drives every turn of a built demo in a real browser, checks numbers/logic/pacing/visuals/believability against a tiered rubric, auto-fixes cosmetic issues and re-runs to convergence, then runs a staged final gauntlet (Fable 5 fresh-eyes judgment pass → Opus 4.8 final fix → fresh Opus 4.8 verification). Escalates only the irreducible product-judgment calls to the operator. Exits with the demo in a ready-to-use state plus evidence artifacts (readiness report, numbers worksheet, per-act recordings). Use after neo-demo-building, or any time to harden a demo before showing it.
---

# Neo demo verifying (the loop)

This skill takes a built demo and drives it to a **ready** state — credible, numerically
airtight, and delightful turn-by-turn — while touching the operator only for the handful of
calls a machine genuinely can't make. It replaces the old "one static pass" critique with a
converging loop plus a staged final gauntlet: converge (Opus) → judge fresh (Fable) → fix
(Opus) → verify fresh (Opus).

## The promise (and its honest boundary)

- **Numbers and cross-surface consistency** — the loop owns fully. Never reaches the operator.
- **Turn-by-turn** (pacing, order, scroll-follow, layout, cues fire, no dead-ends) — the loop
  owns via a real browser + rubric, auto-fixing cosmetic issues.
- **Believable / logic holds / delightful for this buyer** — taste. The loop can't own it; it
  *shrinks* it to a short flagged list + one ~2-min recording to watch.

When the loop exits, every mechanical and perceptual dimension is green **with evidence
attached**, the product-judgment calls are surfaced and resolved, and there's a recorded
walkthrough for the final spot-check. No dimension is ever marked green without an artifact.

## The rubric

All checks live in `rubric.md` (next to this file) as rows tagged by tier. **Add a new aspect
by adding a row there, not by editing this skill.** Tiers route the work:

- **Tier 1 — Deterministic**: scripted / grep-able. Auto-fix trivial, hard-fail the rest.
- **Tier 2 — Perceptual**: judged against captured browser evidence. Cosmetic auto-fixes;
  structural routes back to `neo-demo-building`.
- **Tier 3 — Product judgment**: escalated to the operator, batched, with evidence.

Read `rubric.md` in full at the start of every run — it may have grown since last time (see
**Step 9 — Self-update**).

## Model + thinking pipeline

Verification is staged across two models: **Opus 4.8** does the mechanical + perceptual work
and all code fixes; **Fable 5** supplies one deep fresh-eyes judgment pass on the converged
demo. A skill can't switch the main session's model — check it, ask the user to `/model` when
mismatched, and run cross-model stages as **subagents with explicit `model:` overrides**.

| Stage | Model | Runs as | Thinking effort |
| --- | --- | --- | --- |
| Orchestration, Tier-1 gate, capture (Steps 2–3b) | Opus 4.8 | main session | low — mechanical, evidence-driven |
| Tier-2 perceptual judge (3c) | Opus 4.8 | main session | think hard — judgment against frames |
| **Design tier — Layer 1** DOM layout probe (3c-design) | Opus 4.8 | main session (driver) | low — deterministic overflow/clip/alignment |
| **Design tier — Layer 2** adversarial design critique (3c-design) | **Fable 5** | subagent, `model: "fable"`, read-only | think hard — picky design director |
| Cosmetic auto-fixes, each iteration (3f) | Opus 4.8 | main session | standard |
| **Final pass** — Tier-3 skeptic + fresh-eyes sweep (Step 5) | **Fable 5** | subagent, `model: "fable"`, read-only | **ultrathink** |
| **Final fix** — apply the Fable findings (Step 6) | Opus 4.8 | main session | standard; think hard on subtle fixes |
| **Last verification** (Step 7) | Opus 4.8 | **fresh** subagent, `model: "opus"` (use the `verifier` agent type if the repo has one) | standard — scoped, evidence-based |

- **Model check (before Step 0):** the main session should be **Opus 4.8**. If it isn't, ask
  the user to switch via `/model` before starting. If the user has no Opus 4.8, don't stop —
  run on the strongest model they have and note it.
- **Fable fallback (applies to every `model: "fable"` subagent below):** if Fable 5 isn't
  available in this environment, spawn those judgment subagents on **`model: "opus"`** instead
  and **raise their thinking effort to `ultrathink`** — the extra reasoning budget is how Opus
  stands in for Fable's judgment edge. Note the substitution in the readiness report so the
  reader knows the fresh-eyes pass ran degraded. The two independent-judgment stages (Step 5
  fresh-eyes, Step 7 verifier) must still both run and cite evidence — the gate is about
  independence, not the model name.
- **Why Fable runs once, at the end:** judgment on a *stabilized* demo is worth far more than
  judgment re-run every iteration on a moving target — and by then the loop has cleared
  everything mechanical, so Fable's pass is pure taste + believability.
- **Why the last verifier is a fresh instance:** the fixer shouldn't grade its own homework.
  Same *model* is fine — the check is mechanical and every verdict must cite evidence (frames,
  arithmetic), which doesn't depend on which model looks at it.

## Orchestration — durable run manifest (survives context loss)

A full run is long; the model's context gets summarized and early state is lost. So **run-state
lives in a file, not in the model's head.** Write a manifest at `docs/demos/<slug>-verify.manifest.json`
and treat this skill as a resumable state machine over it.

Each tick: **read the manifest → pick the first not-passed step whose deps are met → run it → write
the result back.** Steps are idempotent (re-running a passed step is a no-op). Per-step checkpoint =
a git commit **and** a manifest update, together. Give every step a timeout + one retry, and a
health-check on its dependencies (browser reachable, dev server up on its port, subagent returned)
before running. On repeated failure, record the step `failed` with its evidence pointer and
**continue to the next runnable step or escalate — never wedge the whole run** on one stuck step.

Support `--resume <slug>`: if the manifest exists, rebuild state from it and continue from the first
not-passed step instead of restarting. This is what lets a summarized/interrupted run pick up cleanly.

Manifest schema/template (statuses: `pending` | `running` | `passed` | `failed`):

```json
{
  "slug": "sku-master-data-auditor",
  "startedAt": "2026-07-11T00:00:00Z",
  "headSha": "<snapshot SHA from Step 2>",
  "steps": [
    { "id": "1-target", "status": "passed", "deps": [], "evidence": "docs/demos/<slug>.md", "attempts": 1 },
    { "id": "2-harness", "status": "passed", "deps": ["1-target"], "evidence": "port:4203", "attempts": 1 },
    { "id": "3a-tier1", "status": "running", "deps": ["2-harness"], "evidence": null, "attempts": 1 },
    { "id": "3b-walk", "status": "pending", "deps": ["3a-tier1"], "evidence": null, "attempts": 0 },
    { "id": "3c-tier2", "status": "pending", "deps": ["3b-walk"], "evidence": null, "attempts": 0 },
    { "id": "3c-design", "status": "pending", "deps": ["3b-walk"], "evidence": null, "attempts": 0 },
    { "id": "5-fable", "status": "pending", "deps": ["3c-tier2", "3c-design"], "evidence": null, "attempts": 0 },
    { "id": "6-fix", "status": "pending", "deps": ["5-fable"], "evidence": null, "attempts": 0 },
    { "id": "7-verify", "status": "pending", "deps": ["6-fix"], "evidence": null, "attempts": 0 }
  ],
  "rubric": [
    { "row": "layout-integrity", "tier": 1, "status": "pending", "evidence": null, "findings": [] },
    { "row": "approvals-no-auto-resolve", "tier": 1, "status": "pending", "evidence": null, "findings": [] },
    { "row": "cue-invited-scripted", "tier": 1, "status": "pending", "evidence": null, "findings": [] },
    { "row": "design-quality", "tier": 2, "status": "pending", "evidence": null, "findings": [] },
    { "row": "brevity", "tier": 2, "status": "pending", "evidence": null, "findings": [] }
  ]
}
```

Track **both** per-step and per-rubric-row status, each with an evidence pointer (a frame path, the
arithmetic, a subagent's findings) and any findings. "Ready" (Step 8) reads this file, not memory —
every step `passed` and every critical/high rubric row `passed` with evidence, or the run isn't ready.

## Step 0 — Audience check (always first)

Same as the other neo-demo skills. Ask verbatim:

> Before we start: are you comfortable with terms like *git branch*, *dev server*, *file path*, *pnpm command*?
>
> — **Technical**: I know these. Keep your updates brief.
> — **Non-technical**: handle the technical bits for me. Just ask product/story questions.

Save the answer in a TodoWrite item and apply mode-aware reporting throughout. In non-technical
mode, the operator's whole interaction is: answer the batched Tier-3 questions, watch the
recordings, and wave through or fix the low-severity backlog.

## Step 1 — Find the target + load the intent oracle

Ask which prospect slug to verify. Read everything for it (paths per `rubric.md`'s references):
`sets/<slug>/index.ts`, `insight.ts`, `scripts/*.ts`, `dashboards/*` + `data.ts`, `mockJobs.ts`,
`demo-mode/insights.ts`, and **`docs/demos/<slug>.md` — the plan, which is the intent oracle.**
Every check is "does the rendered demo match the signed-off plan + the rubric." If a plan-declared
surface is missing, the demo isn't built — route back to `neo-demo-building`.

## Step 2 — Set up the harness

- **Git snapshot** so auto-fixes are reversible (note the current SHA).
- **Dev server** up (find the port from `package.json` / `vite.config.mts`; typically `4203`).
- **Browser driver: the `playwright-cdp-drive` skill.** Use it — not Chrome MCP — for the
  turn-by-turn walk. It drives the operator's already-logged-in Chrome over CDP and, critically,
  **saves screenshots to disk as real files**, which is what makes the evidence artifacts and the
  Tier-2 judge possible on long unattended runs. Load it now.
- **The driver lives at `neo-demo-autopilot/browser/drive-demo.js`** and now emits, per act, a
  **DOM layout report** (overflow/clip/truncation/alignment measurements — the Tier-1 layout-integrity
  probe) and **zoomed per-element frames** at real render width. The Layer-1 design probe reads the
  layout report; the Layer-2 design critique (Step 3c-design) reads the per-element frames.
- Confirm demo mode is on and the target set is selected (Settings → Demo mode).

## Step 3 — The convergence loop (Opus; one iteration)

Run these in order. Everything auto-fixable is fixed and re-verified in-loop; only structural
items leave the loop, and Tier-3 waits for the Fable pass.

### 3a. Tier-1 gate (deterministic; low effort)
Run every Tier-1 row. Auto-fix the trivial (a number that should read from `data.ts`, a missing
`formatDemoApprovalSuccess` case, an unregistered set). Hard-fail the rest with the evidence
(the arithmetic, the mismatched strings). **Gate: Tier-1 must be green before spending browser
time** — no point judging pacing on a demo whose numbers are wrong.

### 3b. Turn-by-turn capture (browser) — drive it like a demoer, not a playback

With `playwright-cdp-drive`, walk **every** script trigger and **every** follow-up path. For each
beat capture: a **screenshot to disk**, a **timestamp** (for pacing), a **DOM snapshot**, and
**what fires next**. Record a **GIF/video per act**. This transcript is the evidence base for 3c
and Step 5 — the judges read *it*, never the source (source lies about what actually rendered).

**Content bugs show in a still frame; interaction/lifecycle bugs do not.** A re-typing text
block, a missed act-to-act transition, a hang, a silent fall-through to the real agent — none of
these appear in a forward sequence of screenshots. They only surface when the walk *performs the
action a demoer performs* and captures the result as motion. So the walk is **not** a linear
forward playback; it MUST include these interaction probes, each recorded as a short clip:

1. **Cold start.** Clear demo state first — `localStorage.removeItem('neo_demo_approval_resolutions')`
   and `neo_demo_sessions`, reload. Persisted approvals/sessions from a prior run mask the
   fresh-resolve code path (this is exactly how the terminal-approval hang hid). Every walk
   starts from clean state.
2. **Natural-language reachability, NOT slash jumps.** Reach each script from a fresh chat by
   typing one of its real `triggers` — a natural phrase a demoer would say. `/demo <id>` is for
   capturing an *isolated beat*; it must never be how you test the **navigation graph**, because
   slash commands bypass the entire trigger/followUp matcher — the code most likely to be broken.
3. **Perform the interaction the cue INVITES — never adapt the harness to force a pass.** At each
   `await-*` pause, read the cue and do what it asks: a **question-phrased** cue → *type* a reply;
   a **button CTA** → *click* it. Confirm the *next scripted beat* plays — not a real-agent reply,
   not a backend POST. A POST to `/neo/web-chat-init` on that natural interaction is a CRITICAL
   fall-through (route to building). The driver must **not** switch interaction modes (e.g. click
   when the cue invites a typed reply) to make the demo pass — that masks the bug rather than
   catching it. This is the followUp/navigation path; it is invisible if you slash-jump.
4. **Act-to-act via the closer's affirmative.** At each `await-user-prompt` that bridges acts,
   type a plain affirmative to the closer ("yes", "show me") and confirm the *next script* plays
   — not a real-agent reply. Then separately confirm topic words ("the 90 days", "all carriers")
   also bridge.
5. **Approvals: assert PENDING before clicking, THEN click and verify the after-state — on fresh
   state, including the script's terminal one.** *First*, screenshot each approval card **before any
   click** and assert it is pending: action buttons live, NO post-approval / after-state text in the
   DOM, and the script has NOT advanced on a timer. An auto-resolved card (after-state pre-click or a
   timed advance) is a CRITICAL auto-approve bug. *Then* click Approve (and, once per set, Deny) and
   watch the after-state: the success message renders, the post-approval reveal shows, the input goes
   **idle** (send arrow + chips, no spinner), and NO empty "Thinking…" bubble hangs. Approving the
   *last* action of a script is the highest-risk moment — a script ending on `await-approval-resolved`
   is where the phantom-message hang lives.
6. **Scroll back up after each act, then back down.** The message list is virtualized
   (react-virtuoso): rows unmount off-screen and remount on return. Immediately screenshot a
   remounted text block / card and confirm it renders **fully, statically** — no re-typing, no
   re-firing entrance animation. A forward-only walk never remounts anything, so this class is
   invisible without the explicit scroll-back.
7. **Watch the network + console the whole time.** With demo mode on, a correct scripted walk
   makes **zero** backend chat calls. Read network requests after each act; any POST to
   `/neo/web-chat-init` (or console errors) means the demo fell out of scripted mode — a
   deterministic signal that catches the entire "dropped to the real agent" class (missed
   followUp, terminal-approval hang) without relying on perception. See the Tier-1 row.

When a foundational primitive changed in the last `main` sync (list virtualization, routing, the
agent data source), give its probe extra weight — that's where the regression class lives.

### 3c. Tier-2 judge (perceptual; think hard)
Run every Tier-2 row against the captured frames/timings. Each finding cites its frame or timing
number. No "looks fine" without an artifact.

### 3c-design. Design tier — two layers ("renders" ≠ "looks good")
A demo that compiles and renders can still be *ugly* — poor hierarchy, cramped density, ragged
alignment. That's a defect the old loop never judged. Design quality is now its own tier, in two
layers, run every convergence iteration:

- **Layer 1 — deterministic DOM layout probe (driver, hard-fail).** From the driver's layout report
  (`neo-demo-autopilot/browser/drive-demo.js`), assert the Tier-1 layout-integrity row: no
  `scrollWidth > clientWidth` on clip/scroll/hidden-overflow elements, no unintended truncation,
  everything within container bounds, columns aligned, numeric columns right-aligned + `tabular-nums`.
  Any hit hard-fails and routes like any Tier-1 miss. This layer needs no taste — it's measured.
- **Layer 2 — adversarial design critique (dedicated Fable subagent, read-only).** Spawn a
  **separate** read-only subagent with `model: "fable"` (this is NOT the general fresh-eyes pass and
  NOT the Tier-2 judge). Frame it adversarially: *"You are a picky design director. Assume this is
  flawed. Enumerate every visual flaw with a severity."* Arm it with the `traba-design` standard, a
  **shipped reference element** (a `cascade-3pl` dashboard card as the known-good bar), and the
  driver's **zoomed per-element frames at real render width**. It returns **findings only** (no code
  edits) — hierarchy, spacing/padding rhythm, table/row density, alignment, on-design-system,
  contrast, each with a severity. High-severity design flaws block exit.

Iterate to convergence: fix → re-render → re-critique, budgeting 2–3 rounds per new element. A
high-severity design finding is structural-adjacent — don't paper it over with copy; fix the element.

### 3d. Tier-3 observations (log, don't escalate yet)
While judging, note anything that smells like a believability / story / framing problem in a
running **Tier-3 observations list** — but don't run the full skeptic here and don't bug the
operator mid-convergence. The authoritative Tier-3 pass is the **Fable 5 final pass (Step 5)**,
which takes this list as one of its inputs.

### 3e. Aggregate + classify
Dedupe across gates. Tag each finding:
- **cosmetic** — copy in `text-delta`/`text-block`, `delayMs`, event/element order, `insights.ts`
  copy, `discussPrompt`, `formatDemoApprovalSuccess` copy, a number that should read from `data.ts`.
- **structural** — new beat/act/element, restructured flow, persona/punchline change → routes to
  `neo-demo-building` (build-level) or `neo-demo-planning` (story-level).
- **product** — onto the Tier-3 observations list.

### 3f. Auto-fix cosmetic + re-verify
Apply all cosmetic fixes. Re-run Tier-1 and the **affected** Tier-2 rows on the change (a copy
edit changes pacing; a number fix changes cross-surface consistency). Typecheck + lint before
moving on.

### Loop
Repeat 3a–3f until a full pass surfaces **zero new critical/high cosmetic or structural findings**.

## Step 4 — Convergence gate

Phase A (the Opus loop) is converged when:
- Tier-1 fully green (including layout-integrity, approvals-no-auto-resolve, cue-invited-scripted).
- A full Tier-2 pass surfaces zero new critical/high (lows go to the polish backlog).
- Design tier converged: Layer-1 layout probe green, Layer-2 Fable design critique surfaces zero
  new high-severity flaws (Step 3c-design).

Guardrails (apply pipeline-wide, Steps 3–7):
- **Iteration cap (~4).** If a finding reappears after its fix, stop auto-fixing it and escalate
  it as "can't auto-resolve — needs you."
- **Evidence-required.** A dimension unmarked by an artifact is treated as *not checked*, never green.
- **Severity-gated.** Only critical/high block progress; lows never trap the loop.
- **Structural doesn't auto-fix.** Never invent a beat/element/act to satisfy a finding — route it.

## Step 5 — Fable 5 final pass (the fresh-eyes judgment)

On the **converged** demo, spawn ONE read-only subagent with `model: "fable"` and an
**ultrathink** instruction in its prompt. Give it: the plan doc, `rubric.md`, the captured
turn-by-turn transcript + on-disk screenshots, the numbers worksheet, and the Tier-3
observations list from 3d. Its brief:

1. **Prospect skeptic**: read the transcript *as the buyer named in the plan* ("would a VP Ops
   at a $150M 3PL believe this? what makes them raise an eyebrow?"). Believability, logic gaps,
   story-arc drift, scale mismatches, plan misalignment.
2. **Full fresh-eyes sweep**: anything the convergence loop normalized — the Opus loop has been
   staring at this demo for iterations; Fable hasn't.

It returns **findings only** (severity + evidence pointer + suggested resolution), classified
cosmetic / structural / product. It must **not** edit code — judgment and patching stay separated.

## Step 6 — Final fix (Opus)

Apply the Fable findings in the main session:
- **cosmetic** → fix now (cosmetic-fix rules below); typecheck + lint.
- **structural** → route to `neo-demo-building` / `neo-demo-planning`; don't paper over.
- **product** → hold for the operator queue (Step 8), with Fable's reasoning attached.

## Step 7 — Last verification (fresh Opus verifier)

Spawn a **fresh** subagent (`model: "opus"`; use the `verifier` agent type if the repo defines
one) — *not* the instance that made the fixes. Scope:
- Full Tier-1 sweep (cheap; the numbers must still be airtight after the fixes).
- Re-walk + re-judge **only** the acts/surfaces the final fix touched.
- **Finding-by-finding confirmation**: every Fable finding is fixed, routed, or queued — with
  evidence cited for each.

If it surfaces a NEW critical/high, run one more fix → verify cycle (counts against the
iteration cap). Exit **ready** only on a clean pass.

## Step 8 — Hand off

**"Ready" is a gated word — the orchestrator/fixer may NEVER self-declare it.** It is forbidden
unless BOTH independent-judgment stages actually ran and cited evidence: (1) the **Fable 5
fresh-eyes pass** (Step 5) returned findings, and (2) the **fresh-Opus verifier** (Step 7) confirmed
them finding-by-finding on a clean pass. Both are separate instances from the loop that did the
fixing. The observed failure mode this closes: after a long run the fixer is deep in its own context
and **grades its own homework** — declares "ready" without a fresh set of eyes. If either gate is
missing or its evidence is absent, the run is **not ready**, full stop. The manifest (not memory) is
the source of truth: every step `passed` and every critical/high rubric row `passed` with evidence.

Ready = converged (Step 4) + Fable pass done (Step 5) + design tier converged (Step 3c-design) +
fixes verified fresh (Step 7) + Tier-3 resolved or explicitly deferred by the operator (below).

Write the artifacts (so the operator can trust "ready" and spot-check in ~2 minutes):
- **`docs/demos/<slug>-verify.md`** — readiness report: every rubric row, its verdict, a pointer
  to its evidence; the low-severity polish backlog.
- **Numbers worksheet** — every $/%/count claim with its recomputation.
- **Per-act recordings** — the GIFs/videos from 3b.
- **Your queue** — the batched Tier-3 calls (loop observations + Fable's product findings), each
  with the reasoning + the relevant frame.

Then resolve Tier-3 with the operator via `AskUserQuestion` — one batched pass, evidence attached.
Non-technical mode: read the top 3–5 items aloud in plain language first; don't recite every low.

## Step 9 — Self-update the rubric (the ratchet)

The loop must get stricter and faster every time it's used — a lesson learned on one demo should
be caught automatically on the next. At the end of a run, or whenever the operator flags a miss,
**propose new `rubric.md` rows**. Triggers:
1. The operator flags something the loop missed ("this shipped wrong and you didn't catch it").
   When they do, don't just add a row for *that* bug — ask **"what interaction would have caught
   it, and is that interaction in the Step 3b walk?"** All three misses on invoice-audit
   (scroll-back re-type, "yes" fall-through, terminal-approval hang) were interaction/lifecycle
   bugs the forward-playback walk never exercised. A row the walk never performs is dead weight;
   fix the *walk*, then add the row.
2. A `main` sync breaks a demo surface (like the Agents empty-roster) → a new Tier-1 structural row.
   **Primitive-change amplifier:** when a sync changes a *foundational primitive* (list
   virtualization, routing, the agent data source, the streaming engine), don't add only the one
   row for the bug that bit — enumerate the whole **regression class** that primitive opens and
   add a row per failure mode. Virtualization, e.g., breaks: scroll-follow *and* scroll-back
   re-animation *and* re-fired mount effects *and* lost per-row state — the 2026-07 sync added
   only the scroll-follow row, so scroll-back re-typing shipped.
3. A Tier-3 judgment recurs across demos → promote it toward a patternable Tier-2 heuristic.

Safety rails (so the rubric doesn't rot into noise):
- **Append/refine only** — never silently delete a check.
- **Provenance on every new row**: `discovered on <slug>, <date> — <one line why>`.
- **Applied on the operator's confirmation** — these are durable skill edits; propose, then apply.

This mirrors the memory/learning protocol: capture the non-obvious lesson at the moment it's
learned, attached to where it'll be used again.

## Cosmetic-fix rules

A fix is cosmetic (auto-applyable in-loop) only if it touches: `text-delta` / `text-block` copy,
`delayMs`, event/element order, `insights.ts` copy, an insight's `discussPrompt`, the message
inside `formatDemoApprovalSuccess`, or a number that should read from a `data.ts` constant.
Anything else — new event types, new elements, new beats/acts/insights, restructured flow,
persona or punchline changes — is **structural** and routes back to building/planning.

## Constraints

- **Never `--no-verify` on commits**, never skip hooks.
- **Never commit if typecheck or lint is failing.** Fix first.
- **Never auto-commit on technical mode.** Stage only.
- **Never auto-fix a structural finding.** Route it; don't invent story/UI to make a check pass.
- **Never mark a dimension green without its evidence artifact.**
- **The Fable pass never edits code; the fixer never verifies its own fixes.**
- **Severity discipline — never downgrade a breaking bug to a "note."** A fall-through to the real
  agent, an auto-resolving approval, and layout overflow are CRITICAL/HIGH by definition — they block
  "ready." They are not cosmetic, not lows, and not "worth mentioning." If you catch yourself softening
  one to keep the run moving, that IS the bug.
- **Never adapt the test harness to make a demo pass.** If the driver hits a fall-through on a
  cue-invited interaction, that's a demo bug to flag and route — not a reason to change what the driver
  does (e.g. click instead of type). Fixing the harness to go green hides the defect.
- **"Ready" requires both independent gates.** The orchestrator/fixer may never self-declare ready
  without the Fable fresh-eyes pass AND the fresh-Opus verifier having run with cited evidence (Step 8).
- **This skill's job ends at the local commit.** Sharing/deploy is out of scope.

## Pitfalls

- **Judging the source instead of the render.** Tier-2/3 read the captured browser evidence. A
  script can *look* right in the `.ts` and render broken (blank frame, clipped card, wrong order).
- **Running the Fable pass on an unconverged demo.** Its judgment is the most expensive read in
  the pipeline — spend it once, on a stable target, after the mechanical noise is gone.
- **Letting the fixer verify its own fixes.** Step 7 is a fresh instance for a reason; reusing
  the fixing context quietly turns verification into self-agreement.
- **Letting a subjective nit trap the loop.** Lows never block exit — list them, move on.
- **Auto-fixing a structural problem.** Shortening copy is cosmetic; adding a beat to fix a
  logic gap is structural — route it, don't paper over it.
- **Skipping the browser walk because Tier-1 passed.** Correct numbers with broken pacing is
  still a failed demo. The turn-by-turn is the product.
- **Running the browser walk before Tier-1 is green.** Wasteful — fix the deterministic stuff first.
- **Skipping the math because "the numbers look reasonable."** They don't have to look wrong to
  be wrong. Recompute every $-claim from `data.ts`; a viewer's calculator is unforgiving.
- **Forgetting to self-update.** If a miss surfaced during the run, the loop hasn't finished its
  job until that lesson is a rubric row — otherwise the next demo repeats it.

## Worked examples

The Republic Services demo on the `neo-demo` branch is the reference for a fully verified state.
`sets/cascade-3pl/` is the reference for a set with dashboards + mock agents (the surfaces with
the most Tier-1 structural checks). `docs/demos/<slug>-verify.md` from a completed run shows the
shape of the readiness report the loop produces.
