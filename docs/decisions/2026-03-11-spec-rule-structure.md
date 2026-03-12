# Spec Rule: README + SPEC.md Split

## Context
The spec generation rule (`traba-spec.md`) was producing a single README-as-living-spec plus session summaries and decision records. Needed to evaluate whether this captured enough signal for Tier 1 re-implementation and whether the consolidation mechanism worked.

## Approaches Considered

### Option 1: Keep README as single living spec
README captures everything — user docs and engineering spec in one file. Session summaries provide supplementary context. Periodic consolidation keeps it current.

Problem: README becomes too technical for operators, too shallow for engineers. Session summaries have a fragile trigger (operator closes terminal → no summary). Periodic consolidation drifts.

### Option 2: README + SPEC.md split
README stays user-facing (what, who, how to run, how to use). SPEC.md is engineer-facing (business rules, typed data model, workflows with edge cases, integrations). Both update continuously.

### Option 3: Structured spec template
Formal spec document with fixed sections, filled in progressively. More structured than option 2 but risks becoming a checkbox exercise.

## Decision
Option 2: README + SPEC.md split.

- README is simple and accessible — anyone who opens the repo understands what this is
- SPEC.md accumulates the technical depth an engineer needs: business rules with specifics (not "manages shifts" but the actual logic), data model with types, integration details, workflow edge cases
- Session summaries dropped entirely — fragile trigger, creates drift-prone parallel log. Learnings flow directly into README/SPEC.md when they happen.
- Periodic consolidation dropped — replaced with continuous updates. Update docs when things change, not on a vague schedule.
- Decision records kept as-is (append-only, they work well)
- Operator corrections to business logic go directly into SPEC.md — this is the highest-signal input for re-implementation
