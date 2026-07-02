// Posts grammar alerts to Slack via chat.postMessage.
// SLACK_TARGET can be a channel id (C…) or a user id (U…) — posting to a user id
// opens a DM automatically, so "ping me" and "post to a channel" share one path.

import type { AgentReply } from "./freshdesk.ts";
import type { GrammarResult } from "./grammar.ts";

const SLACK_URL = "https://slack.com/api/chat.postMessage";

export function buildAlertBlocks(reply: AgentReply, result: GrammarResult): unknown[] {
  const issueLines = result.issues
    .map(
      (i) =>
        `• *${i.type}* — "${truncate(i.quote, 120)}" → "${truncate(i.suggestion, 120)}"` +
        (i.explanation ? `\n   _${i.explanation}_` : ""),
    )
    .join("\n");

  return [
    {
      type: "header",
      text: { type: "plain_text", text: "📝 Grammar check flagged a reply" },
    },
    {
      type: "section",
      fields: [
        { type: "mrkdwn", text: `*Ticket:*\n<${reply.url}|#${reply.ticketId} — ${truncate(reply.ticketSubject, 80)}>` },
        { type: "mrkdwn", text: `*Agent ID:*\n${reply.agentId ?? "unknown"}` },
      ],
    },
    {
      type: "section",
      text: { type: "mrkdwn", text: `*Issues (${result.issues.length}):*\n${issueLines}` },
    },
    {
      type: "context",
      elements: [
        { type: "mrkdwn", text: `Reply sent ${reply.createdAt} · conversation ${reply.conversationId}` },
      ],
    },
  ];
}

export async function sendAlert(
  botToken: string,
  target: string,
  reply: AgentReply,
  result: GrammarResult,
): Promise<void> {
  const res = await fetch(SLACK_URL, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${botToken}`,
      "Content-Type": "application/json; charset=utf-8",
    },
    body: JSON.stringify({
      channel: target,
      text: `Grammar check flagged reply on ticket #${reply.ticketId}`, // fallback for notifications
      blocks: buildAlertBlocks(reply, result),
    }),
  });

  const data = (await res.json()) as { ok: boolean; error?: string };
  if (!data.ok) {
    throw new Error(`Slack chat.postMessage failed: ${data.error ?? "unknown error"}`);
  }
}

function truncate(s: string, max: number): string {
  return s.length > max ? `${s.slice(0, max - 1)}…` : s;
}
