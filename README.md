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

Before your first project, you need the Traba skills installed. You install once, and updates pull automatically in the background.

First, make sure git knows who you are (needed for checkpoints later):

```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@traba.work"
```

Then run the installer:

```bash
curl -fsSL https://raw.githubusercontent.com/Traba-Ops/claude-config/main/install.sh | sh
```

Then open **Claude Code** (either in the terminal or the Code tab in the Claude app) and ask it to set up automatic updates:

> "Set up a launchd job that runs `cd ~/.claude && git pull` every hour between 9 AM and 9 PM"

That's it. From here, just open Claude Code and start building. Skills update themselves in the background.

> **Note:** The setup prompt above must be run in **Claude Code** — it won't work in the Chat or Co-work tabs of the Claude app.

## What You Get

Once you install the Prometheus skills, Claude is pre-configured with:

- **Stack and toolchain:** every project uses a consistent stack with the latest, fastest tooling, which makes it easy to share and promote later
- **Security rules:** your app handles sensitive data safely from day one
- **Design language:** your app looks and feels like a Traba product from the start
- **Development hygiene:** your project builds up documentation naturally as you work, making it easy for others to pick up or for engineers to promote later
- **Deployment guidance:** when it's time to share your app, Claude already knows how to get it deployed
- **Automatic updates:** as we push improvements, every project gets them automatically

## Concepts You Should Know

Claude will handle most of the technical complexity, but you should be familiar with these general concepts. If you're interested, the footnotes explain a bit more what's happening under the hood.

- **Checkpoints:** Save your progress at any time by telling Claude "checkpoint this." Think of it like Google Docs version history, but for code. You can always go back. Claude will also suggest checkpointing when you finish something or switch to a different task. [^1]

- **Secrets:** API keys, passwords, and tokens that connect your app to other services. These should never be shared, pasted in Slack, or put directly in code. When your app needs a secret, an engineer will set it up for you. [^2]

- **Deploying:** Making your app available at a URL so other people can use it. Your app starts by running only on your machine. When others want access, post in **#claudecodestuff** or reach out to Sumeet or Jeff directly. Engineers: see the [eng runbook](docs/eng-runbook.md). [^3]

- **The Spec:** As you build, Claude keeps two documents up to date: a README that explains what your app does and how to use it, and a spec with the technical details an engineer would need to rebuild it. You don't write either one.

## Beyond the Pipeline: Shipping to Core Directly

The pipeline assumes a handoff between operators and engineers. But we're already experimenting with operators shipping directly to the core codebase: the marketing team (MDS, Kanellis) submitting small PRs, Rohan shipping an entire feature end-to-end. Within EPD we're also exploring options to accelerate AI agents working within our codebase like preview environments and automated review safety nets. The goal is to get operators shipping full-stack features independently, with minimal engineering lift.

## Internal Reference (Engineers)

| Document | Purpose |
|----------|---------|
| [Eng Runbook](docs/eng-runbook.md) | Step-by-step: getting an operator from zero to deployed |
| [Admin Operations](docs/admin.md) | Automated maintenance, access provisioning, cost tracking |
| [Prescriptive Stack](docs/stack.md) | What to use and why — the full technology prescription |
| [Security Guardrails](docs/security.md) | Hard checks, SDLC controls, and infrastructure-level protections |
| [Promotion Pipeline](docs/pipeline.md) | How projects move from prototype to production, and how specs accumulate |
| [Skill Bundle Spec](docs/skill-bundle-spec.md) | What goes into the Claude skills bundle and how it's delivered |
| [Open Questions](docs/open-questions.md) | Gaps, deferred decisions, and things to watch |

---

## Footnotes

[^1]: **How checkpoints work.** Under the hood, Claude uses **git**. Each checkpoint is a **commit** — a snapshot of every file in your project at that moment, with a message describing what changed. Commits form a timeline you can jump back to at any point.

[^2]: **Why secrets matter.** An API key is like a password that lets your app talk to another service (a database, a payment processor, an AI model). If someone gets your API key, they can use that service as you — reading your data, running up your bill, or worse. Secrets go in Railway environment variables for deployed apps and `.env` files locally, never in code, never in Slack, never in a document.

[^3]: **What deployment means.** When your app runs on `localhost`, that literally means "this computer" — nobody else can see it. Deploying copies your app to a server in the cloud (we use Railway) that runs it 24/7 and gives it a URL. We put an authentication layer in front (Cloudflare Zero Trust) so only people with a `@traba.work` email can access it.
