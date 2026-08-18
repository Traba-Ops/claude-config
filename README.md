# Prometheus Framework - DEPRECATED

**This repo is deprecated.** Claude config distribution — skills, rules, and agents — now
lives in [Bazaar](https://relay.traba.work/bazaar): browse and subscribe there, and assets
sync to your machine automatically. Nothing in this repo is maintained. The mission it was
built for stands, below.

## The Mission: Field → Core

Traba's core job is to keep going out into the field, learn what works, and bring those operational learnings back into the core product. We're building an **operational machine that keeps extracting signal from the edge and feeding it back into the product**.

Projects move through a pipeline based on demand:

- **Tier 3 — Local prototype:** Operators prototyping fast, failing fast, trying many things. Runs on your machine.
- **Tier 2 — Shared tool:** Winners that survived natural selection, deployed and shared with the team. Has a URL, auth, and persistence.
- **Tier 1 — Core product:** Re-implemented from first principles into the core product.

The natural course is: you build something, others want it, it gets deployed, and if it's valuable enough it becomes part of the core product. Going from a local prototype to a shared tool should be on rails and self-service, with minimal engineering involvement.

## Beyond the Pipeline: Shipping to Core Directly

The pipeline assumes a handoff between operators and engineers. But we're already experimenting with operators shipping directly to the core codebase: the marketing team (MDS, Kanellis) submitting small PRs, Rohan shipping an entire feature end-to-end. Within EPD we're also exploring options to accelerate AI agents working within our codebase like preview environments and automated review safety nets. The goal is to get operators shipping full-stack features independently, with minimal engineering lift.
