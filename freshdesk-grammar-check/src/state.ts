// Dedupe + watermark state, persisted as a small JSON file in ./data (gitignored).
// Keeps us from re-alerting on the same reply and tells us how far back to look.

import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname } from "node:path";

export interface State {
  // ISO timestamp of the newest reply we've considered. Next run looks after this.
  lastRunAt: string | null;
  // Conversation ids we've already alerted on, so retries don't double-ping.
  alerted: number[];
}

const STATE_PATH = new URL("../data/state.json", import.meta.url).pathname;
const MAX_REMEMBERED = 5000; // cap the alerted list so the file can't grow forever

export async function loadState(): Promise<State> {
  try {
    const raw = await readFile(STATE_PATH, "utf8");
    const parsed = JSON.parse(raw) as Partial<State>;
    return {
      lastRunAt: parsed.lastRunAt ?? null,
      alerted: Array.isArray(parsed.alerted) ? parsed.alerted : [],
    };
  } catch {
    return { lastRunAt: null, alerted: [] };
  }
}

export async function saveState(state: State): Promise<void> {
  const trimmed: State = {
    lastRunAt: state.lastRunAt,
    alerted: state.alerted.slice(-MAX_REMEMBERED),
  };
  await mkdir(dirname(STATE_PATH), { recursive: true });
  await writeFile(STATE_PATH, JSON.stringify(trimmed, null, 2), "utf8");
}
