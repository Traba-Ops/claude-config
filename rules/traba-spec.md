# Traba Project Documentation

Keep two living documents: a README for users of the app, and a spec for engineers who may re-implement it. Neither requires effort from the operator. Both get written as a byproduct of normal development.

Update both documents when things change, not at session end. If the operator corrects a business rule, fix the spec right then. If a new workflow gets added, put it in both (briefly in the README, with detail in the spec).

## README.md

The README is for anyone who opens the repo or uses the app. Keep it short.

- **What this does:** one paragraph on the problem and the solution
- **Who uses it:** which team, what workflow, how often
- **How to run it:** setup steps, environment variables, prerequisites
- **How to use it:** the main things users do, with brief descriptions

No technical depth here. That goes in the spec.

## SPEC.md

An engineer should be able to re-implement this app from the spec alone. It accumulates detail as the project grows. Structure it as:

- **Business rules:** the actual logic the app encodes. Not "manages shifts" but "shifts within 30 miles of a worker's home zip are local; beyond that, travel pay applies." When the operator corrects your understanding, capture the corrected rule here.
- **Data model:** tables/collections, fields with types, relationships, where data comes from (MCP tools, APIs, manual entry). Include example values where they clarify meaning.
- **Key workflows:** step-by-step, including error and edge cases. Precise enough that an engineer could implement them without the operator present.
- **Integrations:** external systems the app talks to: APIs, MCP tools, databases, third-party services. What data goes in, what comes back, what credentials are needed.
- **Known limitations:** what it doesn't handle, known bugs, workarounds, things that are intentionally simple.

## Decision Records

When a meaningful choice is made (e.g., "used polling instead of websockets because the data only changes hourly"), capture it in `decisions/YYYY-MM-DD-topic.md`:
- What the options were
- What was chosen and why

Decision records are append-only. If a decision is later reversed, write a new record explaining why. Commit them automatically.
