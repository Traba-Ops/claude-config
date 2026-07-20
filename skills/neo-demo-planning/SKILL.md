---
name: neo-demo-planning
description: Use when starting a new scripted Neo demo (or revising one). Takes a context doc the user provides about the prospect, drafts a plan, then iterates with the user until they sign off. Adapts to technical vs. non-technical users.
---

# Neo demo planning

This skill turns a context dump about a prospect into a concrete plan that another person could build from. It does **not** write code. It writes a markdown plan doc that gets reviewed and then handed to `neo-demo-building`.

The output lives at `docs/demos/<prospect-slug>.md` inside the `traba` repo. Plans are revisable — running this skill again on the same prospect updates the plan in place.

## Model + thinking

Planning is pure judgment work — story arc, scale sanity, believability. Run it on **Fable 5** — it sets the ceiling for the whole demo.

- **Model check (before Step 0):** prefer **Fable 5** (`claude-fable-5`). Tell the user how to switch to it — technical: "switch with `/model` → Fable 5, then re-invoke this skill"; non-technical: "I want to use the stronger reasoning model for planning — type `/model`, pick *Fable 5*, then ask me to plan again." A skill can't switch the session model itself.
- **Fallback (no Fable 5):** if the user doesn't have Fable 5, **do not stop** — proceed on **Opus 4.8** and say so in one line ("Running planning on Opus 4.8 — Fable 5 would sharpen the judgment calls, but this works"). On the Opus fallback, **run judgment at `ultrathink`** (see thinking effort) to close the gap. Only stop if the session is on neither — ask for Opus 4.8 at minimum.
- **Thinking effort:** on **Fable 5**, think hard by default and **ultrathink** on the act structure (Sections 4–5) and the scale sanity check. On the **Opus 4.8 fallback**, **ultrathink the whole planning pass** — the extra reasoning budget is how Opus stands in for Fable's judgment edge, and planning is short/token-cheap so it's worth it. Mechanical plan-doc edits during iteration need no extended thinking on either model.
- **Interactive:** planning uses AskUserQuestion iterations, so it runs in the main session — never delegate the drafting to a subagent.
- **Hand-off:** building runs on **Opus 4.8** — when the plan locks, remind the user to switch models (see Step 4).

## Step 0 — Audience check (always first)

Before any planning work, ask the user this verbatim and wait for an answer:

> Before we start: are you comfortable with terms like *git branch*, *dev server*, *file path*, *pnpm command*?
>
> — **Technical**: I know these. Keep your updates brief.
> — **Non-technical**: handle the technical bits for me. Just ask product/story questions.

Save the answer in a TodoWrite item so it persists, and use it everywhere below. Two patterns:

- **Technical mode**: brief one-line status updates ("Plan written to `docs/demos/republic-services.md`"). You may refer to file paths, branches, scripts by id.
- **Non-technical mode**: plain-language status ("I've saved the plan. You can review it later or ask me to read it back."). Never name a file path, branch, script id, or shell command unless asked. If the user asks "where is this saved?", explain in terms they recognize ("inside the project, under a folder I'll find for you later").

If the user picks "other" or describes themselves in a way you can't parse, treat them as non-technical until they explicitly say otherwise.

## Step 1 — Intake

Ask the user for the context doc.

**The doc must be a single, clean source dedicated to this one demo.** Just the context for this prospect, nothing else. No multi-prospect "live deals" doc with many sections. No long meeting-notes log where the demo brief is one section among twenty. If the user has the context but it's mixed in with other material, ask them to copy just the relevant part into a clean doc first.

Why this rule: ambiguity about which section to read is the single biggest cause of plans being built on the wrong material. Pushing it back on the user takes 30 seconds for them and removes a whole class of failure.

**Do not search for the doc on your own.** Don't browse Drive, Coda, Slack, or any other source looking for matches by prospect name. The user always hands the doc to you.

Accept any of these, but only what the user explicitly provides:

- A **direct paste** in chat — works for any source.
- A **specific URL** the user gives you (Google Doc, Coda, etc.) — if you have the corresponding MCP, fetch it. If not, ask the user to paste instead.
- A **specific file path** the user gives you — read with the Read tool.

Ask the user:

> Drop the context doc here — paste, link, or file path is fine. Quick ask: it needs to be a single clean doc with only this demo's context. If your context is mixed in with other material (multiple prospects in one doc, a long meeting notes log, etc.), copy just the relevant section into a fresh doc first and share that. Otherwise I'll be guessing which part is the actual brief.

