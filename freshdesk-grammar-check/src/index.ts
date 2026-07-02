// Entry point. One pass = fetch recent agent replies, grammar-check the new
// ones, alert on Slack for any with issues, then persist state. A scheduler
// (LaunchAgent / Railway cron) invokes this on an interval; it is not a daemon.

import { loadConfig } from "./config.ts";
import { FreshdeskClient, selectAgentReplies, type AgentReply } from "./freshdesk.ts";
import { checkGrammar } from "./grammar.ts";
import { sendAlert } from "./slack.ts";
import { loadState, saveState } from "./state.ts";

async function main(): Promise<void> {
  const cfg = loadConfig();
  const state = await loadState();
  const freshdesk = new FreshdeskClient(cfg.freshdesk);

  const since = state.lastRunAt
    ? new Date(state.lastRunAt)
    : new Date(Date.now() - cfg.lookbackHours * 60 * 60 * 1000);

  console.log(
    `[${new Date().toISOString()}] scanning tickets updated since ${since.toISOString()}` +
      (cfg.dryRun ? " (dry run — no Slack alerts)" : ""),
  );

  const tickets = await freshdesk.listTicketsUpdatedSince(since, cfg.maxTickets);
  const scoped = cfg.freshdesk.groupId
    ? tickets.filter((t) => String(t.group_id) === cfg.freshdesk.groupId)
    : tickets;

  const alerted = new Set(state.alerted);
  let newestSeen = since;
  let checked = 0;
  let flagged = 0;

  for (const ticket of scoped) {
    const conversations = await freshdesk.listConversations(ticket.id);
    const replies = selectAgentReplies(
      ticket,
      conversations,
      since,
      cfg.freshdesk.agentIds,
      freshdesk.ticketUrl(ticket.id),
    );

    for (const reply of replies) {
      const createdAt = new Date(reply.createdAt);
      if (createdAt > newestSeen) newestSeen = createdAt;
      if (alerted.has(reply.conversationId)) continue;

      checked++;
      const result = await checkGrammar(reply.text, cfg.anthropic, cfg.strictness);
      if (!result.hasIssues) continue;

      flagged++;
      logFlag(reply, result.issues.length);
      if (!cfg.dryRun) {
        await sendAlert(cfg.slack.botToken, cfg.slack.target, reply, result);
      }
      alerted.add(reply.conversationId);
    }
  }

  await saveState({ lastRunAt: newestSeen.toISOString(), alerted: [...alerted] });
  console.log(
    `[${new Date().toISOString()}] done: ${scoped.length} tickets, ${checked} new replies checked, ${flagged} flagged.`,
  );
}

function logFlag(reply: AgentReply, issueCount: number): void {
  console.log(`  flagged ticket #${reply.ticketId} conv ${reply.conversationId}: ${issueCount} issue(s)`);
}

main().catch((err) => {
  console.error("freshdesk-grammar-check failed:", err instanceof Error ? err.message : err);
  process.exit(1);
});
