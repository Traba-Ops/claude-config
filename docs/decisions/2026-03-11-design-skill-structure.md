# Design Skill File Structure

## Context
The design system skill had content split across three files: SKILL.md (7 rules, ~27 lines), core.md (token tables + component specs, ~300 lines), and reference.md (CSS implementation + patterns, ~479 lines). Audit found critical rules duplicated in all three files, Figma links in two places, and component specs separated from their CSS implementation.

## Approaches Considered

### Option 1: Clean up current two-file split (core.md + reference.md)
Remove duplicates, keep the spec-vs-implementation split. Minimal change.

Problem: The split forces Claude to merge two files to build one component (button spec in core.md, button CSS in reference.md). And there's no scenario where Claude loads one without the other.

### Option 2: Three reference files by concern (tokens, components, patterns)
Clearer per-file purpose, but more files. Same problem: Claude always loads all of them.

### Option 3: Single SKILL.md (~630 lines)
Collapse everything into one file. Rules at top, then all content in build order.

## Decision
Option 3. One file.

Progressive disclosure (SKILL.md + reference files) is useful when Claude sometimes needs the entry point without the details. But the design skill always needs everything — there's no partial-load scenario. Splitting creates maintenance surface area and duplication opportunities for zero benefit.

Also removing: Figma links (operators don't have access), "never overwrite files" rule (testing artifact), duplicate rules table, pre-build checklist (restates rules).