If the user gives a link but you can't fetch it (no MCP / private doc / unsupported source), ask them to paste the contents instead.

If the user pushes back and says "just read the multi-section doc, the demo brief is in <X> section" — politely insist on the clean-doc rule. The 30 seconds it takes them to extract saves much more downstream rework.

If they don't have a doc at all, ask them to describe the prospect in their own words and treat that as the context.

## Step 2 — Draft the plan

Read what they gave you carefully. **Don't ask follow-up questions yet** — make your best guesses and put them in the plan as proposals. The plan is a strawman the user will react to.

Write `docs/demos/<prospect-slug>.md` with these 9 sections, in this order:

1. **Prospect** — name, industry, **size (annual revenue band)**, who's likely in the room.
2. **The punchline** — one sentence the prospect should walk away repeating. Make this the headline transformation, not the feature list.
3. **Before / After** — what their day looks like today vs. with Neo. Two short paragraphs.
4. **Acts** — the ordered story (typically 2–4 acts).
5. **Per-act detail** — for each act, the per-beat structure (template below).
6. **Proactive insights** — which acts also surface as insight cards on the Insights tab.
7. **Dashboards** (optional) — if the demo includes hand-tuned dashboards, list them: one per intended view, with the chat scripts each links to.
8. **Persona override** — first/last name for the demoer in the profile chip.
9. **Open questions / TODOs** — things you couldn't infer from the context. List them explicitly so the iteration step has a starting point.

The slug is lowercase, hyphenated (`republic-services`, `waste-management`, `gxo-logistics`).

### Scale sanity check (Section 1)

Before drafting the rest of the plan, lock in the **annual revenue band** for the prospect (or the canonical persona, if this is a generic segment demo). The demo's numbers all derive from this anchor — order volumes, FTE counts, dollar amounts, slot counts, claim recoveries.

A demo's biggest credibility risk is when its numbers feel like rounding-error scale for the prospect's stated size. Examples:

- A $150M 3PL feeling excited about saving $1,080 in contingent labor — that's noise at that scale.
- An $11M small-business prospect deciding on a $1.4M renegotiation — that's an existential bet, not a routine call.

Default scales by revenue band:

| Annual revenue | Typical decisions sized in |
| :---- | :---- |
| < $20M | thousands |
| $20–100M | tens of thousands |
| $100–500M | hundreds of thousands to low millions |
| $500M+ | millions |

When drafting per-act detail, check that the dollar / volume / FTE numbers you propose feel material at the prospect's stated scale. If not, either bump the scale of the numbers or note "needs scale alignment" in Section 9.

### Per-act detail template

```
### Act 2: Predictive maintenance (with data-source toggle)

**Script id**: `predictive-maintenance` (always reachable via `/demo predictive-maintenance` as a slash-command override).

**Punch**: Same problem, different confidence — connect more data, get sharper.

**Beat 1 (SCADA only)**:
- Status: "Reading SCADA telemetry for Primary Baler #2..."
- Brief thinking deltas about correlation limits
- Text: ~1 sentence intro
- Connector strip showing SCADA connected, others off; 42% Low confidence
- Cycle-time line chart
- Evidence card from SCADA
- Closing text-block prompting "connect more"
- Pause for user input

**Beat 2 (sources connect)**:
- Three connector modules (MPower, OIS, Warranty/Lot)
- After each connect: strip updates, evidence card appears, cue text streams
- Wait until all three connected
- Two approval cards land
- Done

**Approvals**:
- `demo-rs-act2-rec-a` — route OCC today
- `demo-rs-act2-rec-b` — schedule Thursday seal-kit replacement

**Bridge**: After both approve, reveal "Want to see what this looks like at network scale?" text-block.

**Also a proactive insight**: yes — single card "Primary Baler #2 likely to fail May 22–25"
```

That level of detail is enough for the building skill to translate into code.

### CRITICAL: separate the demo from the demoer's talk track

GTM briefs almost always mix two distinct things together:

- **The demoer's talk track** — what the human salesperson *says aloud* over the demo. Includes sales framing, customer-quote callbacks ("your 5/7 sentence…"), tailoring asides ("we built this for you"), pacing notes ("pause for reaction").
- **The demo UI** — what the chat itself *shows*. Status messages, thinking deltas, text-deltas, rich elements, action cards.

