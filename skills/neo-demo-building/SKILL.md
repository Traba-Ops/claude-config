---
name: neo-demo-building
description: Use after a plan exists from neo-demo-planning. Builds the demo act-by-act with verification between acts. Auto-commits per act for non-technical users.
---

# Neo demo building

This skill takes a signed-off plan (from `neo-demo-planning`) and turns it into working code, one act at a time. Between acts, it verifies the demo runs and looks right — using Chrome MCP if available, otherwise prompting the user to walk through it manually.

Scope: write code, run checks, save checkpoints. Anything related to sharing the work outside the local machine is out of scope and not discussed here.

## Model + thinking

Building is coding work — run it on **Opus 4.8**.

- **Model check (before Step 0):** prefer **Opus 4.8**. If the session is on Fable 5 (common right after planning), ask the user to switch — technical: "`/model` → Opus 4.8, then re-invoke"; non-technical: "I want to switch to the coding model for the build — type `/model`, pick *Opus 4.8*, then ask me to continue." A skill can't switch the session model itself.
- **Fallback (no Opus 4.8):** if the user doesn't have Opus 4.8, **do not stop** — proceed on the strongest coding model they have (Sonnet 5, else Haiku 4.5) and note it in one line. Coding degrades more gracefully across models than judgment does, so no thinking-effort bump is needed here; just be extra rigorous on the math audit (Step 4d.5).
- **Thinking effort:** standard for scaffolding, registration, and plumbing. **Think hard** when writing script beats (pacing + copy decisions) and on the math audit (Step 4d.5) — show the arithmetic, don't assert it.
- **Hand-off:** the verification loop (`neo-demo-critiquing`) runs on the same model as building — no switch needed after building. The loop spawns its own Fable 5 (or Opus-fallback) subagent for the final judgment pass.

## Step 0 — Audience check (always first)

Same as the planning skill. Ask verbatim:

> Before we start: are you comfortable with terms like *git branch*, *dev server*, *file path*, *pnpm command*?
>
> — **Technical**: I know these. Keep your updates brief.
> — **Non-technical**: handle the technical bits for me. Just ask product/story questions.

Save the answer in a TodoWrite item. Two patterns apply throughout:

- **Technical mode**: brief one-line status updates ("Wrote `unifiedView.ts`, typecheck green, on branch `eng-XXX/republic-demo`").
- **Non-technical mode**: plain-language status ("I finished Act 1 and saved it. The app is ready for you to look at."). Never name a file path, branch, script id, or shell command unless asked.

## Step 1 — Find the plan

Ask the user for the prospect slug (or read it from context if obvious). Read `docs/demos/<slug>.md`. If the file doesn't exist:

- **Technical**: "No plan at that path. Run `neo-demo-planning` first."
- **Non-technical**: "I don't have a plan for this prospect yet. We need to make one first — ask me to plan a demo for <prospect> and I'll get started."

If the plan has open "needs new element" TODOs in section 9, flag them now. New element design is a separate conversation — you may need to break out of the linear act-by-act flow to design and build an element before the act that uses it.

## Step 2 — Prerequisites

Set up the workspace before any code. Mode-aware:

### Branch

- **Technical**: ask the user which branch to base off. Don't assume — they may want to branch off `main`, off `neo-demo` (the canonical demo branch), or off a feature branch they have open. Use the suggested name `demo-<slug>` unless they want something else.
- **Non-technical**: do it silently, branching off whatever the current branch is. Say "I've set up a fresh workspace for this demo — nothing you do here will affect anyone else's work yet."

### Dependency / install check

Confirm `pnpm install` has been run recently. If `node_modules` looks stale (lockfile changed) or the user says they haven't installed, run it.

### Chrome MCP availability check

Try to load one Chrome MCP tool via ToolSearch (e.g., `select:mcp__claude-in-chrome__tabs_context_mcp`). Two outcomes:

**Chrome MCP is available** — continue. You'll use it for verification between acts.

**Chrome MCP is NOT available** — stop and give the user clear restart instructions. Use this exact template, adapted for mode:

> To verify the demo I need to drive your browser, which needs the Chrome connector. It isn't loaded in this session. Here's how to switch over without losing our progress:
>
> 1. Type `/exit` to leave this session.
> 2. From your terminal, run: `claude --chrome --resume`
>    (`--chrome` enables the browser connector; `--resume` will let you pick this session from the list.)
> 3. When the session list appears, pick the most recent one — that's us.
> 4. Once you're back in, say "continue building the demo" and I'll pick up where we left off.

After the restart, the user will reinvoke this skill. The plan doc, branch, and any committed acts persist between sessions, so resuming is safe.

