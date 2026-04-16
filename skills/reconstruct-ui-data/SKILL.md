---
name: reconstruct-ui-data
description: |
  Reconstruct data that the operator can see in an internal UI (Retool, admin
  panel, BI tool, dashboard) but that you cannot pull through the public API.
  First check whether the public API already covers the ask (BigQuery datasets,
  Traba MCP, documented REST endpoints); only if it doesn't, drive the browser
  yourself with the chrome-devtools MCP to capture the real request — install
  it automatically if it is missing. Do not walk the operator through dev
  tools. Use when: (1) the operator points to a view, table, or chart in
  another app and asks you to fetch "the same data", (2) your first attempt
  using the public API returns fewer rows, different columns, or different
  totals than what the operator sees on screen, (3) the operator says "but
  it's right there on the page" after you reported the data isn't available.
version: 2.1.0
---

# Reconstruct UI Data

Operators often see data in an internal tool (Retool, a vendor admin panel, a BI dashboard, a saved view in our own product) and ask you to reproduce it in the app they're building with you. That data is almost never a plain public-API call — it's a **custom query an admin wired up inside that tool**, usually a GraphQL or SQL query with filters, joins, and sorting baked in. The public API has no endpoint that returns "whatever that view is showing", because that view is configuration, not a product feature.

You cannot guess your way through this. If you try, you will return data that looks close but is subtly wrong — wrong totals, missing rows, stale filters — and the operator will only notice after they've acted on it. The fix is to **drive the browser yourself with the chrome-devtools MCP**, capture the real network call behind the view, extract the filter logic, and rebuild it against the public API the operator's app already uses.

## Recognize the pattern

Run this workflow the moment you hit any of these signals:

- The operator points at a screen in another tool and says "grab this data" or "show this in my app"
- Your public-API query returns **a different row count, different columns, or different aggregates** than the number on the operator's screen
- The operator says "but the page shows 432 active shifts and yours shows 380" (or any variant of "yours doesn't match")
- You find yourself about to add a filter you invented ("I'll assume they mean active shifts in the last 30 days") — that assumption is the bug

Once you hit one of these, do **not** keep tweaking filters by guesswork. Move to the walkthrough below.

## Walkthrough

### Step 1 — Get the target from the operator

Ask:

> Send me the URL of the page with the data you want, and tell me exactly what I should match: the columns, the filters you can see, and the row count or total that's shown on the page.

If there's no concrete screen to point at, this skill doesn't apply — build from their description. This skill is only for when the operator has a real, visible source of truth they want you to match.

### Step 2 — Check whether the public API already covers it

Before doing any browser inspection, check whether the data the operator wants is already reachable through the public API the app uses. Browser inspection is the expensive path — skip it whenever an existing endpoint or dataset covers the ask.

Look in this order:

1. **BigQuery via traba-auth.** This is where most Traba operator data lives. Check the bq-auth skill for the dataset conventions, and list the tables in `traba-data.marts.*` and `traba-data.staging.*` that plausibly contain the entity (e.g., for "shifts needing attention", start with `traba-data.marts.shifts`). You can run small exploratory queries (`SELECT column_name FROM \`traba-data.<dataset>.INFORMATION_SCHEMA.COLUMNS\` WHERE table_name = '<table>'`) to confirm the fields match what the operator sees.
2. **Traba MCP**, if configured on the operator's machine. List its available resources/tools and grep for the entity the operator wants.
3. **Any REST API docs the app already uses.** If the app has an OpenAPI/Swagger URL, a `docs/` folder, or a known API reference shared with you in a previous turn, search there for an endpoint that returns the entity with the filters the operator described.
4. **Ask the operator** if they know of a documented endpoint for this. Operators often know which dashboards were built against public APIs versus custom admin queries.

If you find an endpoint or table that plausibly covers the ask:

- Write the query using the filters the operator described in Step 1.
- Run it and compare the row count and 3-5 sample rows to the source screen (the reconciliation from Step 9 — do it now, up front).
- If it matches, you're done: skip the rest of the walkthrough and ship.
- If the row count is off but the entity is clearly right, the filter set on the source screen is richer than what the operator described. Continue to Step 3 to inspect the real filters.

If no public endpoint covers the entity at all, continue to Step 3 — but confirm with the operator first: *"I don't see this data in the public API. Want me to inspect the page to find out what it's querying, and then we can confirm whether the underlying data is available through sanctioned channels?"* Sometimes the answer is "ask data to expose it" rather than "reverse-engineer around the gap".

### Step 3 — Make sure the chrome-devtools MCP is installed

Only reach this step if Step 2 didn't resolve the ask. Check whether you have access to `navigate_page`, `list_network_requests`, and `get_network_request`. If those tools are already in your tool list, skip to Step 4.

If they aren't, install the MCP yourself by running:

