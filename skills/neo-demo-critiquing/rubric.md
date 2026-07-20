# Neo demo verification rubric

The checklist the verification loop runs. **Rows, not prose** — add a new aspect by adding a
row, never by rewriting the loop. Every row has a **tier** that tells the loop who verifies it:

- **Tier 1 — Deterministic.** Scripted / grep-able. The loop auto-fixes the trivial ones and
  hard-fails the rest. Never reaches the human.
- **Tier 2 — Perceptual.** Judged against captured browser evidence (screenshots + timings +
  DOM), never against source. Cosmetic hits auto-fix; structural hits route to building.
- **Tier 3 — Product judgment.** Escalated to the human, batched, with evidence.

New rows carry **provenance**: `discovered on <slug>, <date> — <one line why>`. Seed rows below
were migrated from the original critiquing checklist (2026-06) and carry no provenance.

---

## Tier 1 — Deterministic

### Math
- Every `+$X` / `-$Y` claim derives from the underlying drivers in `data.ts`. Recompute:
  `orders/wk × 0.38 × $1.40 × 52 =? $1.4M`. Mismatch → fail, show the arithmetic. `[high]`
- Margin-recovery reconciles to the revenue base: "7.2%→13.5% on $22M" ⇒ ~$1.39M uplift; the
  mechanism that delivers it must sum to ~$1.39M. `[high]`
- Daily sub-totals sum to the weekly total stated elsewhere. `[high]`
- Per-facility breakdown sums to the network total. `[high]`
- "This week" + "this period" pairs scale plausibly (~period/7 ratio). `[medium]`
- `%` pace / utilization reconcile to raw values (`12,400/13,800 = 90%`). `[medium]`
- Per-row sub-numbers roll up to the summary KPI (4 carrier rows sum to "47 filed · $11,800"). `[high]`