If the user explicitly says they want to skip Chrome verification and walk the demo manually instead, that's fine — note it in the TodoWrite list and proceed. You'll prompt them to verify visually after each act in place of running Chrome.

## Step 3 — Scaffold the set

Create the folder structure:

```
apps/neo-platform/src/demo-mode/sets/<slug>/
├── index.ts            (set definition + persona)
├── insight.ts          (the scripted insight shown on chat hero)
└── scripts/
    └── (one .ts file per script, added in step 4)
```

Reference shape: `apps/neo-platform/src/demo-mode/sets/republic-services/` is the canonical example. Copy that structure, swap names, but leave the scripts array empty for now.

Register the set in `apps/neo-platform/src/demo-mode/sets/index.ts` by adding the import + putting it in the `DEMO_SETS` array. Don't make it the default unless the user asks — leave Republic Services as the default.

Run typecheck + lint. If anything fails, fix before continuing.

### Commit checkpoint

- **Non-technical**: auto-commit with a message like `Scaffold <prospect> demo set`.
- **Technical**: stage the new files but don't commit. Tell the user what's staged so they can commit when ready.

## Step 4 — Build acts one at a time

For each act in the plan's section 5:

### 4a. Read the plan section carefully

Re-read the per-act detail for this act. Look for:
- Beat structure (what events fire in order).
- Rich elements needed (look up in `apps/neo-platform/src/demo-mode/demo-elements/types.ts`).
- Approvals (record the `proposalId`s — they need to match any insight cards that bridge to them).
- Cross-act bridges (e.g., post-approval reveal TextBlocks).

### 4b. Handle missing elements

If the act needs an element that doesn't exist in `apps/neo-platform/src/demo-mode/demo-elements/`:

- **Technical**: pause and design the element with the user before continuing the act. Add it to the demo-elements folder, add it to the `DemoElement` union type and the `DemoElementRenderer` switch, then continue.
- **Non-technical**: say "this act needs a new kind of card that doesn't exist yet — let me design it with you first" and walk through what it should show. Then build it.

Reference patterns:
- A status-aware card with a side accent: model on `EvidenceCard`.
- A stats grid + affected-row list: model on `PatternCard`.
- A ranked table with row-level color status: model on `NetworkRiskTable`.

### 4c. Write the script file

Create the script file under `sets/<slug>/scripts/<act-id>.ts`. Translate each beat from the plan into a `DemoChatEvent[]`. Patterns to follow (cross-reference live code, not memory):

- Opening rhythm: status → thinking-start → 1–2 thinking-deltas → thinking-stop → tool-call(s) → text-delta intro.
- Rich element batch: one `demo-element-add` per element. The engine already enforces a 2 s minimum gap between consecutive rich elements; don't pad `delayMs` for it.
- Closing rhythm: text-block closer → approval(s) → done.
- Inter-act pause: `await-user-prompt`.
- Connector flow: `connector-module` elements + `await-connectors-connected` with count.

For ops-voice copy: short sentences, concrete numbers, no emoji bullets, no "leading-edge signature" jargon. See the pitfalls section in `neo-demo-critiquing` for the full anti-slop list — fold those rules in proactively while writing.

Register the script in `sets/<slug>/index.ts`.

### 4d. Verify the code compiles

Run typecheck + lint. Fix anything broken before continuing.

### 4d.5. Math audit before declaring the beat done

Every quantified claim the beat makes must add up. Open a calculator and run the numbers:

- For every "+$X" or "-$Y" claim, multiply the underlying drivers and confirm. Example: "Renegotiate now → +$1.4M annualized" with a surcharge of "$1.40/order on ~38% of orders" should yield `weekly_orders × 0.38 × $1.40 × 52`. If that doesn't equal $1.4M, one of the three numbers is wrong.
- For margin-recovery claims, reconcile against the revenue base: "Margin recovers from X% to Y%" on $Z annual revenue implies `(Y - X)% × $Z` of uplift, and that has to match whatever delivers the uplift.
- For per-day breakdowns, the daily sum must equal the weekly total stated elsewhere.
- For per-facility breakdowns, the facility sum must equal any network total.
- For "this week" + "this period" pairs (e.g. weekly + 90-day), the longer-period number should be ~(period/7) × the weekly. Wildly different ratios mean one of the numbers was pulled from the wrong source.

If you find a mismatch, fix the underlying numbers in the same commit. A demo's credibility evaporates the moment a viewer's calculator catches an arithmetic error — it's worse than a layout bug because it's the kind of thing the prospect actually checks.

### 4e. Verify the act visually

#### Finding the dev server URL