```bash
claude mcp add chrome-devtools --scope user -- npx chrome-devtools-mcp@latest
```

This adds the server to the operator's user-scope MCP config so it's available across every project, not just this one. Requirements are minimal: Node 16+ (standard on any recent machine) and Chrome installed (operators running Traba apps already have this). No API keys or auth setup.

After running the command, tell the operator:

> I just installed the chrome-devtools MCP so I can drive Chrome directly for this kind of task. You need to restart this Claude Code session before the new tools load — close this conversation, start a new one, and tell me "continue reconstructing the view from the <tool-name> page" and I'll pick up from here.

Do **not** try to continue the workflow in the same session — the new MCP tools do not appear until Claude Code reloads. Stop here and wait for the restart.

### Step 4 — Navigate to the page

Use `navigate_page` to open the URL in the MCP's Chrome instance. Then call `take_snapshot` (or `take_screenshot`) to see what actually rendered.

Three common outcomes:

- **You see the expected data.** Skip to Step 5.
- **You see a login screen.** Tell the operator: *"I've opened the page in a controlled Chrome window. It's asking me to log in — can you complete the login in that window? Let me know when you're through and I'll continue."* Wait for confirmation, then re-snapshot to verify.
- **You see the app but the data hasn't loaded.** The view may require an interaction (clicking a tab, applying a saved filter, picking a date range). Ask the operator what they clicked on the way to the data, then reproduce it with `click` / `fill` / `wait_for`.

### Step 5 — Capture the network request that loads the view

Once the data is visible on the page:

1. Call `list_network_requests` to enumerate recent requests.
2. Filter to requests that look like data calls — paths containing `graphql`, `query`, `api`, or the name of the entity (e.g., `shifts`, `workers`, `requirements`). Ignore static assets (`.js`, `.css`, images, fonts, analytics beacons).
3. For each candidate, call `get_network_request` and check the response body. The right request is the one whose response row count (or a visible key field) matches what's on the screen.

If the app paginates, the first page's response may only have 50–100 rows while the screen shows a total of thousands — match on the total count field in the response, not the array length.

If nothing in the initial load matches, the view probably refetches on interaction. Re-trigger the view (click the "Refresh" button, change and re-apply a filter) and call `list_network_requests` again to capture the new call.

### Step 6 — Extract the filter logic

From the captured request, pull out:

- **Entity / table** — what is being queried (`shifts`, `workers`, `requirements`, etc.)
- **Filters / `where` clauses** — status, date range, region, anything that narrows the result
- **Sort order** — which column and direction
- **Limit / pagination** — top N, offset
- **Fields selected** — the columns the operator sees

GraphQL requests have this in the `query` + `variables` body fields. REST requests have it in the URL query string or JSON body. If the request body has a full SQL `query` string (common in Retool / Hasura-style tools), read the `WHERE`, `ORDER BY`, and `LIMIT` clauses directly.

### Step 7 — Play the filters back to the operator

Before writing any code, confirm in plain English:

> Here's what the page is actually loading: active shifts in the Northeast region, starting in the next 24 hours, with at least one unfilled slot, sorted by start time ascending. Does that match what you want?

This is the single most important step. If the operator corrects any of it, fix it before writing code. An hour of coding against the wrong filter is the failure mode this skill exists to prevent.

### Step 8 — Reconstruct against the public API

The operator's app already has a sanctioned way to pull Traba data. Use it — **do not hit the custom endpoint you just inspected from the operator's app**. That endpoint is private to the tool the operator was looking at, is not stable, and will break without notice. The inspection is evidence, not an integration point.

Map the extracted filters onto whichever public surface the app is using:

- **traba-auth / BigQuery** (most Traba operator apps): translate to a `SELECT ... FROM \`traba-data.<dataset>.<table>\` WHERE ...` query. See the bq-auth skill for the query pattern and for dataset/table names.
- **Traba REST endpoint**: translate filters into query parameters.
- **Traba MCP**: use the MCP tools to filter and paginate.

If the entity or field the operator wants isn't exposed through the public surface at all, stop and tell them — do not silently fall back to a different data source. Ask them to confirm in #data or #claudecodestuff that the data is exposed through the public surface before you spend time building around it.

### Step 9 — Reconcile before shipping

Before calling it done:

- Compare the **total row count** from your reconstructed query to the count visible on the source screen. They should match exactly. If they're off by one, your filters are wrong.
- Spot-check **3–5 specific rows** by a stable key (ID, shift ID, worker ID). Pick rows the operator can see on the source screen and confirm they appear in your result with the same values. You can use `evaluate_script` through the MCP to pull specific values off the page if the operator can't read them off easily.
- If the source screen shows an aggregate (sum, average, count), recompute it from your data and confirm it matches.

If anything doesn't match, go back to Step 6 — do not paper over the mismatch with an extra filter you invented.

## Example — reconstructing a custom Retool view

