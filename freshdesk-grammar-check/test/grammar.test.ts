import { describe, expect, it } from "vitest";
import { parseGrammarResponse } from "../src/grammar.ts";

describe("parseGrammarResponse", () => {
  it("parses a clean result", () => {
    const r = parseGrammarResponse('{"issues": []}');
    expect(r.hasIssues).toBe(false);
    expect(r.issues).toEqual([]);
  });

  it("parses issues", () => {
    const r = parseGrammarResponse(
      '{"issues": [{"quote": "recieve", "suggestion": "receive", "type": "spelling", "explanation": "i before e."}]}',
    );
    expect(r.hasIssues).toBe(true);
    expect(r.issues[0]?.quote).toBe("recieve");
    expect(r.issues[0]?.suggestion).toBe("receive");
    expect(r.issues[0]?.type).toBe("spelling");
  });

  it("tolerates markdown code fences around the JSON", () => {
    const r = parseGrammarResponse('```json\n{"issues": []}\n```');
    expect(r.hasIssues).toBe(false);
  });

  it("fills defaults for missing fields", () => {
    const r = parseGrammarResponse('{"issues": [{"quote": "x"}]}');
    expect(r.issues[0]?.type).toBe("grammar");
    expect(r.issues[0]?.suggestion).toBe("");
  });

  it("throws on non-JSON", () => {
    expect(() => parseGrammarResponse("not json at all")).toThrow();
  });

  it("throws when issues is not an array", () => {
    expect(() => parseGrammarResponse('{"issues": "nope"}')).toThrow();
  });
});