**Only the UI side belongs in the plan.** The talk track is the demoer's job and lives in their notes, Granola, or call guide — not in the script's `text-delta` events.

When extracting the plan from the brief, ignore any block labeled "narration," "Devin says," "talk track," or that uses second-person sales voice ("your stack", "you told us on 5/7"). If a Beat 2 description says *"Devin: 'Top of your list — Pure HOCl Facial Mist 4oz. On-hand at Magic Science: 1,140 units…'"*, the plan should capture the **facts being displayed** (the SKU drill-down state, the verbatim numbers, the action card), not the spoken sentence.

Neo's text-deltas, when used at all, should be:
- Concise ops-voice statements about what's just been computed ("20 SKUs reconciled across Fishbowl and Amazon's portal").
- Or analytical context ("Cycle time trending up 6.5% over 10 days").

Never:
- Customer-name callbacks ("your 5/7 sentence").
- Meeting context ("today, on your stack").
- Sales framing ("the system you asked for").
- Tailoring asides ("we built this for you").

If the brief implies the demo should "name the customer's sentence back to them," that's a talk-track instruction for the demoer to say over the demo — record it in the plan's per-act detail under a *"Demoer says (not in UI):"* note so the build skill knows it's NOT a text-delta.

### Heuristics for the draft

These are defaults — the user can override during iteration. Don't agonize, write the draft and let them push back.

- **Story arc**: default to **narrow → wide**. Start with one obvious site-level problem, then zoom out to network-wide patterns. Reuse the Republic Services arc shape unless the context clearly points elsewhere.
- **Chat vs. proactive insight**:
  - Chat = stories Neo has to *narrate*. Use when the demoer needs to talk over the screen for 5+ minutes.
  - Proactive insight = "you'd have known about this before the VP called." Use when the value is *being-told* rather than *being-explained*.
  - A use case can be *both* — the chat walks through the reasoning in depth, the insight surfaces the conclusion. The skill defaults Acts 2 and 3 to both (matches Republic Services).
- **Rich elements**: pick from the existing library where you can. If the context clearly needs something not in the library, list it under "Open questions / TODOs" as "needs new element: …". Don't try to design the new element here.
- **Visual choice per beat — default to NO chart.** For each beat that has a visual artifact, write down what carries the story: a *number* (one KPI), a *table* (rows with a status column), a *comparison card* (two paths, do-nothing vs with-action), or — only as a last resort — a *chart*. The audience for nearly every Traba demo is a non-technical exec ops buyer (VP Ops, COO, GM, plant manager) who reads dates and outcomes, not curves. A line chart asks them to do mental geometry; a two-path card with dated milestones (`Sun 5/24 — enters risk band`, `Wed 5/27 — stockout`) and bold impact lines (`~$580 fee exposure` vs `Clear for 47 days`) delivers the same story instantly. Only choose a chart if (a) the audience is data-fluent *and* (b) the *shape* of the trend matters, not just the milestones. If the takeaway fits in 3 bullets, a chart is the wrong element. KPI strip + comparison card + honesty caption is the strong default for any "decision moment" beat.
- **Plan the follow-up cue at the end of each pausing beat.** Every beat ending with `await-user-prompt` needs a bold one-line question at the end of its closing prose (the Republic Services pattern — `**Want to drill in?**` / `**Want to see the rest of your Southeast region first, or jump straight into diagnosing Primary Baler #2?**`). In each beat's plan-doc detail, write a "Closing cue:" line with the exact bolded sentence. **One option only unless the script genuinely branches** — don't write "or" alternatives that aren't wired to real downstream paths. Also: if a beat exposes an interactive affordance inside the chat (slider, draggable thing, clickable row), say so with an "Affordance: X. Closing prose calls it out." line — interactive UI inside chat isn't discoverable by default.
- **Approvals**: every act with a "Neo does X" should end with one or more approval cards. Generate placeholder `proposalId`s following the pattern `demo-<slug>-act<n>-<short-tag>`.
- **Script id**: every act maps to one chat script. Pick its id during planning — typically `<topic>` or `<topic>-<variant>`, lowercase, hyphenated (`amazon-fba-coverage`, `predictive-maintenance`, `network-patterns`). The script id is automatically wired as a slash-command target — typing `/demo <script-id>` always works as an explicit override, across sets. **Do not add `/<script-id>` or `/demo` to the trigger list** — the engine handles it. The trigger list is only for natural-language phrases ("show me", "walk me through", topic words).
- **Punchline**: extract from the context if it's there. If not, propose one based on the pain points and ask the user to confirm in iteration.
- **Time budget**: if the context specifies a meeting-time budget for the demo (e.g., "~6 min in a 45-min call"), call out in Section 9 that the replay's char-by-char text streaming + 2 s minimum gap between rich elements will push the actual replay longer than the live-narration estimate. Don't try to solve it in planning — just flag it so the build can verify.
- **Decision sizing**: any beat that presents "options" or "paths" must size each option with a concrete impact in the plan — dollar uplift/loss, % margin recovered, days to break-even, contracts affected. "Renegotiate (+$1.4M annualized)" beats "Renegotiate the contract." If you can't size an option, surface it as an open TODO in Section 9; don't ship vague "three options to consider" framing.
- **Dashboards** (Section 7, optional): if the demo includes hand-tuned dashboards, plan them as a separate output category. One dashboard per "what does the operator see when they open the platform?" view. Each dashboard should map to one primary chat script (linked from a top-right "Discuss with Neo" CTA) and may link to additional scripts via per-card CTAs. Keep the dashboard count low (1-3 per set) — one Operations Pulse (real-time / today), one strategic (forward-looking, e.g. P&L or capacity), and one optional drill. More than that and the surface fragments.

