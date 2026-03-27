# Promotion Pipeline

## Tiers

```
Tier 3: Local prototype
  │  Threshold: others want to use it
  ▼
Tier 2: Shared tool (deployed, auth-gated)
  │  Threshold: EPD decision + spec ready
  ▼
Tier 1: Core product
```

At the edge, the goal is **natural selection**. Operators prototype fast, fail fast, try many things, and discard what doesn't work. Winners emerge organically — one operator builds something, the people around them start using it, and it picks up traction. That traction signal is what triggers promotion.

---

## Tier 3: Local Prototype

**What it is:** A project running on someone's machine. Built with Claude, tested locally, used by the person who built it.

**Infrastructure:** None. Everything runs locally.

**Requirements:**
- Must be in a git repo with local commits (skills enforce this)
- `.gitignore` must include secrets and data files (skills enforce this)
- Pre-commit hook for gitleaks (skills scaffold this automatically)

No other requirements — no GitHub, no tests, no code review, no specific architecture.

**Who can do this:** Anyone at Traba with a Claude subscription.

---

## Tier 2: Shared Tool

**What it is:** A deployed application that multiple people use. Has a URL, auth, and persistence.

**Promotion trigger:** Others want to use it. Someone says "can I get access to that?" and the answer is "let's deploy it."

**How promotion works:**

Most of the setup can be done by the operator with Claude. Engineers provide access and a quick review.

1. **Request access.** The builder asks in #claudecodestuff or reaches out to Sumeet/Jeff.

2. **What the operator does (with Claude):**
   - Create a GitHub repo in the `traba-ops` org
   - Push the code
   - Deploy to Railway (single service: backend serves frontend as static files)

3. **What an engineer does:**
   - Grant access to Railway and Supabase (if needed)
   - Quick review of the code for obvious security issues
   - Add secrets as Railway environment variables
   - Configure Cloudflare Access (email domain restriction for @traba.work)

4. **Post-setup:**
   - Builder pushes directly to main — deploys are automatic
   - GitHub Actions run gitleaks (secret scanning) and a basic build check on push

See [Prescriptive Stack](stack.md) for full infrastructure details.

---

## Tier 1: Core Codebase Integration

**What it is:** The project's functionality is valuable enough to be part of the core Traba product or infrastructure.

**Promotion trigger:** EPD decision + a ready spec. This is rare and handled case by case.

You can't graft externally developed code onto the core product. A shared tool was built in a sandbox with different constraints and architecture. Promoting to core means **re-implementing from first principles**: what problem does this solve, how does it fit into the broader product, and what's the right way to build it within the core architecture.

The code is often irrelevant. What matters is the *spec*: the accumulated understanding of what the app does, what decisions were made, and what edge cases were discovered. **The spec is what gets promoted, not the code.**

### How specs accumulate

The Prometheus workflow generates spec artifacts as a byproduct of normal development. None of these require effort from the builder:

1. **Frequent, descriptive commits:** Operators checkpoint their work by telling Claude to commit. Claude writes a message that explains *what* and *why*. The commit log is a narrative of how the app was built.

2. **Project context:** The README.md captures what the app does, the data model, user workflows, and known limitations. Skills instruct Claude to keep it current — updating it as the project evolves, not just at the end of a session.

3. **Session summaries** (`sessions/`): At the end of each work session, Claude writes a brief log: what was worked on, decisions made, open questions.

4. **Decision records** (`decisions/`): When a non-trivial choice is made (e.g., "used polling instead of websockets because the data only changes hourly"), Claude captures it.

5. **Claude Code session transcripts:** Raw interaction logs between the builder and Claude. Capture intent and reasoning that don't make it into commits.

When an EPD decision is made to promote, an engineer (or Claude) synthesizes these artifacts into a first-principles spec:

> "Generate a product spec from this project's commit history, README.md, session logs, decisions, and Claude Code transcripts. Focus on the problem being solved and the requirements, not the implementation details. This spec will be used to re-implement from scratch in the core codebase."

That spec is used to rebuild in the core repo with full production standards (code review, tests, proper architecture). The original prototype may keep running during transition.

### What can go wrong

- Sessions that are too long without summaries lose context (skills instruct Claude to summarize at natural stopping points)
- Infrequent commits make the log useless (operators should checkpoint regularly)
- Project context not maintained between sessions (skills instruct Claude to update README.md when discovering important details)

---

## Role Responsibilities

### Builder (Ops / non-engineer)
- Builds with Claude locally
- Requests promotion when others want to use it
- Sets up GitHub repo and deployment (with Claude) once an engineer grants access
- Pushes directly to main on their own repos

### Engineer (promotion facilitator)
- Grants access to infrastructure (Railway, Cloudflare, Supabase)
- Quick security review of the code
- Adds secrets as Railway environment variables and sets up auth (Cloudflare Access)

### Claude (orchestrator)
- Enforces the prescriptive stack via skills
- Scaffolds projects with correct `.gitignore`, pre-commit hooks, and structure