- **Non-technical**: figure it out yourself. Check `apps/neo-platform/package.json`, `vite.config.mts`, and any `pnpm start*` scripts to determine the local URL (typically `localhost:4203`, but verify). Also note that some start commands point the frontend at the dev backend — that's fine, the demo is purely client-side and works the same. Run `lsof -i :<port>` to see if it's already up; if not, start it in the background. Don't surface the port number to the user unless they ask.
- **Technical**: ask. "Where's your dev server running? (e.g., `localhost:4203`, dev env, etc.)" Use whatever they say.

#### With Chrome MCP

Walk the act in the browser:

1. Open the dev URL.
2. Toggle on demo mode in Settings → Demo mode if not already on.
3. Select the new set there.
4. Open a new chat and type a trigger phrase from the new script.
5. Watch the act unfold. Check for:
   - Text streams cleanly (no instant dumps).
   - Cards land in the right order with calm pacing.
   - Approval cards land *after* the post-approval text, not on top.
   - No layout jumps, no overlapping content.
   - The view auto-scrolls to keep the newest streamed content visible. Since the `main` sync the message list is `react-virtuoso` (virtualized), not the old custom sticky-follow scroller — watch for the act starting on a blank frame until it scrolls, or the newest element landing below the fold. If replay content renders but isn't visible, that's a scroll-follow regression, not a missing element.
   - All copy reads in ops voice (no AI slop — see critiquing skill for the full list).

#### Reporting back to the user

The reporting protocol differs by mode.

**Technical**: a 1–2 line summary of what you saw, mentioning specific issues if any (e.g., "Beat 2 cards land but the warranty cue arrives 300ms before the strip animation completes — fixing the delayMs").

**Non-technical**: use the **Screenshot-First Protocol**:

1. Take a screenshot of the act at a meaningful moment using `mcp__claude-in-chrome__get_screenshot`. Pick the moment where the act lands — typically right after the rich elements have appeared and before approvals.
2. Read the screenshot back to the user in plain language: "I'm looking at the screen. There's [describe what's visible top to bottom: heading, card 1 + what it shows, card 2, the action buttons, etc.]."
3. Ask them three specific questions, one at a time via AskUserQuestion:
   - **Pacing**: "Did it feel rushed, calm, or about right?"
   - **Story clarity**: "If you were the prospect seeing this, would you understand what Neo is showing you?"
   - **Anything weird**: "Anything on the screen that looks wrong or off?"
4. Take additional screenshots at other moments if useful (e.g., the approval cards landing, the post-approval cue appearing).

If the user reports "this card looks weird but I don't know why" — describe the card in detail back to them, then offer 2–3 specific possible issues as `AskUserQuestion` options. Examples:
- "Card is too tall — too much text"
- "Wrong color emphasis"
- "Spacing inside the card feels uneven"
- "Other (describe)"

#### Without Chrome MCP

Ask the user to walk the act themselves and report back. Give a short checklist:

- "Open the demo in your browser, select the new set, start a chat, and type a trigger phrase from the act."
- "Watch for: text streaming smoothly, cards landing in order, approvals at the bottom, nothing overlapping."
- "Tell me how it feels — calm, rushed, broken? And anything weird visually."

For non-technical users without Chrome MCP, prefer to switch to Chrome MCP (see the restart instructions in Step 2). Pure user-driven visual verification is much harder for them.

#### Loop

If anything is broken or feels off, fix it. Re-run verification. Loop until the user signs off on the act. The sign-off prompt is explicit via AskUserQuestion: "Are we good on this act, or one more pass?"

### 4f. Commit checkpoint

- **Non-technical**: auto-commit with a message like `Add <act name> to <prospect> demo`. Tell the user "Act <n> is saved — if anything goes wrong later we can roll back to this point."
- **Technical**: stage. Optionally commit if the user nods.

Repeat 4a–4f for each act.

## Step 5 — Build proactive insights

If the plan lists proactive insights (section 6), build them after all chat scripts are done.

### 5a. Add insight entries

Open `apps/neo-platform/src/demo-mode/insights.ts`. Add an entry per insight with:
- `id`, severity, category, title, body
- `plan` (the "Will do" subcard text)
- `metrics`, `reasoning`, `sources`, `confidence` (for the detail view)
- `approvals` — must use the same `proposalId`s as the chat script's approval events
- `discussScriptId` and `discussPrompt` — to wire the "Discuss with Neo" button to the right script

Add a branch to `getDemoInsightsForSet` for this prospect slug.

### 5b. Verify the insights surface

