// Loads and validates configuration from environment variables.
// Fails fast with a clear message so a non-engineer can see exactly what's missing.

export type Strictness = "errors" | "clarity" | "all";

export interface Config {
  freshdesk: {
    domain: string;
    apiKey: string;
    groupId: string | null;
    agentIds: number[] | null;
  };
  anthropic: {
    apiKey: string;
    model: string;
  };
  slack: {
    botToken: string;
    target: string;
  };
  strictness: Strictness;
  lookbackHours: number;
  maxTickets: number;
  dryRun: boolean;
}

function required(name: string): string {
  const value = process.env[name]?.trim();
  if (!value) {
    throw new Error(
      `Missing required environment variable: ${name}. ` +
        `Copy .env.example to .env and fill it in (see README.md).`,
    );
  }
  return value;
}

function optional(name: string): string | null {
  const value = process.env[name]?.trim();
  return value ? value : null;
}

function parseIntEnv(name: string, fallback: number): number {
  const raw = process.env[name]?.trim();
  if (!raw) return fallback;
  const n = Number.parseInt(raw, 10);
  if (Number.isNaN(n) || n <= 0) {
    throw new Error(`Environment variable ${name} must be a positive integer, got "${raw}".`);
  }
  return n;
}

function parseStrictness(raw: string | null): Strictness {
  const value = (raw ?? "errors").toLowerCase();
  if (value === "errors" || value === "clarity" || value === "all") return value;
  throw new Error(`STRICTNESS must be one of "errors", "clarity", "all" (got "${raw}").`);
}

export function loadConfig(argv: string[] = process.argv.slice(2)): Config {
  const agentIdsRaw = optional("FRESHDESK_AGENT_IDS");
  const agentIds = agentIdsRaw
    ? agentIdsRaw
        .split(",")
        .map((s) => Number.parseInt(s.trim(), 10))
        .filter((n) => !Number.isNaN(n))
    : null;

  return {
    freshdesk: {
      domain: required("FRESHDESK_DOMAIN"),
      apiKey: required("FRESHDESK_API_KEY"),
      groupId: optional("FRESHDESK_GROUP_ID"),
      agentIds: agentIds && agentIds.length > 0 ? agentIds : null,
    },
    anthropic: {
      apiKey: required("ANTHROPIC_API_KEY"),
      model: optional("ANTHROPIC_MODEL") ?? "claude-haiku-4-5-20251001",
    },
    slack: {
      botToken: required("SLACK_BOT_TOKEN"),
      target: required("SLACK_TARGET"),
    },
    strictness: parseStrictness(optional("STRICTNESS")),
    lookbackHours: parseIntEnv("LOOKBACK_HOURS", 24),
    maxTickets: parseIntEnv("MAX_TICKETS", 200),
    dryRun: argv.includes("--dry-run"),
  };
}
