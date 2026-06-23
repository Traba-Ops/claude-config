---
name: humanize
description: Rewrites text to remove AI writing patterns and sound more human
user-invocable: true
---
# Humanize Writing

When triggered, rewrite provided text to eliminate common AI writing patterns. The user will provide text after invoking this skill.

## Words to Replace or Remove

These words are overused by AI and should be swapped for simpler alternatives:

| AI Word | Human Alternative |
| --- | --- |
| delve | explore, look at, dig into |
| intricate | complex, detailed |
| tapestry | mix, combination |
| pivotal | key, important |
| underscore | show, highlight |
| landscape | field, space, area |
| foster | build, create, encourage |
| testament | proof, sign, evidence |
| enhance | improve |
| crucial | important, key |
| multifaceted | complex |
| realm | area, field |
| nuanced | subtle |
| leverage | use |
| comprehensive | full, complete |
| robust | strong |
| utilize | use |
| facilitate | help, enable |
| genuinely | (usually just delete) |
| truly / really / actually | (usually just delete) |

**Empty intensifiers.** "genuinely," "truly," "really," "actually," "simply," "incredibly" almost never add information — they're verbal throat-clearing. Default to deleting them. Watch for repetition especially: the same intensifier twice in a page is a tell. Be especially suspicious of "It's genuinely [adjective]" / "This is genuinely [adjective]" as an emphatic claim — the "genuinely" is doing the work that evidence should do. Either cut it and state the thing plainly, or replace it with the concrete reason it's true.

## Phrases to Eliminate

Remove or rewrite these AI giveaways:

- "stands as a testament to..."
- "plays a vital/significant/crucial role"
- "underscores its importance"
- "rich cultural heritage"
- "enduring legacy"
- "it's important to note that..."
- "it is worth mentioning..."
- "no discussion would be complete without..."
- "In summary," / "In conclusion," / "Overall,"
- "serves as a reminder that..."
- "highlighting the significance of..."
- "reflecting the continued relevance of..."
- manufactured-insight openers: "What stands out is...", "What's striking is...", "What's notable here is...", "Here's what's interesting...", "The interesting thing is...", "What's remarkable..." (see Structural Pattern 9)
- the "not X, it's Y" reversal (see Structural Pattern 8 — it has many disguises)

## Structural Patterns to Fix

### 1. Use Simple Verbs
Bad: "The building serves as a museum."
Good: "The building is a museum."

Bad: "This marks the beginning of..."
Good: "This is the beginning of..." or just start with the thing.

### 2. Kill Present Participle Endings
Bad: "...emphasizing the significance of community."
Good: Just delete it. If the point matters, make it a real sentence.

Bad: "...reflecting the continued relevance of traditional methods."
Good: "Traditional methods still work."

### 3. Reduce Em Dashes
AI overuses em dashes. Use commas, parentheses, or break into separate sentences.

### 4. Break the Rule of Three
AI defaults to three items in every list. Use two, four, or five instead. Vary it.

### 5. Cut False Ranges
Bad: "From intimate gatherings to global movements..."
Good: Just say what you mean directly.

### 6. Remove Compulsive Summaries
Don't end sections with "In summary" or "Overall." Just end.

### 7. Avoid Overused Transitions
Limit: "Moreover," "Furthermore," "Additionally," "On the other hand"
Use simpler connectors or just start the next sentence.

### 8. Kill the "Not X, It's Y" Reversal
AI loves setting up a contrast just to knock it down. State the point directly instead. It hides in many forms:
- "That's not X. It's Y."
- "X isn't just A — it's B."
- "These aren't just internal tools, they're the foundation of..."
- "It's not about A, it's about B."
- "...real engineering, not hand-waving" / "...on evidence, not vibes" (the trailing "not Y" kicker)

Bad: "Neo proves these aren't just internal tools — they're the foundation of a platform."
Good: "Neo turns those internal tools into the foundation of a platform."

### 9. Kill the Manufactured Insight
AI frames ordinary observations as profound reveals. The cadence is: announce that something is significant ("What stands out is X"), reframe it with a reversal ("It's not X, it's Y"), then certify it with an empty intensifier ("It's genuinely Z"). All three moves dress up a claim instead of making it. Cut the framing and just say the thing — let the reader decide if it's striking.

Bad: "What stands out is the architecture. It's not just a tool, it's a platform. It's genuinely impressive how the pieces fit together."
Good: "The architecture is a platform, not just a tool. The pieces fit together because each service owns one job."

The fix for all three moves is the same: delete the setup, state the fact, and back it with a concrete reason. If there's no concrete reason, the "insight" was filler.

## The Rewrite Process

1. Read the text provided
2. Identify AI patterns from the lists above
3. Rewrite using:
  - Shorter sentences
  - Simpler words
  - Direct statements (not hedged)
  - Varied list lengths
  - "Is/are" instead of "serves as/marks"
  - Concrete language instead of abstract praise
4. Return the rewritten version
5. Optionally list the main changes made

## Style Principles

- **Be direct.** Say things once.
- **Be specific.** Cut vague praise ("important," "significant").
- **Be varied.** Change sentence length. Break patterns.
- **Be human.** Imperfection is fine. Fragments work. Start sentences with "And" or "But."
- **Cut filler.** If a phrase adds no information, delete it.

## Example

**Before (AI-sounding):**
"The annual festival serves as a testament to the community's rich cultural heritage, fostering connections between generations and underscoring the pivotal role that tradition plays in modern society. Moreover, it provides a platform for local artisans—showcasing their intricate craftsmanship—while simultaneously enhancing community bonds and reflecting the enduring legacy of shared celebration."

**After (Human):**
"The festival connects generations. Local artisans sell their work. People show up because they always have, and that's enough reason to keep it going."
