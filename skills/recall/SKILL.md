---
name: recall
description: |
  Find what a prior Claude Code session said, decided, or built, by searching session
  transcripts. Use when: (1) user invokes /recall, (2) user asks "what did we say about X" /
  "we already discussed this" / "another session worked on X", (3) you need rationale or
  findings from prior work that aren't in the project's docs or git history.
user-invocable: true
version: 1.0.0
---

# Recall: find what was said in prior Claude Code sessions

Every Claude Code session leaves a transcript on disk. When the answer to "what did we decide about X" isn't in the project's README/SPEC/decisions or git history, search the transcripts.

**Default execution: delegate to a subagent** (general-purpose, via the Agent tool) and run it foreground — searching large transcript files floods the main conversation's context, and you need the result to answer. Only search inline when you already know which session file holds the answer.

## Where session transcripts live

```
~/.claude/projects/<encoded-cwd>/<session-id>.jsonl
~/.claude/projects/<encoded-cwd>/<session-id>/subagents/agent-<id>.jsonl   # subagent transcripts
```

The encoded-cwd is the absolute path with `/` replaced by `-` and a leading `-` prefix:
- `/Users/pat/my-tool` → `-Users-pat-my-tool`

Different cwd → different project dir → different transcripts. A session started from the home directory lives in a different dir than one started inside the project. Search both (or `grep -r` across `~/.claude/projects/`) if you're unsure where the prior session ran.

## Search pattern that works

```bash
# 1. Find candidate files matching a phrase (-i: transcripts mix cases freely)
grep -rEil 'phrase or regex' ~/.claude/projects/

# 2. Order candidates by recency
ls -lt ~/.claude/projects/<dir>/*.jsonl
```

Plain `grep` on raw JSONL finds candidate *files* but is brittle for reading *content*: each message's text is split across content blocks, and JSON escaping breaks naive line matching. Once narrowed to a candidate, parse the structure:

```bash
python3 -c "
import json
for line in open('<path>'):
    try:
        d = json.loads(line)
        msg = d.get('message', {})
        role = msg.get('role', '?')
        content = msg.get('content', '')
        text = content if isinstance(content, str) else ''.join(
            c.get('text', '') for c in content if isinstance(c, dict) and c.get('type') == 'text'
        )
        if 'target phrase' in text.lower():  # needle must be lowercase — it's compared against lowered text
            print(f'--- {role} ---'); print(text[:2000]); print()
    except: pass
"
```

## The current-session trap

A search subagent often surfaces the **current** session's transcript as the match — it's the most recently modified file, and the user's question in the current session re-states the phrasing from the prior one ("we decided to skip the export feature"), so the current transcript contains the exact search terms. The agent then reports the user's own question back as if it were the prior session's finding.

Brief the subagent explicitly to avoid this:

- Identify the current session's transcripts and **exclude them** — both `~/.claude/projects/<encoded-cwd>/$CLAUDE_CODE_SESSION_ID.jsonl` and its subagent transcripts under `.../$CLAUDE_CODE_SESSION_ID/subagents/`. (If the env var is unset, fall back to excluding the most recently modified transcript — imperfect when parallel sessions share the project dir, so verify every candidate is genuinely a different session.)
- Verify any candidate by reading the *assistant* messages in that session — the substantive findings live there, not in a user prompt that describes them retrospectively.
- Search broadly across cwds and dates, not just the most recent file.

**One more false positive:** when hunting for which sessions actually *used* a tool, a bare grep for the tool name over-matches — the harness lists available tool names in every session's system reminders. Match the structured `tool_use` block (`{"type":"tool_use","name":"..."}`), not the bare name.

## Briefing the subagent

Include in the prompt: what to find (specific phrases, decisions, file paths, or topic), the approximate timeframe if known, the likely cwd(s), the current session's path to exclude, and the output format — session file path plus the specific assistant excerpts that answer the question, under 300 words.

Example brief:

> Find a prior Claude Code session that scoped the shift-tracker dashboard's export feature. The session concluded CSV export was enough and PDF was cut. Likely cwd: `~/shift-tracker`. Exclude the current session at `<path>`. Report the session file path and the assistant's concrete reasoning for cutting PDF.

## When to skip

- The answer is in the project's README, SPEC.md, `decisions/`, or recent `git log` — those are authoritative and faster.
- The user is asking about something earlier in the *current* session — scroll up, don't search disk.
- The user wants to **resume or continue** a prior session rather than just retrieve what it said — that's the **unpark skill** (and **park** writes the durable snapshots it reads). Recall answers questions; unpark revives work.
