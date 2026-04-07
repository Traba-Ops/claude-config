---
name: data-query
description: |
  Ad-hoc BigQuery queries for Traba business data. Use when: (1) user asks
  a question about shifts, workers, companies, fill rate, revenue, or any
  Traba operational or financial metric, (2) user wants to look something up
  in the data warehouse. Requires the BigQuery MCP to be configured (see Setup).
version: 1.0.0
---

# Traba Data Query

Use this skill to answer ad-hoc data questions by writing and running BigQuery queries against Traba's data warehouse. Queries run as the authenticated user's personal Google account — per-user BigQuery RBAC applies.

**Project:** `traba-app`

---

## Setup (one-time per machine)

### 1. Install the MCP Toolbox binary

```bash
# Download the binary for your platform (darwin/arm64 shown — adjust for your OS)
curl -Lo ~/.local/bin/toolbox \
  https://storage.googleapis.com/genai-toolbox/v0.7.0/darwin/arm64/toolbox
chmod +x ~/.local/bin/toolbox

# Verify
toolbox --version
```

For the latest release or other platforms, see: https://googleapis.github.io/genai-toolbox/getting-started/introduction/

### 2. Authenticate with your Traba Google account

```bash
gcloud auth application-default login
```

This stores credentials at `~/.config/gcloud/application_default_credentials.json`. All BigQuery queries will run as your `@traba.work` identity — the same RBAC applies as in the BigQuery console.

### 3. Add the BigQuery MCP to Claude Code settings

Run this in Claude Code, or add it manually to `~/.claude/settings.json`:

> "Add a BigQuery MCP server to my Claude Code settings using the toolbox binary at `~/.local/bin/toolbox` and project `traba-app`"

The resulting config block:

```json
{
  "mcpServers": {
    "bigquery": {
      "command": "/Users/<you>/.local/bin/toolbox",
      "args": ["--prebuilt", "bigquery", "--stdio"],
      "env": {
        "BIGQUERY_PROJECT": "traba-app"
      }
    }
  }
}
```

Restart Claude Code after saving. The BigQuery MCP tools will appear in your tool list.

---

## Dataset Hierarchy

Always query from the highest layer available. Work down only when the data you need doesn't exist in a higher layer.

| Layer | Datasets | Use when |
|-------|----------|----------|
| **Primary** | `marts.*`, `metrics.*` | All standard analysis — shifts, workers, companies, fill rate, revenue |
| **Source** | `src_pg.*`, `src_salesforce.*`, `src_intercom.*`, etc. | Source-specific data not yet in marts (e.g., raw CRM fields) |
| **Admin** | `bigquery_admin.*` | BigQuery cost and usage analysis |
| **Avoid** | `traba_prod.*`, `pg_export_prod_public.*` | Legacy / raw — these are deprecated or raw source |

---

## Key Tables

### `marts.*` — Business entities

| Table | Grain | What it contains |
|-------|-------|-----------------|
| `marts.shifts` | One row per shift | Shift details, slots requested/completed, status, pay rate, timestamps. Updated hourly. |
| `marts.worker_shifts` | One row per worker-shift assignment | Individual assignments with job status, cancellation detail, clock-in/out, role. Updated hourly. |
| `marts.workers` | One row per worker | Worker profile, approval status, aggregate shift counts (completes, cancels). |
| `marts.companies` | One row per company | Company name, category, markup, first shift date, onboarding status. |
| `marts.customers` | One row per customer | Customer tier, slot type, name. A customer may have multiple companies. |
| `marts.placements` | One row per worker × company | First-shift relationship between a worker and a company. |
| `marts.company_regions` | One row per company × region | Geographic combinations, first shift date, ops owners. |

### `metrics.*` — Pre-aggregated daily metrics

| Table | Grain | What it contains |
|-------|-------|-----------------|
| `metrics.company_regions_by_day` | One row per company × region × date | Daily metrics for every active company-region. Includes `days_from_first_shift`. Updated daily. |
| `metrics.placements_by_day` | One row per worker × company × date | Daily expansion of placements from first shift forward. Includes churn, scheduled shift counts. Updated daily. |