**With Chrome MCP**:
1. Open `localhost:4203/` (the Insights tab).
2. Confirm cards render in severity order (urgent first).
3. Click each card body to verify the full-page drill-in.
4. Click "Approve once" on one card and verify the green success banner.
5. Open chat, force-replay the matching script — verify the corresponding approval card already shows as APPROVED.
6. Click "Discuss with Neo" on another card → confirm it lands in chat with the right script playing.

**Without Chrome MCP**:
Ask the user to walk the insights surface and confirm each of the above.

### 5c. Commit checkpoint

- **Non-technical**: auto-commit.
- **Technical**: stage.

## Step 5.5 — Build dashboards (if the plan calls for them)

A demo set can declare hand-tuned dashboards that render inside the Dashboards tab when demo mode is on. Skip this step if the plan doesn't include dashboards.

### Why dashboards exist

Dashboards are the "what does the COO see when they open the platform?" surface. They complement chat (where the demoer narrates) and insights (where Neo surfaces proactive decisions). The dashboard is where the operator goes for self-serve exploration — visually-rich, quantitative views of business state.

Each dashboard should:
- Tie to one or more chat scripts (the relevant ones can be reached via "Discuss with Neo" CTAs).
- Show a hero verdict at the top with concrete numbers.
- Use a shared data module so its numbers stay in lockstep with the chat scripts and insights.

### 5.5a. Set up the dashboards folder

Create `apps/neo-platform/src/demo-mode/sets/<slug>/dashboards/` with:

```
dashboards/
├── data.ts              (single source of truth for numbers shared across surfaces)
├── DashboardShell.tsx   (layout primitives used by all dashboards in this set)
├── index.ts             (DemoDashboard registry exported as cascade3plDashboards or similar)
└── <Name>Dashboard.tsx  (one component per dashboard)
```

Reference shape: `apps/neo-platform/src/demo-mode/sets/cascade-3pl/dashboards/` is the canonical example. Read its `DashboardShell.tsx` for the primitives — `HeroVerdict`, `MetricCard`, `MetricRow`, `InsightCallout`, `HeroCard`, `SectionCard`, `SectionHeader`, `InlineBar`, `DiscussWithNeoButton` (with `compact` variant), and the refined Recharts theme (`CHART_AXIS_PROPS`, `CHART_PALETTE`, `ChartTooltip`).

### 5.5b. Move shared numbers into `data.ts`

This is the structural fix that prevents cross-surface drift. Anywhere a number appears in *both* a chat script and a dashboard (or in an insight and a dashboard), extract it into a `data.ts` constant and import from both sides. Examples from the Cascade build:

- `NETWORK_WEEK` — network totals (orders, revenue, contribution, FT capacity, gap)
- `BRAND_ROWS` — per-brand portfolio data
- `FACILITY_LABOR` — per-facility labor breakdown
- `OPS_FACILITY_TODAY` — per-facility today snapshot (used by Ops Pulse tiles)
- `AGENT_ACTIVITY` — weekly agent rollup
- `CARRIER_PERFORMANCE` — per-carrier loss/damage/late rates

Then the dashboard components and the chat scripts both reference the same constants. When the number changes, it changes once.

### 5.5c. Build the dashboard component

Layout rhythm (apply to every dashboard):

1. `<DashboardHeader>` with title, subtitle, and a top-right `<DiscussWithNeoButton>` mapped to the primary chat script for this dashboard.
2. `<HeroVerdict>` — one declarative sentence + sub. Tone is critical / warning / neutral based on the headline metric.
3. `<MetricRow>` of 3-4 `<MetricCard>`s — hero-sized numbers with left accent stripes.
4. `<InsightCallout>` — one sentence pulling out the sharpest single fact.
5. `<HeroCard>` — the dashboard's centerpiece visual. One per dashboard. Slightly elevated padding + shadow.
6. Supporting `<SectionCard>`s, often in `<TwoColRow>` pairs.

### 5.5d. Discuss-with-Neo CTAs