## Step 3 — Iterate

After writing the draft, share it with the user (mode-aware):

- **Technical**: "Draft plan at `docs/demos/<slug>.md`. Walking you through it section by section."
- **Non-technical**: "Here's a first draft of the plan. I'll walk you through it section by section — stop me when you want to push back."

Walk through **all 9 sections in order**, one at a time. For sections 1–8, use the standard pattern. For section 9 (open questions), use the **per-question resolution pattern** described below — those questions need answers, not a "keep / change" gate.

### Standard pattern (Sections 1–8)

For each section, do two things:

1. Read the section back in plain language (a sentence or two for short sections; a brief paraphrase for long ones — never read large blocks of text verbatim).
2. Offer a small set of revision options + a free-text option, using the AskUserQuestion pattern. Always include a "keep as drafted" option as the first choice so they can move on quickly.

### Per-question resolution pattern (Section 9)

Section 9 isn't a proposal to react to — it's a list of unresolved items. Don't ask "keep or change?" for the whole section; that strands the user with no way to give answers. Walk through each open question individually using AskUserQuestion.

For each open item, offer:
- 2–3 concrete resolutions to pick from (draw from the context, common defaults, or the obvious branches).
- "Leave open — defer to build" — keeps it on the list as a real TODO for `neo-demo-building` to surface during the build.
- Free-text — if none of the above fit.

