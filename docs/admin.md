# Prometheus Admin Operations

Automated maintenance and admin tasks that keep the Prometheus infrastructure healthy. These run independently of the operator onboarding workflow.

---

## GitHub Housekeeping

**Schedule:** Daily at 4:00 AM
**Runs on:** Sumeet's machine (requires GitHub admin permissions on Traba-Ops)

Runs two tasks back-to-back:

1. **Repo compliance check** — Scans all Traba-Ops repos via `gh` CLI and auto-fixes non-compliant settings:
   - Only squash merges allowed (disables rebase and merge commits)
   - Delete branch on merge enabled
   - Visibility must be `internal` (except `claude-config` which is `public`)

2. **Slack identity update** — Runs Claude headlessly to map GitHub committers to Slack users. This powers the weekly digest with correct Slack @mentions instead of raw GitHub usernames.

Both tasks are Claude skills in the [traba-slackbot](https://github.com/trabapro/traba-slackbot) repo. Requires `gh` CLI with admin access to the Traba-Ops org.

### GitHub Ops Activity Digest

**Schedule:** Weekly
**Channel:** `#github-ops-activity`
**Runs via:** [traba-slackbot](https://github.com/trabapro/traba-slackbot) (deployed on Railway)

Automated summary of commits, PRs, and contributor activity across all Traba-Ops repos. Helps eng spot duplicate efforts and interesting projects early. Also flags inactive repos (see below).

### Operator Skill Auto-Updates

**Schedule:** Each operator's machine runs `cd ~/.claude && git pull` hourly between 9 AM and 9 PM (set up during initial claude-config install).

When eng pushes changes to `Traba-Ops/claude-config`, all operators get them on next pull. No manual intervention needed.

---

## Offboarding

When someone leaves Traba, revoke access to:
- GitHub (Traba-Ops org)
- Railway (Traba team)
- Transfer ownership of any Tier 2 apps they built

This is currently manual — needs to be added to the company offboarding checklist (see [open questions](open-questions.md#6-offboarding)).

---

## Culling Inactive Projects

The weekly GitHub ops activity digest flags repos with no recent commits. There's no automated cleanup — use the digest to identify stale repos and decide case by case whether to archive them.

Signs a repo should be archived:
- No commits in 30+ days and the operator hasn't mentioned it
- Operator left the company
- Duplicate of another tool that won

Archiving (not deleting) preserves the code and commit history in case someone wants to revisit.

---

## Cost Tracking

Per Tier 2 app: ~$5-10/month
- Railway Hobby: $5/mo (includes $5 usage credit)
- Cloudflare Access: Free up to 50 users
- Supabase Free: 2 projects, 500 MB database
- GitHub: $21/seat/mo (enterprise umbrella)

At 50 apps, estimate ~$250-500/mo plus GitHub seats. No per-team chargeback — company investment.

Set up org-level billing alerts on Railway and Supabase.