One CTA at the dashboard top right (in `DashboardHeader`'s `rightSlot`). That's the only dashboard-level CTA.

Per-card CTAs only when the card maps to a *different* chat script than the header. Place them in the top-right of the card via `<SectionHeader action={...}>`, using the `compact` variant of `DiscussWithNeoButton` with short scope-specific copy:

- "Discuss exceptions" (post-shipment-support script)
- "Discuss claims" (carrier-claims-agent script)
- "Discuss agents" (bulk-label-agent script)

Never put a Discuss CTA at the bottom of a card. Never repeat copy that's redundant with the header CTA.

### 5.5e. Color semantics

Tile / row / card status colors derive from the headline metric — don't hand-set them:

- Pace tiles: `>= 100%` good, `90-99%` warning, `< 90%` critical.
- Margin trends: collapsing margin = critical; recovering = good.
- Gap / shortage: positive (short) = warning/critical depending on size; negative (long) = good or neutral.

If a tile has multiple signals (Charlotte 110% pace + 8 critical exceptions), the *primary* metric drives the tile color; the secondary signal surfaces via a separate badge or callout. Don't let the secondary signal override the primary — it creates a contradiction the viewer reads as buggy.

### 5.5f. Side-by-side card balance

When two `SectionCard`s sit in a `<TwoColRow>`, match content shape, not pixel heights:

- Same row count.
- Same per-row line count (one-line rows alongside one-line rows; two-line alongside two-line).
- Same heading shape (both use `SectionHeader`, or both use bare `SectionTitle`).

If the natural row counts don't match (e.g. "top 5 of 22 exceptions" vs "4 carriers"), drop one or pad the other so they match.

### 5.5g. Register the dashboards

In `sets/<slug>/dashboards/index.ts`, export a registry:

```ts
export const xxxDashboards: DemoDashboard[] = [
  {
    id: 'xxx-dashboard-id',
    title: 'Display Title',
    description: 'Card-list description.',
    lastUpdatedLabel: 'updated 4:00 AM today',
    emoji: '💰',
    Component: SomeDashboard,
  },
]
```

Then add `dashboards: xxxDashboards` to the `DemoSet` in `sets/<slug>/index.ts`. The plumbing in `DashboardsScreen.tsx` and `DashboardsList.tsx` handles the routing + list rendering automatically.

### 5.5h. Verify the dashboards visually

With Chrome MCP:

1. Open `localhost:4203/dashboards` (the Dashboards list). Confirm the demo dashboards appear inline with real dashboards (no violet section, no "DEMO" labels — same base card chrome). Note: real dashboard cards now carry owner-only affordances the demo cards intentionally omit — a favorite star, a dot-menu, and a `MINE` badge (added on `main`). That's expected; the demo cards (`DemoDashboardCardItem` / `DemoDashboardListRow`) are deliberately simpler. Don't try to fake those controls, and don't treat their absence as a bug.
2. Click into each dashboard. Verify the hero verdict, KPI strip, insight callout, hero visual, and supporting cards all render.
3. Click the top-right "Discuss with Neo" CTA. Confirm it navigates to `/chat` with the right script playing.
4. Click any card-level CTA. Confirm it routes to its target script.
5. Run the math audit on the dashboard numbers (Step 4d.5 rules apply): every $-claim should add up, side-by-side cards should balance, colors should match metrics.

### 5.5i. Commit checkpoint

- **Non-technical**: auto-commit per dashboard, then a final "Plumbing + N dashboards" commit if you went iterative.
- **Technical**: stage.

## Step 5.6 — Agents roster (if the set has mock agents)

A set can populate the **Agents** tab with hand-built "always-on watcher" rows. Skip this
step if the plan doesn't call for an Agents view.

### 5.6a. Build the mock jobs

Create `apps/neo-platform/src/demo-mode/sets/<slug>/mockJobs.ts`. Reference shape:
`sets/cascade-3pl/mockJobs.ts`. Each row is an `AgentJob` (type lives in `@traba/agents-ui`,
re-exported via `useNeoJobs`); spread a shared `COMMON_FIELDS` so the rows stay consistent,
and export factories like `cascadeMockJobs()` plus an optional `cascadeMockJobDetail(jobId)`
for the per-agent detail view + runs. Keep the roster's numbers in `data.ts` so they match the
chat scripts and dashboards.

### 5.6b. Wire onto the set

On the `DemoSet` in `sets/<slug>/index.ts`, set `mockJobs` (and `mockJobDetail`). `useNeoJobs`
/ `useNeoJob` short-circuit to these when demo mode is on.

### 5.6c. CRITICAL — the demo Agents source override

`main` moved the Agents roster to a unified `/neo/agents` endpoint gated on the
`NEO_AGENTS_UNIFIED` Statsig flag — and that endpoint has **no demo data**. The mock agents
only appear because `AgentsScreen.tsx` forces the legacy `useNeoJobs` source while in demo mode
(`useUnifiedSource={!isDemoMode && unified === 'enabled'}`). If that override regresses — or a
future `main` sync moves the roster's data source again — the Agents tab goes silently empty
even though everything compiles and typechecks. This already happened once (the empty-roster
bug fixed during the last sync). After any `main` sync, open the Agents tab in demo mode and
confirm the mock agents render.

### 5.6d. Verify + commit

With Chrome MCP: open `/agents`, confirm the roster lists the mock agents (the "Active" count
matches), then click into one for its detail + runs. Commit checkpoint per the mode rules
(auto-commit non-technical, stage technical).

## Step 6 — End-to-end verification

Once all acts, insights, and dashboards are in:

1. **Set picker**: confirm the new set appears in Settings → Demo mode, and selecting it switches the persona + insights + dashboards.
2. **Sidebar**: confirm the persona shows correctly in the bottom-left profile chip, and the set name replaces the email line.
3. **Cross-script bridges**: walk acts in order, follow the followUp triggers (e.g., "yes" → next script), confirm the bridges fire.
4. **Cross-surface number consistency**: spot-check the same metric in chat + insight + dashboard. Same number, same label, same time window. If `data.ts` is the source of truth, this should be free — but verify on at least 3 prominent numbers.
5. **Agents roster** (if the set has `mockJobs`): open the Agents tab and confirm the mock agents render (not an empty "all agents healthy" state — see Step 5.6c).
6. **Reset demo**: in Settings → Demo mode → Reset demo, confirm all approvals revert to PENDING and the insight cards reappear.

Final commit checkpoint:
- **Non-technical**: auto-commit with a message like `Polish + verify <prospect> demo end-to-end`.
- **Technical**: stage.

## Step 7 — Hand off

Tell the user (mode-aware):

- **Technical**: "Demo built and verified on branch `demo-<slug>`. Next step: run `neo-demo-critiquing` for an opinionated review pass."
- **Non-technical**: "The demo is built and working. Want me to do a careful review pass to look for things to polish?"

Offer the critiquing skill as the next step regardless of how confident the verification went. Catching slop and pacing issues before someone shows the demo is the whole point of the loop.

## Constraints

- **Never `--no-verify` on commits**, never skip hooks.
- **Never commit if typecheck or lint is failing.** Fix first.
- **Never auto-commit on technical mode.** Stage only; the user controls commit timing.
- **One prospect per session.** Don't try to build two demos in parallel — the branch model doesn't support it cleanly.
- **`data.ts` is the single source of truth for every cross-surface number.** Any number that appears on more than one surface — a chat script, an insight, a dashboard, a mock agent — MUST be a named constant in the set's `data.ts` and imported at every use site. Never inline the same number in two places. Create `sets/<slug>/data.ts` as soon as the *first* number is shared (don't wait for dashboards; scripts and insights already share numbers). This is a hard rule, not a nicety: the verification loop's math audit treats `data.ts` as the oracle and hard-fails any surface whose number doesn't trace back to a `data.ts` constant. If you catch yourself typing a literal that also appears elsewhere, stop and extract it first.
- **This skill's job ends at the local commit.** Anything beyond that is out of scope here.

