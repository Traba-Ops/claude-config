// Minimal Freshdesk API v2 client.
// Auth is HTTP Basic with the API key as the username and any string as the password.
// Docs: https://developers.freshdesk.com/api/

import type { Config } from "./config.ts";

export interface FreshdeskTicket {
  id: number;
  subject: string;
  group_id: number | null;
  responder_id: number | null;
  updated_at: string;
}

export interface FreshdeskConversation {
  id: number;
  ticket_id?: number;
  body_text: string;
  incoming: boolean; // true = message from the requester (customer)
  private: boolean; // true = internal note, not sent to the customer
  user_id: number | null; // author (agent) id for outgoing replies
  created_at: string;
}

// A public, outbound reply written by an agent — the thing we grammar-check.
export interface AgentReply {
  ticketId: number;
  ticketSubject: string;
  conversationId: number;
  agentId: number | null;
  createdAt: string;
  text: string;
  url: string;
}

export class FreshdeskClient {
  private readonly base: string;
  private readonly authHeader: string;

  constructor(private readonly cfg: Config["freshdesk"]) {
    this.base = `https://${cfg.domain}.freshdesk.com/api/v2`;
    // Basic auth: base64("<apiKey>:X"). The password is ignored by Freshdesk.
    this.authHeader = `Basic ${btoa(`${cfg.apiKey}:X`)}`;
  }

  ticketUrl(ticketId: number): string {
    return `https://${this.cfg.domain}.freshdesk.com/a/tickets/${ticketId}`;
  }

  private async get<T>(path: string): Promise<{ data: T; linkHeader: string | null }> {
    const url = `${this.base}${path}`;
    for (let attempt = 0; attempt < 5; attempt++) {
      const res = await fetch(url, {
        headers: { Authorization: this.authHeader, "Content-Type": "application/json" },
      });

      // Freshdesk returns 429 with a Retry-After header when rate limited.
      if (res.status === 429) {
        const retryAfter = Number.parseInt(res.headers.get("Retry-After") ?? "5", 10);
        await sleep((Number.isNaN(retryAfter) ? 5 : retryAfter) * 1000);
        continue;
      }
      if (!res.ok) {
        const body = await res.text().catch(() => "");
        throw new Error(`Freshdesk GET ${path} failed: ${res.status} ${res.statusText} ${body}`);
      }
      return { data: (await res.json()) as T, linkHeader: res.headers.get("link") };
    }
    throw new Error(`Freshdesk GET ${path} failed after retries (rate limited).`);
  }

  // Tickets updated since `since`, oldest first, following pagination.
  async listTicketsUpdatedSince(since: Date, maxTickets: number): Promise<FreshdeskTicket[]> {
    const tickets: FreshdeskTicket[] = [];
    let page = 1;
    while (tickets.length < maxTickets) {
      const path =
        `/tickets?updated_since=${encodeURIComponent(since.toISOString())}` +
        `&order_by=updated_at&order_type=asc&per_page=100&page=${page}`;
      const { data, linkHeader } = await this.get<FreshdeskTicket[]>(path);
      tickets.push(...data);
      // Freshdesk signals "more pages" via a Link: <...>; rel="next" header.
      if (!linkHeader?.includes('rel="next"') || data.length === 0) break;
      page++;
    }
    return tickets.slice(0, maxTickets);
  }

  async listConversations(ticketId: number): Promise<FreshdeskConversation[]> {
    const conversations: FreshdeskConversation[] = [];
    let page = 1;
    while (true) {
      const { data, linkHeader } = await this.get<FreshdeskConversation[]>(
        `/tickets/${ticketId}/conversations?per_page=100&page=${page}`,
      );
      conversations.push(...data);
      if (!linkHeader?.includes('rel="next"') || data.length === 0) break;
      page++;
    }
    return conversations;
  }
}

// Pure filter — no I/O — so it can be unit tested.
// Keeps public, outbound agent replies created strictly after `since`,
// optionally restricted to a set of agent ids.
export function selectAgentReplies(
  ticket: FreshdeskTicket,
  conversations: FreshdeskConversation[],
  since: Date,
  agentIds: number[] | null,
  ticketUrl: string,
): AgentReply[] {
  return conversations
    .filter((c) => !c.incoming && !c.private) // outbound + public only
    .filter((c) => new Date(c.created_at) > since)
    .filter((c) => (agentIds ? c.user_id != null && agentIds.includes(c.user_id) : true))
    .filter((c) => c.body_text.trim().length > 0)
    .map((c) => ({
      ticketId: ticket.id,
      ticketSubject: ticket.subject,
      conversationId: c.id,
      agentId: c.user_id,
      createdAt: c.created_at,
      text: c.body_text.trim(),
      url: ticketUrl,
    }));
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
