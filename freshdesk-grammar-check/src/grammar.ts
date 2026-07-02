// Grammar judgment via the Anthropic Messages API.
// We ask the model to return strict JSON describing any issues it finds so the
// deterministic parts of the worker (dedupe, Slack formatting) stay simple.

import type { Config, Strictness } from "./config.ts";

export interface GrammarIssue {
  quote: string; // the exact problematic text from the reply
  suggestion: string; // the corrected version
  type: string; // e.g. "spelling", "grammar", "punctuation", "clarity", "tone"
  explanation: string; // one short sentence
}

export interface GrammarResult {
  hasIssues: boolean;
  issues: GrammarIssue[];
}

const ANTHROPIC_URL = "https://api.anthropic.com/v1/messages";
const ANTHROPIC_VERSION = "2023-06-01";

function scopeForStrictness(strictness: Strictness): string {
  switch (strictness) {
    case "errors":
      return "Flag ONLY objective spelling, grammar, punctuation, and verb-agreement mistakes. Do NOT flag style, tone, clarity, or formatting. When in doubt, do not flag.";
    case "clarity":
      return "Flag spelling, grammar, and punctuation mistakes, plus genuinely awkward, confusing, or unclear phrasing and clearly off-tone wording for a customer support reply. Do not nitpick acceptable stylistic choices.";
    case "all":
      return "Flag spelling, grammar, punctuation, clarity, tone, capitalization, and formatting issues that would make this reply look less professional to a customer.";
  }
}

function buildSystemPrompt(strictness: Strictness): string {
  return [
    "You are a meticulous proofreader for a customer support team.",
    "You review the text of a single reply an agent sent to a customer.",
    scopeForStrictness(strictness),
    "Ignore URLs, email signatures, names, product names, ticket numbers, and placeholders.",
    "Return ONLY a JSON object, no prose, no markdown fences, matching exactly:",
    '{"issues": [{"quote": string, "suggestion": string, "type": string, "explanation": string}]}',
    'If the reply is clean, return {"issues": []}.',
    "Each quote MUST be an exact substring of the reply. Keep explanations to one short sentence.",
  ].join(" ");
}

export function parseGrammarResponse(raw: string): GrammarResult {
  // The model is instructed to return bare JSON, but strip accidental fences just in case.
  const cleaned = raw.trim().replace(/^```(?:json)?/i, "").replace(/```$/i, "").trim();
  let parsed: unknown;
  try {
    parsed = JSON.parse(cleaned);
  } catch {
    throw new Error(`Grammar model did not return valid JSON: ${raw.slice(0, 500)}`);
  }
  const issuesRaw = (parsed as { issues?: unknown }).issues;
  if (!Array.isArray(issuesRaw)) {
    throw new Error(`Grammar model JSON missing "issues" array: ${cleaned.slice(0, 500)}`);
  }
  const issues: GrammarIssue[] = issuesRaw.map((i) => {
    const o = i as Record<string, unknown>;
    return {
      quote: String(o.quote ?? ""),
      suggestion: String(o.suggestion ?? ""),
      type: String(o.type ?? "grammar"),
      explanation: String(o.explanation ?? ""),
    };
  });
  return { hasIssues: issues.length > 0, issues };
}

export async function checkGrammar(
  text: string,
  cfg: Config["anthropic"],
  strictness: Strictness,
): Promise<GrammarResult> {
  const res = await fetch(ANTHROPIC_URL, {
    method: "POST",
    headers: {
      "x-api-key": cfg.apiKey,
      "anthropic-version": ANTHROPIC_VERSION,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      model: cfg.model,
      max_tokens: 1024,
      system: buildSystemPrompt(strictness),
      messages: [{ role: "user", content: `Reply to review:\n\n"""\n${text}\n"""` }],
    }),
  });

  if (!res.ok) {
    const body = await res.text().catch(() => "");
    throw new Error(`Anthropic request failed: ${res.status} ${res.statusText} ${body}`);
  }

  const data = (await res.json()) as { content?: Array<{ type: string; text?: string }> };
  const textBlock = data.content?.find((b) => b.type === "text")?.text ?? "";
  return parseGrammarResponse(textBlock);
}