## Pitfalls

- **Building before the plan is signed off.** If section 9 of the plan has open TODOs that affect the build, surface them and route the user back to planning.
- **Skipping verification between acts.** Bugs compound. Catching a pacing problem after writing three acts costs more than catching it after one.
- **Inventing new rich-element kinds inline instead of designing them.** New kinds need a type, a renderer case, and styling consistent with the library. Pause and design.
- **Forgetting to register the script or the set.** Trigger phrases won't match if the script isn't in `sets/<slug>/index.ts` and the set isn't in `sets/index.ts`.
- **Diverging proposalIds between chat approvals and insight approvals.** The bridge depends on string equality. Decide the id once and use it everywhere for that decision.
- **Auto-committing on technical mode by accident.** Technical users want commit control — only stage.
- **Reusing an element by name without reading its type.** An element from the library may be structurally coupled to a different use case (e.g., `ConnectorStripElement` includes a required `prediction` field designed for predictive-maintenance flows; pulling it into an inventory demo shows a "FAILURE PROBABILITY" footer that doesn't belong). Before reusing, open the type definition and ask: "Does my demo need every field this element exposes? Will it render extra content I don't want?" If yes, either extend the element with an optional mode flag (preferred for small additions, e.g. `mode: 'asset-prediction' | 'data-sources'`) or build a new element.
- **Reflex copy-paste of field values from a prior demo.** It's easy to type the source list, SKU codes, or persona name from muscle memory instead of from the plan. Always copy concrete field values (source names, asset names, proposalIds, persona) from the *plan doc*, not from a similar prior script.
- **Mixing system-of-record with artifact name in source labels.** "Demand plan" is the analytical output that lives *inside* an Excel workbook — it's not a data source. The source is the application that owns the bytes (Excel, Fishbowl, Amazon Seller Central, QuickBooks). Use the system-of-record name in the connector strip. If the user's voice references the artifact ("our brain is the workbook"), say it in narration, not in the strip label.
- **Leaking the demoer's talk track into the demo UI.** GTM briefs combine "what Devin says over the demo" with "what the demo shows" in the same document. If you see second-person sales voice in the brief (*"your 5/7 sentence"*, *"today, on your stack"*, *"we built this for you"*), that's the human's lines, NOT Neo's. Don't translate those into `text-delta` events. Neo's text-deltas should be ops-voice statements about what's just been computed or what's on screen — never customer-name callbacks, meeting-date callbacks, or sales framing. If the plan accidentally contains such copy in a Beat detail, treat it as a planning bug and ask the user to revise or drop it before writing the script.
- **Time the replay end-to-end, not by adding `delayMs` values.** A back-of-envelope estimate from `delayMs` + char counts × 25 ms typically underestimates the actual replay length 3-4×. Streaming is real-time; React batching, autoscroll, and rich-element entrance animations all add latency. The only honest way to know runtime is to walk the demo in Chrome with a stopwatch. If the plan calls out a meeting-time budget (e.g. "~6 min"), measure once Beat 1 is done and recalibrate `delayMs` (or copy length) early — don't wait until all beats are built to discover it runs 2× over.
- **One-line `if` statements fail the project's lint.** The repo's lint config requires curly braces on every conditional, even single-line ones. Either always use `if (cond) { stmt }` or run `pnpm exec nx lint <app>` before declaring a beat done.
- **Reaching for a chart when a decision card would work.** This is the single biggest visual-design trap. If the audience is an exec ops buyer (VP Ops, COO, GM), they read *dates, dollars, and decisions* — not curves. A line chart with two forecast lines + a risk band + a today marker asks the viewer to do mental geometry to extract the takeaway. A two-column "If we do nothing | With the recommended action" card with dated milestones (`Sun 5/24 — enters risk band`, `Wed 5/27 — stockout`) and bold impact lines (`~$580 fee exposure` vs `Clear for 47 days`) delivers the same story in one glance. **Default to no chart.** A chart is only the right element when (a) the audience is data-fluent (analyst, ops engineer) and (b) the *shape* of the trend matters, not just the milestones. If you can list the takeaways in 3 bullets, the chart is the wrong element. KPI tiles + a two-path comparison + an honesty caption beat a multi-series line chart almost every time.
- **Don't hand-roll SVG charts when Recharts is in the dep tree.** *When* a chart is actually warranted (after the test above), reach for Recharts directly — it's already imported in `shared/neutron-chat`. `ReferenceArea` handles risk bands; `ReferenceLine` handles today markers; `Tooltip` + custom content gives hover. ~100 LOC vs ~300 for the SVG equivalent, and the chart can animate when data changes. The existing hand-rolled SVG elements (`LineTrendCard`, `NetworkMap`) exist for specific historical reasons (Albers projection, tight styling) — don't take them as the pattern for new work.
- **Building UI to spec without sanity-checking screen height and width.** Tables and grids defined in the plan as "20 rows" or "all sources" can balloon to multiple screens or wrap into two lines once rendered. After the first visual verification, check: does any card span more than one screen? Does the connector strip wrap? If yes, slim it (top-N + footer line for tables, shorter source names + dropped separators for strips) before declaring the beat done.
- **Planning to ship the first visual implementation.** The first render of any new rich element almost always has a layout flaw you can't see in the code — overlapping callouts when adjacent dots are too close, too much vertical air between a label and its anchor, end-anchored labels clipping past their container, text that wraps awkwardly to three lines once it hits a real width. Budget for **2-3 visual iterations per new element**. Build v1, screenshot it, look at it with fresh eyes (not the eyes that just wrote the code), and refine. The element isn't "done" after the first compile; it's done after the screenshot looks right.
- **Floating callouts on timeline elements.** When plotting dated events on a horizontal rail, the layout that *almost* works but doesn't is "callout above the rail with a thin tick down to the dot." The tick reads as decorative; the eye doesn't bind the callout to its dot, and the two feel disembodied. The layout that works is a tight vertical column directly under each dot: **dot (on the rail) → short tick → date label (bold caps, severity color) → event description**. Every element in the column visually descends from the rail, anchoring to its position. Also: budget enough inner horizontal padding (~50-80px each side) on the timeline frame so end-anchored milestones (Today at dayOffset 0, last milestone at dayOffset = windowDays) don't clip when their centered labels overflow past the rail edges. And when adjacent milestones are within ~2 days on a 12-day axis, their centered labels will collide — consolidate (drop a non-load-bearing milestone) rather than trying to stagger vertically.
- **Closing a beat into `await-user-prompt` with no follow-up cue.** The script pauses; the user (live demoer or audience following along) sees the closing text-block and then... silence. They have no idea what to type. The demoer is forced to narrate "now type MS-HCL-001" or "type 'push to team' to continue," which leaks scripting into the conversation. **The cue pattern is the one Republic Services already uses: a bold question folded into the closing text-block prose itself** — no separate element, no chips, no inline links. Example: `text: 'Worst of the five: **MS-HCL-001 — Pure HOCl Facial Mist 4oz**, 9 days of coverage, modeled band entry in 6. **Want to drill in?**'`. Any user reply resumes the script past `await-user-prompt`, so the specific words don't matter — the cue just signals that *something will happen* if they answer. Also: when a beat exposes an interactive UI affordance (slider, draggable thing) inside a card, call it out in the cue — interactive affordances inside chat aren't discoverable by default.
- **Cues that offer multiple options when the script only has one continuation.** Don't write `"Want to drill into MS-HCL-001, or check MS-DIS-001 right behind it?"` if only MS-HCL-001 actually fires the next beat. The audience reads "or" as a real choice; typing the unsupported option lands them on nothing. **One option per cue unless multiple downstream paths actually exist** (different beat scripts triggered by different phrases). For most beats this means a single bold question — Republic Services' two-option cues work because each option is wired to a real path (Southeast region beat vs Primary Baler diagnostic script); don't mimic the shape without the substance.
- **Inventing a new element when an existing pattern already covers the case.** Before adding a new element kind, search the existing demo set (`republic-services` is the reference build) for how a similar moment was handled. If RS solved it with bold prose in a `text-block`, do that — don't add a `follow-up-prompts` kind. New element kinds carry permanent surface area (types, renderer case, styling, doc); they're worth it only when the existing library genuinely can't express the moment.
- **Approval cards that fall through to "✓ Action completed."** Every `approval` event you add in a script needs a matching case in `formatDemoApprovalSuccess` in `apps/neo-platform/src/components/Neo/NeoApprovalCard.tsx` — keyed by the proposal's `proposalId`. Without it, clicking Approve renders the generic "✓ Action completed." which is jarringly thin after a beat that listed specific recipients, dates, and owners. Match RS's level of detail: name real-sounding work-order or PO identifiers (`WO-83419`, `PR-25-0518`, `PO-MS-2308`), surface the systems the action would actually hit (Fishbowl, MPower, the SIOP agenda), and call out the named owners who would be notified. After adding an approval to a script, grep for its `proposalId` in `NeoApprovalCard.tsx` to confirm the success message exists.
- **Inlining numbers across multiple files instead of using a data module.** Same number, copied into 3-4 places, will drift the first time you adjust one of them. When the chat replay says "+$1.4M annualized" and the dashboard says "+$1.2M" three months later because someone edited one and not the other, the credibility hit is bigger than the bug. Move shared numbers into `sets/<slug>/dashboards/data.ts` (or a `data.ts` in the set folder if you don't have dashboards yet) and import from both sides.
- **Hand-setting tile / row status colors instead of deriving them.** When the demo data changes, hand-set `status: 'good'` fields don't auto-update — so a tile can claim "+110% pace" and be colored yellow because someone earlier set its status to warning for a now-irrelevant reason. If the color reflects a metric, compute the color from the metric (or at least audit every hand-set status when adjusting underlying numbers).
- **Showing dashboards as visually-different ("demo") in the Dashboards list.** Demo dashboards render inline with real dashboards in the Dashboards tab, using the same base `DashboardCard` chrome (`DashboardsList.tsx`). No violet tints, no "demo" labels, no separate section above the filter row. Caveat since the `main` sync: real cards gained owner-only affordances (favorite star, dot-menu, `MINE` badge) that the demo cards (`DemoDashboardCardItem`) don't render — so they're no longer pixel-identical, and that's fine. The bar is "same card shape + styling, minus the owner-only controls," not "fake a favorite star on a hardcoded dashboard."
- **Bottom-of-card "Discuss with Neo →" buttons on dashboards.** The dashboard has one top-right Discuss CTA in the header. Per-card CTAs only exist when the card maps to a different chat script; they sit top-right of the card in a `SectionHeader` action slot with compact short copy ("Discuss exceptions", "Discuss claims"). Never put a Discuss CTA at the bottom of a section.

## Worked examples

The Republic Services demo is the reference build. To see what the *output* of this skill looks like:

- `apps/neo-platform/src/demo-mode/sets/republic-services/` — the whole set folder.
- `apps/neo-platform/src/demo-mode/insights.ts` — the proactive insights matched to acts 2 and 3.
- The commit history on the `neo-demo` branch — each commit is roughly one of the steps above, in order.
