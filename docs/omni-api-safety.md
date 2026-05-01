# Omni REST API — branch gating (default)

Omni exposes powerful APIs (shared model YAML, [content validator](https://docs.omni.co/api/content-validator/validate-content.md), [find/replace across documents](https://docs.omni.co/api/content-validator/find-and-replace-content.md), promotions, permissions, etc.). Some calls only **read**; others **mutate** production workbooks, dashboard filters, or the live shared model.

## Default rule

**Gate Omni API usage behind an Omni model branch** (`branch_id` / `branchId` in request paths or bodies) whenever the call can change model or content state, unless a human has **explicitly** agreed in the ticket/thread that operating on **main** is required and why.

- **Roombas, agents, and scripted automation** must assume: no branch id → **stop** and create or obtain a branch before mutating.
- **Read-only** calls (e.g. listing topics, `GET` content validator to inspect issues) may use main **only when** that is clearly safe and documented; if unsure, use a branch anyway.

## Rationale

- Prevents automation from altering **production** Omni content or the production shared model when the intent was to experiment or migrate.
- Aligns blast-radius checks: run **`GET` content validator** against the same branch before merge.

## Exceptions (must be explicit)

Skipping branch gating on main is allowed **only** when the owner has stated so in writing (e.g. Linear comment) with a concrete reason (emergency fix, API limitation after vendor check, etc.). The automation or agent should still prefer the smallest blast radius (e.g. `only_in_workbook_id` where applicable).