### Cross-surface number consistency
- Every ≥3-digit number: same value ⇒ same label/meaning on every surface (the "285 = two
  different concepts" bug). Grep, cluster by value, confirm. `[critical]`
- Weekly tables show weekly numbers, not a 90-day rollup pulled in by mistake. `[high]`
- Carrier/facility/brand identity carries through (OakHill = Reno everywhere unless multi-site
  is deliberate). `[medium]`
- Forecast-horizon labels match across surfaces (same dates, not "next 7 days" vs "May 25–29"). `[low]`
- **`data.ts` is the oracle.** Any cross-surface number that isn't a `data.ts` constant imported
  at each site is a fail — the builder was supposed to extract it. `[high]`
- **No hardcoded number that duplicates a `data.ts` constant** — especially in
  `formatDemoApprovalSuccess` success strings, approval `description`s, and `text-delta` copy. A
  literal that shadows a constant drifts silently when the constant changes. Grep the literal
  form of every `data.ts` money/count value; each hit outside `data.ts` must be a
  read (`k(SWEEP_90D.x)`), not a typed number. `[critical]`
  *(provenance: invoice-audit, 2026-07-08 — expiringSoon moved $24K→$21K in data.ts + URGENCY, but a hardcoded "$24K" in the act2 success string didn't, re-creating a carrier-`expired` collision the fresh verifier caught.)*
- **No two `data.ts` values collide within a set unless they mean the same thing.** Cluster all
  set constants by value; a shared value across different concepts (an urgency tranche == a
  carrier's expired total) is a viewer trip-hazard even before it reaches a surface. Force one
  apart. `[high]`
  *(provenance: invoice-audit, 2026-07-08 — `expiringSoon` was deliberately shifted off any carrier `expired` value; make that a standing check, not a one-off comment.)*

### Bridges
- `proposalId` set-equality across chat approvals ↔ insight approvals ↔
  `formatDemoApprovalSuccess` cases. Any string mismatch breaks the bridge. `[critical]`
- Every `approval` proposalId has a tailored `formatDemoApprovalSuccess` case (no fall-through
  to "✓ Action completed."). `[high]`
- `discussScriptId` resolves to a real exported script; `discussPrompt` is a sentence. `[high]`
- `followUps` triggers cover the closer cue's likely replies ("yes"/"ok"/"next"/topic word). `[medium]`

### Structural conventions
- Post-approval reveal elements have ids starting `after-approvals-` (so `NeoChatMessage`
  buckets them below the approval cards). `[high]`
- New element kinds are registered in the `DemoElement` union + `DemoElementRenderer` switch,
  and render through the `Slot` entrance wrapper. `[high]`
- Set is imported in `sets/index.ts` and present in `DEMO_SETS`; persona (`userPersona`) set. `[critical]`
- **Agents roster wired** (if the set has `mockJobs`): `mockJobs`/`mockJobDetail` on the
  `DemoSet`, AND the `isDemoMode` legacy-source override present in `AgentsScreen.tsx`
  (`useUnifiedSource={!isDemoMode && …}`). Missing override = silently empty Agents tab. `[critical]`
  *(provenance: neo-demo, 2026-07 — main moved the roster to the gated `/neo/agents` source, which has no demo data.)*
- Reset wiring: `clearDemoSessions` clears approvals (`clearDemoApprovalResolutions`) + insights
  (`clearDemoInsightStates`); no new persistent demo state left unwired. `[high]`
- **Zero backend chat calls during scripted playback.** With demo mode on, walking any script +
  its follow-ups + resolving every approval must make **no** POST to `/neo/web-chat-init` and log
  no console errors. One backend call = the demo fell out of scripted mode (a missed
  trigger/followUp, a terminal-approval hang, an unmatched affirmative). This is the deterministic
  catch-all for the whole "dropped to the real agent" class — assert it on the browser walk. `[critical]`
  *(provenance: invoice-audit, 2026-07-08 — both the Act1→Act2 "yes" miss and the terminal-approval hang ended in a silent fall-through to the real agent; a network assertion would have caught both without perception.)*
- Typecheck + lint clean. `[critical]`

### Layout integrity
- **No content overflow, no truncation, everything in bounds.** On any element with clip / scroll /
  hidden overflow, `scrollWidth > clientWidth` (or `scrollHeight > clientHeight`) is a fail; no
  unintended text truncation/ellipsis; every element sits within its container bounds; table columns
  align; numeric columns are right-aligned with `tabular-nums`. Measured by the driver's DOM layout
  probe (`neo-demo-autopilot/browser/drive-demo.js` layout report), not by eye. Any hit blocks exit. `[high]`
  *(discovered on sku-master-data-auditor, 2026-07-11 — shipped cards overflowed their clip bounds and truncated content; "does it render" never measured scrollWidth vs clientWidth.)*

### Interaction integrity
- **Approvals must not auto-resolve.** Before any click, the approval card is PENDING: action buttons
  live, NO post-approval / after-state text present in the DOM, and the script does NOT advance on a
  timer. The after-state renders ONLY after a real click. Auto-resolve — after-state visible pre-click,
  or a timed advance past the approval — is a fail; ties to the demo-state-sequencing rule. `[critical]`
  *(discovered on sku-master-data-auditor, 2026-07-11 — an approval card resolved to its "after" state with no user click; the driver always clicked, so the stay-pending invariant was never exercised.)*
- **Cue-invited interaction stays scripted — no fall-through, no harness adaptation.** At every
  `await-*` pause, the walk performs the interaction the cue INVITES: a question-phrased cue → type a
  reply; a button CTA → click it. A backend POST (e.g. `/neo/web-chat-init`) on that natural interaction
  = fall-through to the real agent → route to building. The driver must NOT switch interaction modes
  (e.g. click when the cue invites a typed reply) to force a pass — that hides the bug. `[critical]`
  *(discovered on sku-master-data-auditor, 2026-07-11 — a question-phrased closer ("Want this running?") fell through to the real backend agent; the operator "fixed" the test harness by making the driver click instead of type, masking the fall-through, then self-declared ready.)*
- **Thinking / tool-call status must LEAD the turn, not trail the response.** After the user's input at a
  beat boundary, the thinking + tool-call indicator (divider / `activeToolName` / `toolHistory`) must render
  ABOVE the response content, so a beat reads: input → thinking / tool call → cards. If tool-call chips
  render below the streamed cards (a trailing footer) they read as belonging to the *previous* response.
  Probe: mid-stream, the tool-call element's y-position must be above the beat's cards (drive-demo captures
  this); it must also clear when the beat's `done` fires. `[high]`
  *(discovered on sku-master-data-auditor, 2026-07-11 — the streaming status block rendered after the content bubble, so every scripted beat showed its tool-calls under the fix-list; masked at settle because `done` clears the block. Fixed demo-only via an isDemoMode-gated leading render.)*
- **Files are Drive-discovered, never uploaded.** A demo must NOT ask the user to upload / attach / "drop
  in" a file — there's no good live-demo action for it. When a use case needs an input file, it is a
  **Google Doc/Sheet that Neo discovers in the prospect's Google Drive**, shows, and asks the user to
  confirm (discover → *"use this one?"* → confirm → use) — which also showcases Neo auto-finding + readying
  files. Files Neo *produces* are **Google Sheets/Docs created in Drive** (shared with named owners), never
  `.xlsx`/`.csv` downloads. Flag any upload/attach/drop cue, any attachment-triggered beat, and any output
  framed as a local file. `[high]`
  *(discovered on sku-master-data-auditor, 2026-07-11 — a mid-demo "drop last quarter's ShipHero billing export" cue has no performable live-demo action; the discover-confirm-use pattern removes the upload entirely.)*
- **A typed reply at ANY pause advances — never a fall-through.** Beat boundaries advance by typing
  (`await-user-prompt`), and approval / file-confirm gates (`await-approval-resolved`, DriveFileCard
  "Use this file", action approvals) must accept **both a click and a typed reply** — a demoer trained to
  type "yes" at earlier beats must not get dumped into the real agent at an approval-gated one. Probe:
  at every pause, type a reply and assert **no backend POST**; separately, click the card and assert it
  also advances. `[critical]`
  *(discovered on sku-master-data-auditor, 2026-07-11 — the terminal beat gated on `await-approval-resolved`; typing "yes, continue" instead of clicking Approve fell through to real Neo. Fixed in the engine: a typed reply now resumes approval/confirm pauses too, not just user-prompt pauses.)*

---

## Tier 2 — Perceptual (judged against captured browser evidence)

### Copy / ops voice
- No emoji bullets (🔴🟠🟡🟢) as list markers in `text-delta` — use rich elements. `[medium]`
- No marketing slop ("comprehensive", "robust", "seamless", "leading-edge", "best-in-class"). `[medium]`
- No vague qualifiers ("various", "several", "significant") — use numbers. `[medium]`
- No nominalizations ("provide a notification" → "notify"). `[low]`
- First text-delta of each beat is one sentence. `[low]`
- **Brevity.** Every demo `text-delta` / `text-block` block must be skimmable: flag any block over a
  small line budget (~2 short sentences / ~30 words). Demo audiences skim; long copy is a defect. Fix
  = cut to the one-line essence. The word count is deterministically measurable (Tier-1 flag); whether
  the cut kept the essence is perceptual (Tier-2). `[high]`
  *(discovered on sku-master-data-auditor, 2026-07-11 — the loop shipped verbose copy no one reads; there was no line/word budget on demo copy.)*
- Every $/%/window/count claim is concrete, not hand-waved. `[high]`
- No meta-Neo voice (naming "Neo" inside what Neo says; "showing you the math"). `[medium]`
- No tutorial/preachy framing or agency-handoff narration ("decision lands on you"). `[medium]`
- No bridge meta-narration ("same forward-looking framing applies to labor too"). `[medium]`
- Options in a decision beat are each sized with concrete impact. `[high]`
- **Copy never references a surface or proof-point that isn't built.** No "see the dashboard",
  "in the Agents tab", "zero integration", or a cited insight/table that this set doesn't render.
  Either the surface is structural-missing (route to building) or the copy is wrong (cosmetic).
  Also flag meta-pitch / self-congratulation ("unlike the audit firms", "the system you asked
  for") — that's the demoer's talk track, not Neo's voice. `[high]`
  *(provenance: invoice-audit, 2026-07-08 — hero + closers name-dropped a dashboard, the Agents tab, "zero integration", and an audit-firm dunk; the insights surface those leaned on was then descoped. Fable pass stripped them.)*
- **Cold-start check: a first-touch/pre-deployment hero must be prospective, not a completed
  audit.** If the story premise is "Neo hasn't seen your data yet", the hero insight frames the
  *expected* result (benchmark), and the hard numbers are the in-session reveal — don't leak the
  payoff into the wedge. `[medium]`
  *(provenance: invoice-audit, 2026-07-08 — hero originally claimed a completed audit found $260K, collapsing the narrow→wide arc; reframed to expected ~1.4%/~$1M at spend.)*

### Pacing
- Beat order: ambient (status/thinking/tool) → text-delta → rich elements → closer → approvals →
  done. Out-of-order looks broken. `[high]`
- Rich elements don't pile with no narration between (engine enforces 2s min, but story needs air). `[medium]`
- Connector `onConnectCue` streams fully before the next element/approval. `[medium]`
- `delayMs` values look intentional (not `200` everywhere). `[low]`
- **Scroll-follow**: newest streamed content stays in view; no blank opening frame / below-fold
  landing (react-virtuoso regression). Content in DOM but not visible = scroll bug, not missing. `[high]`
  *(provenance: neo-demo, 2026-07 — list migrated to react-virtuoso; sticky-follow behavior changed.)*
- **Scroll-back is inert**: after scrolling an act off-screen and back, remounted text blocks and
  cards render **fully and statically** — no re-typing, no re-fired entrance animation. Virtuoso
  unmounts/remounts rows, so any mount-driven effect (TextBlock typewriter, `Slot` fade) must be
  gated to play once. Probe by scrolling up then down and screenshotting the remounted element
  immediately. `[high]`
  *(provenance: invoice-audit, 2026-07-08 — TextBlock re-typed and Slot re-faded on every scroll-back remount; a forward-only walk never remounts, so this was invisible.)*

### Visuals + structure
- Approval cards land *after* post-approval text, not on top. `[high]`
- CTA order consistent (insight card + detail): Discuss · Deny · Approve-future · Approve-once. `[low]`
- `DemoInsightDetail` has neither a sticky top bar nor sticky bottom bar (both shrink content). `[medium]`
- Every rich element has the shared fade+slide entrance (renders through `DemoElementRenderer`). `[medium]`
- **Chart-vs-card test**: for an exec ops buyer, if the takeaway fits in 3 bullets a chart is the
  wrong element — prefer KPI tiles + two-path card + dated milestones. Flag multi-series line
  charts with risk bands. `[high]`
- No card spans > ~1.5 viewport heights; no connector strip wraps to two lines. `[medium]`
- Timeline milestones read as belonging to their dot (tight column under the dot), not floating. `[medium]`
- Every `await-user-prompt` is preceded by a bold closing question; interactive affordances
  (slider, draggable) are called out in the cue. `[high]`
- No cue offers an "or" path that doesn't fire a real beat (dead-end). `[high]`
- No new element kind invented where an existing pattern (bold prose in a `text-block`, an
  existing rich element) would serve. `[medium]`

### Design quality
- **Looks good, not just renders.** Judged on ZOOMED per-element frames at real render width (from the
  driver's per-element frame output) against a known-good reference — a shipped `cascade-3pl` dashboard
  card — and the `traba-design` standard: visual hierarchy, spacing/padding rhythm, table/row density,
  alignment, on-design-system, contrast. "Renders" ≠ "looks good." High-severity design flaws block
  exit; budget 2–3 fix→re-render→re-critique iterations per new element. Judged by the dedicated Fable
  design-critique subagent (SKILL Step 3c-design), not the general fresh-eyes pass. `[high]`
  *(discovered on sku-master-data-auditor, 2026-07-11 — shipped cards were ugly (poor hierarchy/spacing/density) despite compiling and rendering; the loop had no design-quality judgment, only "does it render".)*

### Color + visual semantics
- Tile/row color derives from the *primary* metric, not a secondary signal (110% pace tile is
  green even with 8 exceptions). `[high]`
- Color thresholds consistent across the demo (`≥100% good, 90–99% warning, <90% critical`). `[medium]`
- Margin down = red, up = green, everywhere. `[medium]`
- Verdict tone = insight-callout tone = tile tones for the same story. `[medium]`
- `critical` (red) reserved for the one must-act thing; not diluted across unrelated tiles. `[low]`

### Side-by-side card balance
- Two `SectionCard`s in a `TwoColRow` match row count, per-row line count, and heading shape.
  Test content shape, not pixel heights. `[low]`

### Dashboards (if the set has them)
- Exactly one top-right "Discuss with Neo" CTA per dashboard; per-card CTAs only when the card
  maps to a *different* script (compact, scope-specific copy, in `SectionHeader` action slot). `[medium]`
- Header rhythm: `DashboardHeader` → `HeroVerdict` → `MetricRow` → `InsightCallout` → `HeroCard`
  → supporting cards. Headline never buried below charts. `[medium]`
- Hero verdict = one declarative sentence + sub; `MetricCard` values hero-sized (~34px). `[low]`
- Demo dashboards use the same base card chrome as real ones — no violet tint, no "DEMO" label,
  no separate section. Do NOT flag the owner-only affordances real cards now carry (favorite,
  dot-menu, `MINE`) that demo cards intentionally omit — that asymmetry is expected. `[low]`
  *(provenance: neo-demo, 2026-07 — main added owner controls to real dashboard cards.)*

### End-to-end (live)
- Set picker shows the set; selecting it switches persona in the sidebar chip immediately. `[high]`
- Each script's trigger phrase plays the right script from a fresh chat — tested with a real
  **natural-language `trigger`**, never `/demo <id>` (slash bypasses the matcher). Trigger lists
  must be robust: plain affirmatives + several topic phrasings, not one exact string. `[critical]`
- `followUps` cross-link acts in order, reached by typing an **affirmative to the closer**
  ("yes"/"show me"/"next") — confirm the next script plays, not a real-agent reply. Slash-jumping
  between acts does NOT exercise this and is not a valid test. `[critical]`
  *(provenance: invoice-audit, 2026-07-08 — "yes" at the end of Act 1 fell through to the real agent because the followUp context wasn't set during the terminal approval pause; the loop had walked acts via `/demo`, which skips followUp matching entirely.)*
- **Agents roster renders** (if `mockJobs`): not an empty "all agents healthy" state. `[critical]`
- **Resolve EVERY approval, including a script's terminal one, and confirm a clean end** — the
  closer shows, input goes idle (send arrow + chips, no spinner), and NO empty "Thinking…"
  bubble hangs / falls through to the real agent. Walk this on fresh (unresolved) approvals:
  clear `neo_demo_approval_resolutions` in localStorage first, since persisted resolutions make
  a terminal approval silently skip its resolve path. `[critical]`
  *(provenance: invoice-audit, 2026-07-08 — a script ending on `await-approval-resolved` spun up a phantom "Thinking…" message on the final approve; only caught by approving with fresh state, not with persisted-resolved approvals.)*
- Reset demo restores everything to a clean slate. `[high]`

---

## Tier 3 — Product judgment (escalate, batched, with evidence)

- Believable for *this* prospect: persona, systems-of-record, and scale-appropriate numbers vs
  the plan's revenue band ($150M 3PL doesn't care about $1,080; $11M business can't casually
  make a $1.4M call). `[high]`
- The punchline still lands / the story arc (narrow→wide, reactive→proactive) is intact after
  the build drifted. `[high]`
- Is *this* the right headline number / framing for the room. `[medium]`
- "Delight" — does the turn-by-turn feel calm, confident, and worth the meeting minutes. `[medium]`
- Plan alignment: every act in `docs/demos/<slug>.md` exists as a script; every planned insight
  exists; open TODOs in the plan's section 9 are done or still flagged. `[high]`

*Tier-3 findings are drafted by the **Fable 5 final pass** (the adversarial "prospect skeptic"
reads the captured turn-by-turn transcript as the buyer named in the plan, with ultrathink),
but the human makes every call.*
