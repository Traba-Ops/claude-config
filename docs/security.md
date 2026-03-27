# Security Guardrails

Security for Prometheus operates on two planes: **Claude skill guidance** (soft, advisory, can be ignored) and **infrastructure enforcement** (hard, deterministic, cannot be bypassed). The principle: hard guardrails for catastrophic risks, soft guidance for everything else.

## Threat Model

What are we actually protecting against? Non-engineers building apps with AI assistance, where the AI happily generates insecure code and the user can't tell the difference.

### Catastrophic failure modes (MUST prevent)

| Failure Mode | Example | Likelihood | Impact |
|-------------|---------|------------|--------|
| **Secret leakage** | API key committed to GitHub, auth token in a tweet | Very high — 45% of AI-generated code introduces vulnerabilities ([Veracode 2025](https://www.veracode.com/resources/gen-ai-code-security-report)) | Immediate financial loss, data breach |
| **Data exposure** | Admin dashboard with no auth, Supabase table with no RLS | Very high — 83% of exposed Supabase DBs have RLS misconfig | PII leak, regulatory risk |
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
| SSO enforcement for internal tools | Cloudflare Zero Trust OTP + email domain restriction is sufficient. Add SAML when onboarding/offboarding friction becomes a risk. |
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
| **Railway env var isolation** | Each Railway project has its own environment variables. Operators can view/edit variables for their own projects only. |
| **Environment isolation** | Supabase projects for citizen dev apps are separate from production Supabase. Separate Railway projects. |
| **Network isolation** | Citizen-developed apps cannot directly access production data stores. Use the Traba MCP data layer (BigQuery RBAC). |

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
supabase.json
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

---

## Soft Guardrails (Claude Skill Guidance)

These are enforced by Claude skills — advisory, not deterministic. They guide the AI to generate secure code by default.

### Supabase RLS

The Claude skill must instruct:
- Enable RLS on every table at creation time
- Generate explicit RLS policies (not just `enable`)
- Default policy: authenticated users can read their own rows, only row owner can write
- For admin tables: restrict to specific user roles

This is the #1 security risk for Supabase-based apps. 83% of exposed databases involve RLS misconfiguration ([VibeAppScanner](https://vibeappscanner.com/supabase-row-level-security)).

### CORS configuration

The skill should instruct Claude to never set `Access-Control-Allow-Origin: *`. Instead:
- Specify the exact allowed origins
- For internal tools behind Cloudflare Access, CORS is largely irrelevant (requests come from the same domain)

### Input validation

Instruct Claude to validate at system boundaries:
- Sanitize user input
- Use parameterized queries (Supabase client does this by default)
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

1. **Immediately rotate** the compromised credential in Railway project variables (and at the source provider)
2. Review the provider's usage dashboard for unauthorized access during exposure window
3. If an API key: check the provider's usage dashboard for anomalous activity
4. Add the secret pattern to GitHub push protection custom patterns if it wasn't caught

### Exposed Supabase database

1. Enable RLS immediately on exposed tables
2. Review Supabase auth logs for unauthorized access
3. Rotate the `anon` and `service_role` keys
4. Check if any data was exfiltrated

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