An operator has a Retool dashboard that shows "Shifts needing attention" and asks you to add the same list to the app you're building. Your first attempt — `SELECT * FROM shifts WHERE status = 'open'` — returns 1,240 rows. The Retool dashboard shows 87.

You run the workflow:

1. Operator sends the Retool URL. You call `navigate_page` and hit a Google SSO screen. Operator logs in in the controlled window, confirms, you re-snapshot and see the dashboard with 87 rows.
2. You call `list_network_requests`, spot a POST to `/api/v1/graphql` whose response contains 87 items, and call `get_network_request` to read the body. The query is `shiftsNeedingAttention` with `variables: { regionIds: ["ne-1","ne-2"], hoursUntilStart: 24, minUnfilledSlots: 1 }`.
3. You play it back: *"Shifts in Northeast regions, starting within 24 hours, with at least one unfilled slot."* Operator confirms.
4. You rewrite against BigQuery via traba-auth:

   ```sql
   SELECT shift_id, business_name, start_time, slots_total - slots_filled AS unfilled
   FROM `traba-data.marts.shifts`
   WHERE region_id IN UNNEST(?)
     AND start_time BETWEEN CURRENT_TIMESTAMP() AND TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
     AND slots_filled < slots_total
   ORDER BY start_time ASC
   ```

5. You run it, get 87 rows, spot-check three shift IDs against the dashboard, and confirm before shipping.

## Gotchas

**The custom endpoint is not the public API.** It belongs to whatever admin tool you inspected. Do not hardcode its URL, do not re-hit it from the operator's app, do not treat its schema as stable. The only thing the inspection gives you is evidence about what filters the view applies. Translate to the sanctioned public API before writing code.

**Some filters live in client code, not the request.** If the page has a search box or a toggle that filters the table after it loads, the network request may return more rows than the screen shows. Match the on-screen total (usually shown as "N results"), not the array length in the network response. If the two disagree, there's client-side filtering — ask the operator what the search/toggle is set to and include it in your filters.

**Timezones will bite you.** UI dashboards display timestamps in the viewer's local timezone; BigQuery stores UTC. A "today" filter in the UI is not `DATE(start_time) = CURRENT_DATE()` in UTC — it's whatever `today` is in the operator's timezone. Ask the operator what timezone the screen is showing before writing date filters.

**Pagination hides rows.** Many dashboards load only the first page until you scroll. The summary count at the top of the screen (e.g., "1,240 results") is the true total — match that, not the rendered DOM.

**Aggregates can be computed client-side.** A "total hours" or "average pay" number may be summed in the tool after the rows load. If your rows match, the aggregate will match automatically. Don't go looking for an aggregate endpoint that doesn't exist — compute it the same way the UI does.

**Admin-saved views drift.** The filters in the dashboard were correct when the admin last edited them. They are not guaranteed to still be what the operator actually wants. During Step 7, ask: *"Are these still the filters you care about, or is the view out of date?"*

**Session state matters.** The MCP's Chrome is a fresh profile by default — no cookies, no SSO, no saved state. Expect to ask the operator to log in the first time, and expect session timeouts on longer workflows.

## Fallback — if the chrome-devtools MCP can't be installed

Only use this if the MCP genuinely isn't available (locked-down machine, time pressure, MCP install blocked). In that case, walk the operator through the inspection manually:

1. Ask them to open the page, open dev tools (right-click → Inspect), switch to the **Network** tab, click the **Fetch/XHR** filter, and reload.
2. Have them find the request whose name contains `graphql`, `query`, `api`, or the entity name, click it, and paste the **Payload** / **Request** body (and **Response** row count) into the chat.
3. Proceed from Step 6 above.

This is slower and more error-prone than driving the browser yourself — prefer the MCP.

## Rules

- **Always** check the public API (BigQuery datasets, Traba MCP, documented REST endpoints) for an existing path to the data before reaching for browser inspection — inspection is the expensive fallback, not the default
- **Always** use the chrome-devtools MCP to capture the request when inspection is needed — do not guess, do not walk the operator through dev tools unless the MCP is genuinely unavailable
- **Always** install the chrome-devtools MCP automatically if it is missing (`claude mcp add chrome-devtools --scope user -- npx chrome-devtools-mcp@latest`) and pause for a session restart before continuing
- **Always** play the extracted filters back to the operator in plain English before writing code
- **Always** reconcile the row count (and at least one aggregate, if shown) before calling the work done
- **Never** call the custom endpoint you inspected from the operator's app — it is evidence, not an integration point
- **Never** silently fall back to a different dataset if the public API doesn't expose what the operator needs — stop and escalate
- Keep the reconstructed query in the app's code, not in a throwaway script — the operator will want to re-run it later
- If the MCP's Chrome needs a login, ask the operator to complete it in the controlled window and wait for confirmation before continuing
