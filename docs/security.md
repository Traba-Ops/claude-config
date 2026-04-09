# Security Guardrails

Security for Prometheus operates on two planes: **Claude skill guidance** (soft, advisory, can be ignored) and **infrastructure enforcement** (hard, deterministic, cannot be bypassed). The principle: hard guardrails for catastrophic risks, soft guidance for everything else.

## Threat Model

What are we actually protecting against? Non-engineers building apps with AI assistance, where the AI happily generates insecure code and the user can't tell the difference.

### Catastrophic failure modes (MUST prevent)

| Failure Mode | Example | Likelihood | Impact |
|-------------|---------|------------|--------|
| **Secret leakage** | API key committed to GitHub, auth token in a tweet | Very high — 45% of AI-generated code introduces vulnerabilities ([Veracode 2025](https://www.veracode.com/resources/gen-ai-code-security-report)) | Immediate financial loss, data breach |
| **Data exposure** | Admin dashboard with no auth, database with no access controls | Very high | PII leak, regulatory risk |
| **Credential escalation** | Citizen dev gets access to production DB via shared Railway project | Medium | Full production data access |

### Serious failure modes (SHOULD prevent)

| Failure Mode | Example | Likelihood | Impact |
|-------------|---------|------------|--------|
| **Cost overruns** | Exposed endpoint hammered by attacker, runaway API loop | Medium — documented cases of $300+ overnight losses ([HN](https://news.ycombinator.com/item?id=45241001)) | Financial loss |
| **Insecure defaults** | CORS wildcard, no rate limiting, no input validation | High — LLMs default to convenience | Exploitable apps |
| **Duplicate work** | Two teams building the same tool independently | High — Gartner: 66% of AI-generated apps undiscovered by IT ([BetaNews](https://betanews.com/2025/12/17/citizen-developers-dominate-the-rise-of-ai-code-as-the-new-latin-development-predictions-for-2026/)) | Wasted effort, conflicting data |

### Acceptable risks (defer for now)

| Failure Mode | Why It Can Wait |
|-------------|----------------|
| Dependency vulnerabilities in prototypes | Dependabot alerts are sufficient. Full SBOM tracking is overkill for < 20 users. |
| Formal threat modeling per project | An engineer doing PR review catches the same issues faster. Formalize when you have external-facing apps. |
| SSO enforcement for internal tools | In-app Google OAuth with `@traba.work` domain restriction is sufficient. Add SAML when onboarding/offboarding friction becomes a risk. |
| Comprehensive SIEM / security logging | Basic cloud provider logging is sufficient. Invest when you have incident response requirements. |
| Container image scanning | Not relevant until you have multi-service container infrastructure. |
| Compliance automation (SOC 2, ISO 27001) | No customer is asking for it from internal tools. |

---

## Hard Guardrails (Deterministic, Automated)

These cannot be bypassed by the user. They are enforced by infrastructure, not by Claude skills or process documents.

### Layer 1: Pre-commit hooks (client-side, defense in depth)

**Tool:** [gitleaks](https://github.com/gitleaks/gitleaks) as a pre-commit hook.

```yaml
# .pre-commit-config.yaml (included in every Prometheus project)
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.21.2
    hooks:
      - id: gitleaks
```

Detects 160+ secret types. Provides immediate feedback before the commit is created.

**Limitation:** Pre-commit hooks are client-side and can be bypassed with `git commit --no-verify`. This is a speed bump, not a security boundary. That's why Layer 2 exists.

### Layer 2: GitHub push protection (server-side, cannot be bypassed)

This is the real enforcement layer. When a developer pushes, GitHub scans the diff for secret patterns. If a secret is detected, **the push is blocked** before it enters the repository.

**Setup:**
- Enable [GitHub Secret Protection](https://docs.github.com/en/code-security/secret-scanning/introduction/about-push-protection) on the Prometheus GitHub org
- Cost: $19/active committer/month (standalone product as of March 2025)
- Supports custom patterns (up to 500 per org) for Traba-specific credential formats
- Bypass reasons are logged for audit

**Alternative if cost is a concern:** [Gitleaks GitHub Action](https://github.com/gitleaks/gitleaks-action) runs in CI and blocks PRs that contain secrets. Free for personal repos, free license key for org repos.

```yaml
# .github/workflows/gitleaks.yml
name: gitleaks
on: [push, pull_request]
jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          GITLEAKS_LICENSE: ${{ secrets.GITLEAKS_LICENSE }}
```

### Layer 3: CI checks on push

GitHub Actions run on every push to catch issues automatically:

- **Gitleaks** — scans for accidentally committed secrets
- **Build check** — verifies the project compiles/runs

Operators push directly to main on their own repos. The CI checks are the safety net, not branch protection or PR review. This keeps the workflow simple — no branches, no PRs, no overhead.

For projects that eventually need more rigor (high traffic, sensitive data), branch protection and PR review can be added case by case.

### Layer 4: Dependency scanning

- **Dependabot** (free on GitHub): Enable on all repos. Automated PRs for vulnerable dependencies.

### Layer 5: Infrastructure access controls

| Control | Implementation |
|---------|---------------|
| **No production DB access** | Citizen developers never get production connection strings. Read replicas or API gateways only. |
| **Scoped API keys** | Every key issued has narrowest possible permissions and hard rate limits. |
| **Billing alerts** | Cloud billing alerts at 50%, 80%, 100% of budget on all accounts. Non-negotiable. |
| **Railway env var isolation** | Railway has no per-project access control — any team Member can view all env vars. Sensitive values must be sealed (see Layer 7). |
| **Environment isolation** | Railway projects for citizen dev apps are separate from production infrastructure. Separate Railway projects per app. |
| **Network isolation** | Citizen-developed apps cannot directly access production data stores. Use the Traba MCP data layer (BigQuery RBAC). |
| **No new GCP projects** | Never create a new GCP project. Use the existing `traba-ops` project. Contact a GCP admin to provision service accounts, enable APIs, and grant IAM permissions. |

#### GCP: always use `traba-ops`, never create new projects

Creating a new GCP project bypasses org-level billing controls, IAM policies, audit logging, and quota guardrails. It also creates an unmonitored footprint that Traba's security team can't see.

**Rule:** If a feature needs a GCP service (Cloud Storage, Pub/Sub, Cloud Tasks, etc.), open a request to a GCP admin. They will:
- Create or scope a service account inside `traba-ops` with least-privilege IAM roles
- Enable the required APIs on the existing project
- Provide the service account key or Workload Identity binding

Claude should never run `gcloud projects create` or click through the GCP console to create a new project. If a task seems to require a new GCP project, stop and ask an admin instead.

### Layer 6: `.gitignore` template

Every Prometheus project starts with a comprehensive `.gitignore`. The Claude skill includes this as part of project scaffolding:

```gitignore
# Secrets
.env
.env.*
!.env.example
*.pem
*.key
credentials.json
infisical-token

# Data
*.sqlite
*.db
data/

# OS
.DS_Store
Thumbs.db

# Dependencies
node_modules/
__pycache__/
venv/
```

### Layer 7: Secrets classification and sealing

Railway's current plan has no role-based access control — every team Member can view every environment variable on every project. This means any teammate (or a leaked Railway login) can read production API keys, database passwords, and service account credentials in plaintext.

**Primary control: Railway sealed secrets.** Sealing a variable permanently hides its value from the Railway dashboard UI and API while still injecting it at runtime. Once sealed, nobody can read the value back — not in the UI, not via the API, not via the CLI. Seal via the 3-dot menu next to the variable in Railway's dashboard.

For projects that need more rigorous lifecycle management (rotation, audit trail, centralized access control), [Infisical](https://infisical.com/) can be layered on top with the [Railway integration](https://infisical.com/docs/integrations/cloud/railway). This is not required for most Prometheus projects.

#### What to seal

Classify every environment variable by sensitivity. The scoring rubric from the March 2026 Railway security audit uses three dimensions: blast radius, data sensitivity, and scope (highest score wins).

| Score | Classification | Examples | Action |
|-------|---------------|----------|--------|
| **5 — Critical** | Meta-secrets, production DB credentials, keys that bypass access controls | GCP service account JSON, backend signing keys (`NEST_SERVER_PRIVATE_KEY`) | **Must seal.** Rotate quarterly. |
| **4 — High** | API keys with write access or broad permissions, credentials for external services | Anthropic API keys, Stripe secret keys, Firebase API keys, BigQuery credentials | **Must seal.** Rotate semi-annually. |
| **2 — Low** | API keys with limited blast radius, non-critical service config | Narrow-scope read-only keys, webhook URLs with built-in auth | **Seal recommended.** |
| **1 — Minimal** | Non-secret configuration | `PORT`, `NODE_ENV`, `LOG_LEVEL`, `RAILWAY_PUBLIC_DOMAIN`, public URLs, project IDs | **Do not seal.** Plain Railway env vars are fine. |

**Rule of thumb:** if leaking the value would let someone access data, spend money, or impersonate a service, seal it.

#### Sealing gotchas

- **Sealed values cannot be read back.** Before sealing, save the value somewhere else (password manager, Infisical, etc.). You will never retrieve it from Railway again.
- **Verify the app works before sealing.** Deploy first, confirm the service reads the secret correctly, then seal. Sealing is irreversible — if something is misconfigured, you can't unseal to debug.
- **Sealed variables are not copied** to PR environments, duplicated services, or new environments. Plan for this if you use Railway's environment features.
- **Do not seal reference variables** that compose URLs from other variables (e.g., `DATABASE_URL=${{shared.DB_PASSWORD}}`). Seal the atomic secret (`DB_PASSWORD`), keep the template unsealed.
- **Sealing is UI-only.** There is no CLI or API command to seal. It must be done manually in the Railway dashboard.

#### Dead projects

Revoke secrets on stopped or failed Railway projects immediately. A dead service with live credentials is an unmonitored attack surface. If the project is truly dead, delete it from Railway.

---

## Soft Guardrails (Claude Skill Guidance)

These are enforced by Claude skills — advisory, not deterministic. They guide the AI to generate secure code by default.

### Database access control

The Railway Postgres template enables TCP proxy by default, which exposes the database to the public internet. **Disable TCP proxy** on every Prometheus database (Service → Settings → Networking → remove TCP proxy). With TCP proxy disabled, the database is only reachable over Railway's private network within the project.

Once TCP proxy is disabled, `DATABASE_URL` does not need to be sealed — the password is never exposed outside Railway's private network. If TCP proxy is left enabled for any reason (e.g., external tooling needs direct DB access), `DATABASE_URL` must be sealed (Score 5).

For apps that need fine-grained access control beyond network isolation, use Prisma middleware or application-level authorization checks.

### CORS configuration

The skill should instruct Claude to never set `Access-Control-Allow-Origin: *`. Instead:
- Specify the exact allowed origins
- For internal tools using in-app Google OAuth, CORS should match the app's domain (requests come from the same origin)

### Input validation

Instruct Claude to validate at system boundaries:
- Sanitize user input
- Use parameterized queries (Prisma does this by default)
- Validate file uploads (type, size)

### Error handling

Instruct Claude to never expose internal details in error responses:
- No stack traces in production
- No raw database errors
- No auth tokens or API keys in logs

---

## Incident Response (Lightweight)

For this scale (< 20 users, internal tools), a full incident response plan is overkill. But two scenarios need pre-planned responses:

### Leaked secret detected

1. **Immediately rotate** the compromised credential at the source provider
2. Update the new value in Railway project variables (and Infisical, if the project uses it)
3. **Seal the new variable** if it wasn't already sealed — the leak likely happened because it was visible in plaintext
4. Review the provider's usage dashboard for unauthorized access during the exposure window
5. Add the secret pattern to GitHub push protection custom patterns if it wasn't caught

### Exposed database

1. Immediately rotate the `DATABASE_URL` credential (change the Postgres password)
2. Check Railway logs and Postgres logs for unauthorized access
3. Update the sealed Railway env var with the new connection string
4. Verify the database is only accessible over Railway's private network (no public TCP proxy enabled)

---

## Design Philosophy

Two ideas we borrow:

- **"The walls matter more than the model"** ([Stripe](https://stripe.dev/blog/minions-stripes-one-shot-end-to-end-coding-agents-part-2)): AI reliability scales with the quality of its constraints. Claude generates the code, but deterministic checks (gitleaks, CI, infra access controls) validate it.
- **Make the secure path the easiest path** ([Shopify](https://logz.io/blog/scaling-platform-engineering-shopify-blueprint/)): The Claude skills bundle means the easiest way to build is the secure way.

---

## References

- [OWASP Citizen Development Top 10 Security Risks](https://owasp.org/www-project-citizen-development-top10-security-risks/)
- [Veracode GenAI Code Security Report 2025](https://www.veracode.com/resources/gen-ai-code-security-report)
- [AlterSquare: Audit of 5 vibe-coded startups](https://altersquare.io/vibe-coded-startups-audit-common-codebase-problems/)
- [OWASP Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)
- [HashiCorp 18-point secrets management checklist](https://www.hashicorp.com/en/blog/the-18-point-secrets-management-checklist)
- [GitHub push protection docs](https://docs.github.com/en/code-security/secret-scanning/introduction/about-push-protection)
- [Gitleaks](https://github.com/gitleaks/gitleaks)
- [Gartner: 66% of AI-generated apps undiscovered](https://betanews.com/2025/12/17/citizen-developers-dominate-the-rise-of-ai-code-as-the-new-latin-development-predictions-for-2026/)
