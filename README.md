# Prometheus Framework

A framework for non-engineering teams to build and deploy their own tools using Claude. You get a sandbox with guardrails, and you ship when you're ready.

## The Mission: Field → Core

Traba's core job is to keep going out into the field, learn what works, and bring those operational learnings back into the core product. We're building an **operational machine that keeps extracting signal from the edge and feeding it back into the product**.

Projects move through a pipeline based on demand:

- **Tier 3 — Local prototype:** Operators prototyping fast, failing fast, trying many things. Runs on your machine.
- **Tier 2 — Shared tool:** Winners that survived natural selection, deployed and shared with the team. Has a URL, auth, and persistence.
- **Tier 1 — Core product:** Re-implemented from first principles into the core product.

The natural course is: you build something, others want it, it gets deployed, and if it's valuable enough it becomes part of the core product. Going from a local prototype to a shared tool should be on rails and self-service, with minimal engineering involvement.

## Setup

Before your first project, you need the Traba skills installed. You install once, and updates propagate automatically as the team improves the skills.

You'll need a terminal for these steps. Open Terminal and run the following:

**Step 1 — Clone the skills repo:**

```bash
git clone https://github.com/Traba-Ops/claude-config.git ~/.traba-config
```

**Step 2 — Copy skills and rules into Claude:**

```bash
cp -r ~/.traba-config/skills/* ~/.claude/skills/
cp -r ~/.traba-config/rules/* ~/.claude/rules/
```

**Step 3 — Set up automatic updates:**

Ask Claude to keep your skills current:

> "Set up a launchd job that pulls `~/.traba-config` and copies its skills and rules to `~/.claude` twice a day at 10 AM and 7 PM"

That's it. From here, just open Claude (terminal or Claude Cowork) and start building. Skills update themselves in the background.

## What You Get

Once you install the Prometheus skills, Claude is pre-configured with:

- **Stack and toolchain:** every project uses a consistent stack with the latest, fastest tooling, which makes it easy to share and promote later
- **Security rules:** your app handles sensitive data safely from day one
- **Design language:** your app looks and feels like a Traba product from the start
- **Development hygiene:** your project builds up documentation naturally as you work, making it easy for others to pick up or for engineers to promote later
- **Deployment guidance:** when it's time to share your app, Claude already knows how to get it deployed
- **Automatic updates:** as we push improvements to the skill bundle, every project gets them automatically

## Concepts You Should Know

Claude will handle most of the technical complexity, but you should be familiar with these general concepts. If you're interested, the footnotes explain a bit more what's happening under the hood.

- **Checkpoints:** Save your progress at any time by telling Claude "checkpoint this." Think of it like Google Docs version history, but for code. You can always go back. [^1]

- **Secrets:** API keys, passwords, and tokens that connect your app to other services. These should never be shared, pasted in Slack, or put directly in code. When your app needs a secret, an engineer will set it up for you. [^2]

- **Deploying:** Making your app available at a URL so other people can use it. Your app starts by running only on your machine. When others want access, post in **#claudecodestuff** or reach out to Sumeet or Jeff directly. [^3]

- **The Spec:** As you build, Claude keeps two documents up to date: a README that explains what your app does and how to use it, and a spec with the technical details an engineer would need to rebuild it. You don't write either one.

## Beyond the Pipeline: Shipping to Core Directly

The pipeline assumes a handoff between operators and engineers. But we're already experimenting with operators shipping directly to the core codebase: the marketing team (MDS, Kanellis) submitting small PRs, Rohan shipping an entire feature end-to-end. Within EPD we're also exploring options to accelerate AI agents working within our codebase like preview environments and automated review safety nets. In the near-term, we will enable operators to efficiently ship full-stack features safely and mostly autonomously with minimal engineering lift.

## Internal Reference (Engineers)

| Document | Purpose |
|----------|---------|
| [Prescriptive Stack](docs/stack.md) | What to use and why — the full technology prescription |
| [Security Guardrails](docs/security.md) | Hard checks, SDLC controls, and infrastructure-level protections |
| [Promotion Pipeline](docs/pipeline.md) | How projects move from prototype to production, and how specs accumulate |
| [Skill Bundle Spec](docs/skill-bundle-spec.md) | What goes into the Claude skills bundle and how it's delivered |
| [Open Questions](docs/open-questions.md) | Gaps, deferred decisions, and things to watch |

---

## Footnotes

[^1]: **How checkpoints work.** Under the hood, Claude uses **git**. Each checkpoint is a **commit** — a snapshot of every file in your project at that moment, with a message describing what changed. Commits form a timeline you can jump back to at any point.

[^2]: **Why secrets matter.** An API key is like a password that lets your app talk to another service (a database, a payment processor, an AI model). If someone gets your API key, they can use that service as you — reading your data, running up your bill, or worse. Secrets go in a secure vault (we use Infisical), never in code, never in Slack, never in a document.

[^3]: **What deployment means.** When your app runs on `localhost`, that literally means "this computer" — nobody else can see it. Deploying copies your app to a server in the cloud (we use Railway) that runs it 24/7 and gives it a URL. We put an authentication layer in front (Cloudflare Zero Trust) so only people with a `@traba.work` email can access it.
