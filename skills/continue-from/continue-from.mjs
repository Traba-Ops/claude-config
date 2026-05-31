#!/usr/bin/env node
// continue-from.mjs — snapshot another background Claude Code session's work
// so the current session can pick it up and continue.
//
// Usage: node continue-from.mjs [hint]
//   hint = free text describing the session: words from its name OR its goal,
//          or a short-id prefix. Matching scores against name + goal (intent) +
//          last status (detail), so "the paychecks flaky test work" finds the
//          right session even when its auto-name is something else.
//   No hint  -> lists the background sessions (with a goal snippet) and exits.
//   1 winner -> prints a clean context block (goal, where it left off, activity).
//   tie / 0  -> prints the candidates so you can re-run with a sharper hint.
//
// Sources (deliberately NOT `claude logs` — that returns raw ANSI screen redraws):
//   - `claude agents --json`                  : live session roster
//   - <config>/jobs/<short>/state.json         : intent (goal), detail (status), state
//   - <config>/projects/*/<sessionId>.jsonl    : transcript, for recent activity
//
// <config> honors CLAUDE_CONFIG_DIR; defaults to ~/.claude.

import { execFileSync } from "node:child_process";
import { homedir } from "node:os";
import { join } from "node:path";
import { readFileSync, existsSync, readdirSync } from "node:fs";

const CONFIG_DIR = process.env.CLAUDE_CONFIG_DIR || join(homedir(), ".claude");
const hint = process.argv.slice(2).join(" ").trim().toLowerCase();

// Tunables — keep the injected block small enough not to bloat context.
const MAX_ACTIVITY_ITEMS = 28;
const MAX_TEXT_LEN = 600;
const MAX_ARG_LEN = 160;
const TAIL_LINES = 400;
const SNIPPET_LEN = 90;

// Words to ignore when scoring a free-text hint against a session.
const STOP = new Set(
  ("the a an i was is were are be been doing do did work working on from continue " +
   "session sessions that with for my of to and where this it stuff thing about " +
   "you me we please can could go look check pick up").split(" "),
);

function die(msg) {
  console.log(msg);
  process.exit(0); // exit 0 so the caller renders the message cleanly
}
function truncate(s, n) {
  s = String(s).replace(/\s+/g, " ").trim();
  return s.length > n ? s.slice(0, n) + "…" : s;
}
function shortId(s) {
  return (s.sessionId || "").slice(0, 8);
}
function fmtAge(ts) {
  if (!ts) return "?";
  const mins = Math.floor((Date.now() - ts) / 60000);
  if (mins < 60) return `${mins}m`;
  const h = Math.floor(mins / 60);
  return h < 24 ? `${h}h` : `${Math.floor(h / 24)}d`;
}

// 1. Roster -----------------------------------------------------------------
let sessions;
try {
  const raw = execFileSync("claude", ["agents", "--json"], {
    encoding: "utf8",
    maxBuffer: 32 * 1024 * 1024,
  });
  sessions = JSON.parse(raw);
} catch (e) {
  die(`Could not run \`claude agents --json\`: ${e.message}`);
}
if (!Array.isArray(sessions) || sessions.length === 0) {
  die("No background sessions found. Dispatch one with `claude --bg` or from `claude agents`.");
}

const selfId = process.env.CLAUDE_SESSION_ID || "";

function readState(s) {
  const sp = join(CONFIG_DIR, "jobs", shortId(s), "state.json");
  if (existsSync(sp)) {
    try {
      return JSON.parse(readFileSync(sp, "utf8"));
    } catch { /* ignore */ }
  }
  return {};
}

// Attach state (goal/status) to each candidate, excluding the current session.
const candidates = sessions
  .filter((s) => s.sessionId !== selfId)
  .map((s) => ({ s, st: readState(s) }));

if (candidates.length === 0) {
  die("The only background session is this one — nothing else to continue from.");
}