Each "resolved now" answer should be written back into the plan doc immediately:
- If the resolution belongs in another section (e.g., the user picks trigger phrases — that's a Section 5 detail), edit that section.
- If the resolution is itself a piece of guidance for the build (e.g., "no approval cards in this demo, confirmed"), leave a one-line resolved-note in Section 9 like `**Resolved 2026-05-18**: no approval cards in this demo — Nolan's brief explicitly rejected the Approve/Deny frame.`

Items genuinely deferred stay in Section 9 with no resolved-note. The build skill knows to surface them.

If there are more than ~5 open items, group them by theme (e.g., "Elements to design", "Product decisions", "Run-time / pacing"), and walk through the most blocking ones first.

### Example: walking through "Punchline"

Read: *"The punchline I drafted is — 'Today we find out about asset failures when the regional VP calls. With Neo we see them 30 days out.'"*

Then ask via AskUserQuestion:
- **Keep as drafted** — move on.
- **Lean harder on dollars** — rewrite to anchor on a $ number from their pain points.
- **Lean harder on time** — rewrite to anchor on hours/days saved.
- **Different transformation** — *(free-text; user describes what they want)*

### Example: walking through "Acts"

Read: *"I've proposed three acts — Atlanta morning rollup, predictive maintenance on one baler, network-wide patterns."*

Then ask:
- **Keep as drafted** — three acts, narrow → wide.
- **Drop an act** — remove one (which?).
- **Add an act** — *(free-text)*.
- **Reorder** — *(free-text)*.

### Generating good options

For each section, surface 2–3 *real* alternative directions, not generic "change it." Pull from:
- Tradeoffs the context doc surfaced ("the prospect mentioned both downtime $ and overtime $ — which is the headline number?").
- Common Neo arcs (narrow → wide, reactive → proactive, one-system → multi-system).
- Audience adjustments (more technical persona, more executive persona).

If you genuinely can't think of two real alternatives, just offer "Keep" and "Enter your own."

After each user choice, edit `docs/demos/<slug>.md` in place to reflect the change, then move to the next section. **Don't re-summarize between sections** unless the change cascaded into other sections (e.g., dropping Act 2 may collapse a proactive insight).

When all 9 sections are walked, ask the user explicitly via AskUserQuestion:

- **Locked in — ready to build** — hand off to building skill.
- **One more pass** — go through the sections again, only stopping where they want to change something.
- **Major rework needed** — start over from Step 2.

## Step 4 — Hand off

Once the plan is signed off, tell the user (mode-aware). Building runs on **Opus 4.8**, so include the model switch in the hand-off:

- **Technical**: "Plan locked. Switch to Opus 4.8 (`/model`), then run `neo-demo-building` with this slug to start coding."
- **Non-technical**: "Plan locked. When you're ready to build it: type `/model`, pick *Opus 4.8* (the coding model), then ask me to start building this demo and I'll take it from here."

If there are any "needs new element" TODOs in section 9, call them out explicitly — the building skill will need to know.

## When to re-run this skill

- Punchline shifts.
- Scope changes (adding/removing an act).
- An act gets reshuffled between chat and proactive insight.
- Major story-arc change.

Don't re-run for code-level changes — those go through `neo-demo-building` or `neo-demo-critiquing`.

## Worked examples

The Republic Services demo lives at `apps/neo-platform/src/demo-mode/sets/republic-services/`. Read these to see the shape of a finished demo:

- `sets/republic-services/index.ts` — set definition and persona.
- `sets/republic-services/scripts/unifiedView.ts` — Act 1 (Atlanta Today View, multi-site morning rollup).
- `sets/republic-services/scripts/predictiveMaintenance.ts` — Act 2 (connectors + 2 approvals; canonical example of the data-source-toggle pattern).
- `sets/republic-services/scripts/networkPatterns.ts` — Act 3 (network map + two pattern cards + cross-act bridges).

For the proactive surface: `apps/neo-platform/src/demo-mode/insights.ts` — three insights mapping to acts 2 and 3.

The existing rich elements are catalogued in `apps/neo-platform/src/demo-mode/demo-elements/types.ts` — that file is the source of truth for what's available.

## Pitfalls

- **Don't ask the user to fill in everything before drafting.** Read the context, draft confidently, iterate. The draft is the conversation starter.
- **Don't pick rich elements during planning unless the choice is obvious.** Just say "needs a way to show OCC screen jam rate over 3 summers" — the building skill picks the element or flags a new one.
- **Don't write final copy during planning.** Headlines, body text, "Will do" plans, success messages — leave those for building. The plan describes *what each beat shows*, not *what each beat says*.
- **Don't skip the audience check.** Non-technical users get lost the moment you say "branch" or any other dev-tool jargon. Verify before assuming.
- **Don't try to plan more than one prospect at a time.** One slug, one plan doc, one session.
- **Don't expand the open-questions list to be exhaustive.** Only flag gaps that meaningfully affect the build — story-level ambiguities, missing data sources, missing audience details. Skip nitpicks.
- **Don't draft numbers that feel like rounding error for the prospect's scale.** A $150M 3PL doesn't care about a $1,000 contingent-labor decision; an $11M business doesn't credibly make a $1.4M call without it being existential. Anchor the numbers to the scale band before writing per-act detail. See "Scale sanity check" in Step 2.
- **Don't propose "three options to consider" without sizing each option.** Decision beats need concrete impact per option (dollar uplift, days saved, contracts affected). Unsized options read as AI hand-waving. If you can't size them, list as open TODOs.
- **Don't plan dashboards as a chat-script extension.** Dashboards are their own surface with their own rhythm (hero verdict → metrics → insight callout → hero visual → supporting cards). They are NOT just "the chat replay rendered as a dashboard" — they're the always-on quantitative view that the operator returns to. Plan them with their own audience question: "What does the operator see when they open the platform on a Tuesday morning?"
