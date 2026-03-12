# Open Questions & Gaps

---

## Resolved

| # | Decision | Detail |
|---|----------|--------|
| 1 | **GitHub org:** `traba-ops` | Separate org under enterprise umbrella. $21/seat. Jeff set it up. |
| 2 | **Supabase RLS:** auth is the gate, not RLS | Cloudflare Zero Trust is the security boundary. RLS is overkill for internal tools. |
| 4 | **Claude subscription:** Team plan | Operators start on base, upgrade as needed. |
| 5 | **Railway reliability:** non-issue | Chosen for DX, not reliability. If an app can't tolerate downtime, it should be Tier 1. |

---

## Open

### 3. Traba MCP data layer: timeline and scope

Charles, Javi, and Jeremy are defining the ontology and access control. The Prometheus skills can't include a data access skill until the ontology and MCP tools are defined.

**Action:** Follow up on Traba MCP progress. Draft the data access skill once the ontology is published.

### 6. Offboarding

When someone leaves Traba, need to revoke: Infisical, GitHub (`traba-ops`), Cloudflare Zero Trust, Railway access, and transfer ownership of any Tier 2 apps.

**Action:** Add Prometheus to the offboarding checklist.

### 7. Monitoring for deployed apps

Tier 2 apps have no monitoring. Railway's deploy status is probably sufficient. Add uptime checks for specific apps as they become critical. Don't over-invest — if nobody notices it's down, it wasn't important enough to monitor.

### 8. Database migrations

Most Tier 3/2 apps call the Traba API or MCP data layer, not heavy data storage. For apps that store their own data (config, preferences, workflow state), it's prototype data and disposable during promotion. Figure it out case by case.

### 9. Cost tracking

Per Tier 2 app: ~$5-10/mo (Railway $5, everything else free or existing). At 50 apps, ~$250-500/mo plus GitHub seats (enterprise umbrella). No chargeback to teams — company investment. Set up org-level billing alerts on Railway and Supabase.

### 10. Sensitive data and authentication

Any deployed app must be behind auth. Default: Cloudflare Zero Trust with `@traba.work` email restriction. Already covered in [Security Guardrails](security.md) and [Prescriptive Stack](stack.md). Just make sure the deployment skill gates on auth setup.

---

## Things That Are Fine for Now

| Issue | When It Matters |
|-------|----------------|
| No formal asset inventory | When the commit feed becomes insufficient for tracking (~30+ projects) |
| No automated deployment pipeline for Tier 2 promotion | When promotion requests exceed 2-3/week |
| ~~No template repo with all scaffolding pre-configured~~ | Resolved — scaffolding templates are reference files in the project-setup skill, delivered via skillshare |
| No Terraform for Cloudflare Access apps | When more than 10 apps are protected by Zero Trust |
| Skills not versioned with semver | When skill changes cause breaking behavior in existing projects |
| No formal promotion runbook | For Tier 3→2, the runbook is basically: give the operator access to the deployment stack and let their Claude skills handle deployment. We'll iterate on this as we go. Formalize when the process is more proven. |
