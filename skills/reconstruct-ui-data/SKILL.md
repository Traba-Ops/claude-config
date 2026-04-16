---
name: reconstruct-ui-data
description: |
  Reconstruct data that the operator can see in an internal UI (Retool, admin panel,
  BI tool, dashboard) but that you cannot pull through the public API. Use when:
  (1) the operator points to a view, table, or chart in another app and asks you to
  fetch "the same data", (2) your first attempt using the public API returns fewer
  rows, different columns, or different totals than what the operator sees on screen,
  (3) the operator says "but it's right there on the page" after you reported the
  data isn't available.
version: 1.0.0
---

# Reconstruct UI Data

Operators often see data in an internal tool (Retool, a vendor admin panel, a BI dashboard, a saved view in our own product) and ask you to reproduce it in the app they're building with you. That data is almost never a plain public-API call — it's a **custom query an admin wired up inside that tool**, usually a GraphQL or SQL query with filters, joins, and sorting baked in. The public API does not have an endpoint that returns "whatever that view is showing", because that view is configuration, not a product feature.

You cannot guess your way through this. If you try, you will return data that looks close but is subtly wrong — wrong totals, missing rows, stale filters — and the operator will only notice after they've acted on it. The fix is to have the operator inspect the network call behind that view, extract the real filter logic, and rebuild it against the public API the operator's app already has access to.

## Recognize the pattern

Stop and run this workflow the moment you hit any of these signals:

- The operator points at a screen in another tool and says "grab this data" or "show this in my app"
- Your public-API query returns **a different row count, different columns, or different aggregates** than the number on the operator's screen
- The operator says "but the page shows 432 active shifts and yours shows 380" (or any variant of "yours doesn't match")
- You find yourself about to add a filter you invented ("I'll assume they mean active shifts in the last 30 days") — that assumption is the bug

Once you hit one of these, do **not** keep tweaking filters by guesswork. Move to the walkthrough below.

## Walkthrough — run this with the operator

The operator has to do the browser steps; you cannot see their screen. Give them one step at a time, wait for the result, then move on. Be patient — most operators have never opened dev tools before.

### Step 1 — Confirm you're in the right situation

Ask the operator:

> Which app or page are you looking at? Can you send me the URL, and describe exactly what you want me to reproduce — the columns, the filters you can see, and the number of rows or the total?

If the operator says "just build me something like X" and there's no concrete screen to point at, this skill doesn't apply — build from their description. This skill is for when there's a real, visible source of truth they want you to match.

### Step 2 — Open dev tools on the source screen

Tell the operator:

> Open the page where you see the data. Then:
> 1. Right-click anywhere on the page and click **Inspect** (Chrome/Arc/Edge) or **Inspect Element** (Safari — you may need to enable the Develop menu first in Settings → Advanced).
> 2. In the panel that opens, click the **Network** tab along the top.
> 3. Click the **Fetch/XHR** filter (in Chrome it's a button row near the search box). This hides image/CSS/font requests so you only see data calls.
> 4. With the Network tab open, **reload the page** (Cmd+R). You'll see a list of requests fill in.

### Step 3 — Find the request that loads the view

Tell the operator:

> Look down the list for a request whose name includes `graphql`, `query`, `api`, or the name of the data you're looking at (e.g., `shifts`, `workers`). Click it. On the right, click the **Payload** or **Request** tab.
>
> Paste me whatever is in that panel. If you see a big block labeled `query` with curly braces and field names, that's what I need. If you see a `variables` block too, send that as well.

If the operator finds multiple candidate requests, ask them to click each one and look for the one whose **Response** tab contains the row count or a value they recognize from the screen.

If the tool uses REST rather than GraphQL, the request will look like `/api/something?filter=...&sort=...` — ask the operator to send the full URL and the response body.

### Step 4 — Extract the filter logic

From what the operator pastes, pull out:

- **Entity / table** — what is being queried (`shifts`, `workers`, `requirements`, etc.)
- **Filters / `where` clauses** — status, date range, region, anything that narrows the result
- **Sort order** — which column and direction
- **Limit / pagination** — top N, offset
- **Fields selected** — the columns the operator sees

Write these out in plain English and play them back to the operator before you build anything:

> Here's what I'm seeing: you want active shifts in the Northeast region, started in the last 14 days, sorted by start time descending, showing shift ID, business name, worker count, and status. Does that match what you see on the page?

This is the single most important step. If the operator corrects any of these, fix it before writing code. An hour of coding against the wrong filter is the failure mode this skill exists to prevent.

### Step 5 — Map to the public API the operator's app uses

The operator's app already has a sanctioned way to pull Traba data. Use it — do not try to hit the custom GraphQL endpoint you just inspected. That endpoint is private to the tool the operator was looking at, is not stable, and will break without notice.

The mapping depends on the app's stack:

- If the app uses **traba-auth / BigQuery** (most Traba operator apps), translate the filters into a `SELECT ... FROM \`traba-data.<dataset>.<table>\` WHERE ...` query. See the bq-auth skill for the query pattern and for the dataset/table names.
- If the app uses a **Traba REST endpoint**, translate the filters into query parameters on that endpoint.
- If the app uses the **Traba MCP**, use the MCP tools to filter and paginate.

If the entity or field the operator wants isn't in the public data surface at all, stop and tell them — do not silently fall back to a different data source. Ask them to confirm in #data or #claudecodestuff that the data they need is exposed through the public surface before you spend time building around it.

### Step 6 — Verify row-for-row against the source

Before calling this done, reconcile:

- Run the reconstructed query.
- Compare the **total row count** to the count visible on the source screen. They should match exactly. If they're off by even one, the filters are wrong.
- Spot-check **3–5 specific rows** by ID (or another stable key) — pick rows the operator can see on the source screen and confirm they appear in your result with the same values.
- If an aggregate (sum, average, count) is shown on the source screen, recompute it from your data and check that it matches.

If any of these don't match, go back to Step 4 with the operator — don't paper over the mismatch with an extra filter you invented.

## Example — reconstructing a custom Retool view

An operator has a Retool dashboard that shows "Shifts needing attention" and asks you to add the same list to the app you're building. Your first attempt — `SELECT * FROM shifts WHERE status = 'open'` — returns 1,240 rows. The Retool dashboard shows 87.

You run the workflow:

1. Operator opens dev tools on the Retool page, reloads, and sends you the GraphQL payload. It's a `shiftsNeedingAttention` query with `variables: { regionIds: ["ne-1","ne-2"], hoursUntilStart: 24, minUnfilledSlots: 1 }`.
2. You translate the filters back to plain English and confirm with the operator: *"Shifts in Northeast regions, starting within 24 hours, with at least one unfilled slot."* Operator confirms.
3. You rewrite the query against BigQuery via traba-auth:

   ```sql
   SELECT shift_id, business_name, start_time, slots_total - slots_filled AS unfilled
   FROM `traba-data.marts.shifts`
   WHERE region_id IN UNNEST(?)
     AND start_time BETWEEN CURRENT_TIMESTAMP() AND TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
     AND slots_filled < slots_total
   ORDER BY start_time ASC
   ```

4. You run it, get 87 rows, spot-check three shift IDs against the Retool screen, and confirm they match before shipping.

## Gotchas

**The custom GraphQL endpoint is not the public API.** It belongs to whatever admin tool the operator was looking at. Do not hardcode its URL, do not re-hit it from the operator's app, do not treat its schema as stable. The only thing it gives you is evidence about what filters the view applies. Always translate to the sanctioned public API before writing code in the app.

**Some UI filters live in client code, not the request.** If the operator's screen has a search box or a toggle that filters the table after it loads, the network request may return more rows than the screen shows. Ask the operator: "Is the number you see on screen the full result of the query, or is there a search/filter on the page that's narrowing it further?"

**Timezones will bite you.** UI dashboards usually display timestamps in the viewer's local timezone, while BigQuery stores UTC. A "today" filter in the UI is not `DATE(start_time) = CURRENT_DATE()` in UTC — it's whatever `today` is in the operator's timezone. Ask the operator what timezone the screen is showing before writing date filters.

**Pagination hides rows.** Many dashboards only load the first 50–100 rows until you scroll. The row count at the top of the screen (e.g., "1,240 results") is the true total — match that, not what's currently rendered in the DOM.

**Aggregates can be computed client-side.** A "total hours" or "average pay" number may be summed in the tool after the rows load. If your reconstructed query returns the same rows, the aggregate will match automatically. Don't try to reproduce an aggregate endpoint if none exists — compute it the same way the UI does.

**Admin-saved views drift.** The filters in the dashboard were correct whenever the admin last edited them. They are not guaranteed to still be what the operator actually wants today. When playing back the filters in Step 4, ask: *"Are these still the filters you care about, or is the view out of date?"*

## Rules

- **Never** guess at filters when the operator pointed at a concrete screen — run the inspection workflow
- **Always** play the extracted filters back to the operator in plain English before writing code
- **Always** reconcile the row count (and at least one aggregate, if shown) before calling the work done
- **Never** call the custom endpoint you inspected from the operator's app — it is evidence, not an integration point
- **Never** silently fall back to a different dataset if the public API doesn't expose what the operator needs — stop and escalate
- If the operator cannot get to dev tools (locked-down browser, mobile, SSO-wrapped tool), ask them to send a screenshot of the full view **including** any filter controls and visible totals, and reconstruct from that plus their description
- Keep the reconstructed query in the app's code, not in a throwaway script — the operator will want to re-run it later
