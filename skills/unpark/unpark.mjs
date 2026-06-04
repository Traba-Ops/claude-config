#!/usr/bin/env node
// unpark.mjs — unified "pick up where something left off".
//
// Supersedes continue-from.mjs: searches BOTH
//   (1) live background Claude Code sessions  (resume an active session), and
//   (2) parked Obsidian snapshots in Jeffs Junk (revive a dead session),
// ranks them together against a free-text hint, and prints the winner's context
// block so the calling session can continue the work.
//
// Usage: node unpark.mjs [hint]
//   No hint  -> lists live sessions + parked notes (with goal/title snippets).
//   1 winner -> prints that target's full context block (live snapshot OR note).
//   tie / 0  -> prints the candidates so you can re-run with a sharper hint.
//
// Sources (deliberately NOT `claude logs` — that returns raw ANSI redraws):
//   - `claude agents --json`                    : live session roster
//   - <config>/jobs/<short>/state.json           : intent (goal), detail (status)
//   - <config>/projects/*/<sessionId>.jsonl      : transcript tail, recent activity
//   - <vault>/Claude Sessions/*.md               : parked snapshots (frontmatter+body)
//
// <config> honors CLAUDE_CONFIG_DIR; defaults to ~/.claude.

import { execFileSync } from "node:child_process";
import { homedir } from "node:os";
import { join } from "node:path";
import { readFileSync, existsSync, readdirSync } from "node:fs";

const CONFIG_DIR = process.env.CLAUDE_CONFIG_DIR || join(homedir(), ".claude");
// Where parked snapshots live. Override with CLAUDE_PARK_DIR (point it at an
// Obsidian vault folder, a Dropbox dir, anywhere). Default is a plain local dir
// OUTSIDE the (often git-backed) config dir so notes never pollute it.
const PARK_DIR = process.env.CLAUDE_PARK_DIR || join(homedir(), ".claude-park");
const hint = process.argv.slice(2).join(" ").trim().toLowerCase();

// Tunables — keep injected blocks small enough not to bloat context.
const MAX_ACTIVITY_ITEMS = 28;
const MAX_TEXT_LEN = 600;
const MAX_ARG_LEN = 160;
const TAIL_LINES = 400;
const SNIPPET_LEN = 90;
const MAX_NOTE_BODY = 8000; // a parked note is the whole point — print generously