### Useful supporting datasets

| Table | What it contains |
|-------|-----------------|
| `bigquery_admin.usage_by_user` | Per-user query cost and count. Use for BQ cost analysis. |

---

## Key Column Reference

### Dates & timestamps

All timestamps are UTC. Use `_timestamp_utc` suffix columns for filtering:

```sql
-- Shifts: use shift_start_timestamp_utc for date filtering
WHERE DATE(shift_start_timestamp_utc) >= '2026-01-01'

-- worker_shifts: same column name
WHERE DATE(shift_start_timestamp_utc) >= '2026-01-01'

-- metrics tables: use date_day (DATE type, no cast needed)
WHERE date_day >= '2026-01-01'
```

### Status fields

```
shifts.shift_status         — 'COMPLETE', 'ACTIVE', 'CANCELED', etc.
worker_shifts.job_status    — 'COMPLETE', 'CANCELED', etc.
workers.is_approved         — boolean
companies.is_approved       — boolean
```

### Identifiers

```
shift_id, worker_id, company_id, region_id, role_id  — natural keys (STRING)
*_sk                                                  — surrogate keys (STRING, avoid in WHERE clauses)
customer_number                                       — INT64, links companies to customers
```

---

## SQL Conventions

**Always use CTEs.** No inline subqueries.

```sql
-- Good
with
    base as (
        select ...
        from `traba-app.marts.shifts`
        where date(shift_start_timestamp_utc) >= '2026-01-01'
    ),
    summary as (
        select
            date(shift_start_timestamp_utc) as shift_date,
            count(*) as total_shifts,
            countif(shift_status = 'COMPLETE') as completed_shifts
        from base
        group by 1
    )
select *
from summary
order by shift_date desc
limit 5
```

**Fully qualify all table references:**
```sql
`traba-app.marts.shifts`          -- correct
`traba-app.metrics.company_regions_by_day`
```

**Default date range: 2026 YTD** unless the user specifies otherwise:
```sql
where date(shift_start_timestamp_utc) >= '2026-01-01'
```

**Limit results:**
- Exploratory / row-level queries: `LIMIT 5`
- Aggregations: no limit needed (the result is already small)

**Use `COUNTIF` over `SUM(CASE WHEN)`:**
```sql
countif(shift_status = 'COMPLETE') as completed_shifts  -- preferred
sum(case when shift_status = 'COMPLETE' then 1 else 0 end)  -- avoid
```

---

## Execution

### Dry-run before every query

Before executing, always run a dry-run to estimate bytes scanned. The BigQuery MCP supports this natively — use the dry-run tool before the execute tool.

**Thresholds:**

| Estimated scan | Action |
|----------------|--------|
| < 200 MB | Proceed, note the scan size in the response |
| 200 MB – 1 GB | Warn the user ("this will scan ~X MB — proceed?") and wait for confirmation |
| > 1 GB | Hard stop. Explain why the query is large and ask the user to confirm or refine it |

A well-formed query against `marts.*` or `metrics.*` with a date filter should scan **10–100 MB**. Anything over 200 MB usually means a missing date filter or a join that's fanning out unexpectedly — investigate before running.

### If the BigQuery MCP is not available

If the MCP tools aren't in your session (check your tool list), write the SQL query and tell the user to run it in the BigQuery console (`console.cloud.google.com/bigquery`, project `traba-app`). Do not attempt to execute via shell or any other mechanism.

---

## Result Formatting

- Return results as a **markdown table**
- For aggregations, add **one sentence** interpreting the result in business terms (e.g., "Fill rate in March was 87%, up 3 points from February")
- Show the query used, collapsed in a `<details>` block so the user can inspect or reuse it
- Include the scan size from the dry-run alongside the results

```
**Result** (scanned 45 MB)

| shift_date | total_shifts | completed | fill_rate |
|------------|-------------|-----------|-----------|
| 2026-04-06 | 1,243 | 1,081 | 87.0% |
...

Fill rate last week averaged 87%, consistent with the prior 4-week trend.

<details><summary>Query</summary>

\`\`\`sql
with base as ( ... )
select ...
\`\`\`

</details>
```