function goalSnippet(c) {
  const g = c.st.intent || c.st.detail || "";
  return g ? truncate(g, SNIPPET_LEN) : "";
}
function listLine(c) {
  const g = goalSnippet(c);
  return (
    `  - ${shortId(c.s)}  [${c.s.status || "?"}]  ${c.s.name || "(unnamed)"}` +
    `  · ${fmtAge(c.s.startedAt)} ago` +
    (g ? `\n      goal: ${g}` : "")
  );
}

// 2. Score against name + goal + status -------------------------------------
function score(c) {
  // Explicit short-id prefix always wins outright.
  if (hint && shortId(c.s).startsWith(hint)) return 1000;
  const name = (c.s.name || "").toLowerCase();
  const hay = `${name} ${c.st.intent || ""} ${c.st.detail || ""}`.toLowerCase();
  let sc = 0;
  if (hint && name.includes(hint)) sc += 5; // whole phrase in the name
  const toks = hint.split(/\s+/).filter((t) => t.length > 2 && !STOP.has(t));
  for (const t of toks) if (hay.includes(t)) sc += 1;
  return sc;
}

if (!hint) {
  die(
    "Background sessions (re-run with `<name or what it was about>`):\n" +
      candidates.map(listLine).join("\n"),
  );
}

const ranked = candidates
  .map((c) => ({ c, score: score(c) }))
  .sort((a, b) => b.score - a.score);

const top = ranked[0];
const tie = ranked.filter((r) => r.score === top.score);

if (top.score === 0) {
  die(`Nothing matches "${hint}". Candidates:\n` + candidates.map(listLine).join("\n"));
}
if (tie.length > 1) {
  die(
    `"${hint}" is ambiguous (${tie.length} equally-good matches) — be more specific:\n` +
      tie.map((r) => listLine(r.c)).join("\n"),
  );
}

const target = top.c.s;
const st = top.c.st;
const short = shortId(target);
const sid = target.sessionId;
const intent = (st.intent || "").trim();
const detail = (st.detail || "").trim();
const state = st.state || target.status || "";

// 3. Transcript tail -> recent activity -------------------------------------
function findTranscript() {
  const projects = join(CONFIG_DIR, "projects");
  if (!existsSync(projects)) return null;
  for (const dir of readdirSync(projects)) {
    const p = join(projects, dir, `${sid}.jsonl`);
    if (existsSync(p)) return p;
  }
  return null;
}
function recentActivity() {
  const tpath = findTranscript();
  if (!tpath) return "(transcript not found on disk)";
  let lines;
  try {
    lines = readFileSync(tpath, "utf8").split("\n").filter(Boolean);
  } catch (e) {
    return `(could not read transcript: ${e.message})`;
  }
  const items = [];
  for (const line of lines.slice(-TAIL_LINES)) {
    let ev;
    try { ev = JSON.parse(line); } catch { continue; }
    if (ev.type !== "assistant") continue;
    const content = ev.message?.content;
    if (!Array.isArray(content)) continue;
    for (const block of content) {
      if (block.type === "text" && block.text?.trim()) {
        items.push(`💬 ${truncate(block.text, MAX_TEXT_LEN)}`);
      } else if (block.type === "tool_use") {
        const a = block.input || {};
        const arg = a.file_path || a.path || a.command || a.pattern || a.prompt || a.url || "";
        items.push(`🔧 ${block.name}${arg ? `  ${truncate(arg, MAX_ARG_LEN)}` : ""}`);
      }
    }
  }
  const recent = items.slice(-MAX_ACTIVITY_ITEMS);
  return recent.length ? recent.join("\n") : "(no recent assistant activity in transcript tail)";
}

// 4. Emit context block -----------------------------------------------------
const out = [`## Snapshot: "${target.name}"  (${short}, state: ${state})`, `cwd: ${target.cwd || "?"}`, ""];
if (intent) out.push("### Goal it was given", intent, "");
if (detail) out.push("### Where it left off / last status", detail, "");
out.push("### Recent activity (newest last)", recentActivity());
console.log(out.join("\n"));