const STOP = new Set(
  ("the a an i was is were are be been doing do did work working on from continue " +
    "session sessions that with for my of to and where this it stuff thing about " +
    "you me we please can could go look check pick up revive resume park unpark").split(" "),
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
function tryReadJson(p) {
  if (existsSync(p)) {
    try {
      return JSON.parse(readFileSync(p, "utf8"));
    } catch { /* ignore */ }
  }
  return null;
}

// ── 1. Live background sessions ────────────────────────────────────────────
function runAgentsJson() {
  const bins = ["claude", process.env.CLAUDE_CODE_EXECPATH].filter(Boolean);
  let lastErr;
  for (const bin of bins) {
    try {
      return execFileSync(bin, ["agents", "--json"], {
        encoding: "utf8",
        maxBuffer: 32 * 1024 * 1024,
      });
    } catch (e) {
      lastErr = e;
    }
  }
  throw lastErr || new Error("`claude` CLI not found");
}

const selfId = process.env.CLAUDE_CODE_SESSION_ID || process.env.CLAUDE_SESSION_ID || "";
const JOBS_DIR = join(CONFIG_DIR, "jobs");

function readState(s) {
  const direct = tryReadJson(join(JOBS_DIR, shortId(s), "state.json"));
  if (direct) return direct;
  if (existsSync(JOBS_DIR)) {
    for (const d of readdirSync(JOBS_DIR)) {
      const st = tryReadJson(join(JOBS_DIR, d, "state.json"));
      if (st && st.sessionId === s.sessionId) return st;
    }
  }
  return {};
}

function loadLive() {
  let sessions;
  try {
    sessions = JSON.parse(runAgentsJson());
  } catch {
    return []; // no CLI / no roster — parked notes may still answer the hint
  }
  if (!Array.isArray(sessions)) return [];
  return sessions
    .filter((s) => s.sessionId && s.sessionId !== selfId)
    .map((s) => {
      const st = readState(s);
      const goal = (st.intent || st.detail || "").trim();
      return {
        kind: "live",
        id: shortId(s),
        s,
        st,
        name: s.name || "(unnamed)",
        hay: `${s.name || ""} ${st.intent || ""} ${st.detail || ""}`.toLowerCase(),
        snippet: goal ? truncate(goal, SNIPPET_LEN) : "",
        age: fmtAge(s.startedAt),
        status: s.status || st.state || "?",
      };
    });
}

// ── 2. Parked Obsidian notes ───────────────────────────────────────────────
function parseFrontmatter(text) {
  const m = text.match(/^---\n([\s\S]*?)\n---\n?([\s\S]*)$/);
  if (!m) return { fm: {}, body: text };
  const fm = {};
  for (const line of m[1].split("\n")) {
    const mm = line.match(/^(\w+):\s*(.*)$/);
    if (mm) fm[mm[1]] = mm[2].trim();
  }
  return { fm, body: m[2] };
}

function loadParked() {
  if (!existsSync(PARK_DIR)) return [];
  return readdirSync(PARK_DIR)
    .filter((f) => f.endsWith(".md"))
    .map((f) => {
      const path = join(PARK_DIR, f);
      let raw = "";
      try {
        raw = readFileSync(path, "utf8");
      } catch {
        return null;
      }
      const { fm, body } = parseFrontmatter(raw);
      const title = fm.title?.replace(/^["']|["']$/g, "") || f.replace(/\.md$/, "");
      return {
        kind: "park",
        id: fm.short_id || f.replace(/\.md$/, "").slice(0, 12),
        path,
        file: f,
        fm,
        body,
        name: title,
        hay: `${title} ${fm.tags || ""} ${fm.cwd || ""} ${body}`.toLowerCase(),
        snippet: truncate(body.replace(/^#.*$/m, "").trim(), SNIPPET_LEN),
        age: fm.parked || "?",
        status: fm.status || "parked",
      };
    })
    .filter(Boolean);
}

// ── 3. Unified roster + scoring ────────────────────────────────────────────
const candidates = [...loadLive(), ...loadParked()];

if (candidates.length === 0) {
  die(
    "Nothing to pick up: no other live background sessions, and no parked notes in\n" +
      `  ${PARK_DIR}\nPark a session first with /park, or dispatch one with \`claude --bg\`.`,
  );
}

function score(c) {
  if (hint && c.id.toLowerCase().startsWith(hint)) return 1000; // explicit id wins
  let sc = 0;
  if (hint && c.name.toLowerCase().includes(hint)) sc += 5; // whole phrase in title/name
  const toks = hint.split(/\s+/).filter((t) => t.length > 2 && !STOP.has(t));
  for (const t of toks) if (c.hay.includes(t)) sc += 1;
  return sc;
}

function listLine(c) {
  const tag = c.kind === "live" ? "▶ live" : "■ park";
  return (
    `  - [${tag}] ${c.id}  [${c.status}]  ${c.name}  · ${c.age}${c.kind === "live" ? " ago" : ""}` +
    (c.snippet ? `\n        ${c.kind === "park" ? "" : "goal: "}${c.snippet}` : "")
  );
}

if (!hint) {
  const live = candidates.filter((c) => c.kind === "live");
  const park = candidates.filter((c) => c.kind === "park");
  const out = ["Pick up where something left off — re-run with `<name or what it was about>`:"];
  if (live.length) out.push("\nLive background sessions (resume):", ...live.map(listLine));
  if (park.length) out.push("\nParked snapshots (revive):", ...park.map(listLine));
  die(out.join("\n"));
}

const ranked = candidates.map((c) => ({ c, score: score(c) })).sort((a, b) => b.score - a.score);
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

const target = top.c;

// ── 4a. Revive a parked note ───────────────────────────────────────────────
if (target.kind === "park") {
  const out = [
    `## Revive parked session: "${target.name}"`,
    `note: ${target.path}`,
    `parked: ${target.fm.parked || "?"}   cwd: ${target.fm.cwd || "?"}   branch: ${target.fm.branch || "?"}   status: ${target.fm.status || "?"}`,
    "",
    "This session is dead — its live transcript may be gone. Revive from the snapshot",
    "below: read it, then continue the work from its Next steps in the noted cwd.",
    "",
    "---",
    truncate(target.body, MAX_NOTE_BODY).replace(/…$/, "\n\n…(note truncated — read the full file above)"),
  ];
  console.log(out.join("\n"));
  process.exit(0);
}

// ── 4b. Resume a live session (continue-from behavior) ─────────────────────
const s = target.s;
const st = target.st;
const sid = s.sessionId;
const intent = (st.intent || "").trim();
const detail = (st.detail || "").trim();
const state = st.state || s.status || "";

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
  if (!tpath) return "(transcript not found on disk — it may have been cleaned up; consider /park next time)";
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

const out = [
  `## Resume live session: "${s.name}"  (${target.id}, state: ${state})`,
  `cwd: ${s.cwd || "?"}`,
  "",
];
if (intent) out.push("### Goal it was given", intent, "");
if (detail) out.push("### Where it left off / last status", detail, "");
out.push("### Recent activity (newest last)", recentActivity());
console.log(out.join("\n"));
