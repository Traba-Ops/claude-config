import { describe, expect, it } from "vitest";
import { selectAgentReplies, type FreshdeskConversation, type FreshdeskTicket } from "../src/freshdesk.ts";

const ticket: FreshdeskTicket = {
  id: 42,
  subject: "Payout question",
  group_id: 7,
  responder_id: 100,
  updated_at: "2026-07-02T12:00:00Z",
};

function conv(overrides: Partial<FreshdeskConversation>): FreshdeskConversation {
  return {
    id: 1,
    body_text: "Thanks for reaching out.",
    incoming: false,
    private: false,
    user_id: 100,
    created_at: "2026-07-02T11:00:00Z",
    ...overrides,
  };
}

const since = new Date("2026-07-02T10:00:00Z");
const url = "https://acme.freshdesk.com/a/tickets/42";

describe("selectAgentReplies", () => {
  it("keeps public outbound agent replies after the watermark", () => {
    const replies = selectAgentReplies(ticket, [conv({ id: 1 })], since, null, url);
    expect(replies).toHaveLength(1);
    expect(replies[0]?.conversationId).toBe(1);
    expect(replies[0]?.ticketId).toBe(42);
    expect(replies[0]?.url).toBe(url);
  });

  it("drops incoming (customer) messages", () => {
    const replies = selectAgentReplies(ticket, [conv({ id: 2, incoming: true })], since, null, url);
    expect(replies).toHaveLength(0);
  });

  it("drops private notes", () => {
    const replies = selectAgentReplies(ticket, [conv({ id: 3, private: true })], since, null, url);
    expect(replies).toHaveLength(0);
  });

  it("drops replies at or before the watermark", () => {
    const replies = selectAgentReplies(
      ticket,
      [conv({ id: 4, created_at: "2026-07-02T09:59:59Z" })],
      since,
      null,
      url,
    );
    expect(replies).toHaveLength(0);
  });

  it("drops empty replies", () => {
    const replies = selectAgentReplies(ticket, [conv({ id: 5, body_text: "   " })], since, null, url);
    expect(replies).toHaveLength(0);
  });

  it("restricts to the given agent ids when provided", () => {
    const replies = selectAgentReplies(
      ticket,
      [conv({ id: 6, user_id: 100 }), conv({ id: 7, user_id: 999 })],
      since,
      [100],
      url,
    );
    expect(replies.map((r) => r.conversationId)).toEqual([6]);
  });
});
