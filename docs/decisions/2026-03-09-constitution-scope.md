# Constitution Scope: Behavioral Rules Only

## Context
While drafting the skills bundle, we noticed that having both Tier 3 (SQLite) and Tier 2 (Supabase, Railway) stacks in the CLAUDE.md constitution caused Claude to reach for the complex stack even when operators were just prototyping locally. More broadly, stack and toolchain preferences are project configuration, not collaboration rules — they don't describe how Claude should interact with the operator.

## Approaches Considered

### Option 1: Default to Tier 3 in the constitution
Remove Tier 2 stack (Supabase, Railway, Infisical) from CLAUDE.md, keep them in a deployment skill. Constitution still includes stack and toolchain.

Problem: stack/toolchain still don't belong in the constitution. They're setup concerns, not behavioral rules.

### Option 2: Constitution is behavioral only, stack moves to a skill
CLAUDE.md contains only collaboration rules: security, development hygiene, project context, session management. Stack, toolchain, and scaffolding move to a project setup skill that auto-detects the project's tier by reading the repo.

### Option 3: No tier detection, just use what's appropriate
Tell Claude to look at the existing repo and use what's already there. New projects default to Tier 3. Promoted projects already have Tier 2 dependencies, so Claude will see them and continue using them.

## Decision
Option 2 + 3 combined. The constitution is purely behavioral. A project setup skill handles stack/toolchain/scaffolding with tier auto-detection: read the repo, use what's there, default to Tier 3 for new projects. No hardcoded tier in any file.
