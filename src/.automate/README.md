Automater (AI agent automation kit)

Component scope (lock):
- domain_name: Automater
- declared_responsibility: Secure HTTP trigger that dispatches GitHub Actions workflow_dispatch tasks; plus a small task-runner script for common repo checks (health/scan/validate/doctor/plan/codex/pr).
- target_usage:
  - embed as a patch into SmartResponsor component repos (Domain/Tool + Domain/Ai + workflow file)
  - call /dispatch from PowerShell (or any client) using HMAC signature + timestamp
  - GitHub Actions executes Domain/Tool/automater-task.ps1 with inputs.task and optional metadata (kind/message/note)
- explicit_exclusions:
  - not a Symfony domain component; canon “mirror interfaces per layer” does NOT apply here
  - no long-running workflow engine, no queue, no scheduler
  - no privileged GitHub App management; uses standard GitHub workflow_dispatch
  - no storage of secrets or audit logs outside the worker/platform defaults

Key prefixes:
- env vars: AUTOMATER_*
- HTTP headers: X-AUTOMATER-*
- filenames: automater-*

What is included:
- Domain/Ai/agent-trigger/worker (Cloudflare Worker): /health, /dispatch
- Domain/Tool/automater-call.ps1: signs and sends /dispatch
- Domain/Tool/automater-secret-set.ps1: helper to set AUTOMATER_TRIGGER_SECRET_K*
- Domain/Tool/automater-worker-init.ps1: auto-fill wrangler.toml from git remote
- Domain/Tool/automater-task.ps1: GitHub Actions task runner (scan/health/doctor/validate/plan/codex/pr)
- .github/workflows/automater-dispatch.yml: workflow_dispatch entrypoint

API summary:
- GET /health
- POST /dispatch
  - headers:
    - X-AUTOMATER-Kid: K1 (or K2, K3, ...)
    - X-AUTOMATER-Timestamp: unix seconds
    - X-AUTOMATER-Signature: hex(HMAC_SHA256(secret, "<ts>.<sha256hex(rawBody)>"))
  - body (JSON):
    {"task":"health","ref":"master","inputs":{"kind":"fix","message":"...","note":"..."}}

K1 / K2 / K3 mechanism (recommended):
- Use multiple keys for rotation and blast-radius control.
- Worker selects secret by X-AUTOMATER-Kid -> env var AUTOMATER_TRIGGER_SECRET_<Kid>.
- Example: set AUTOMATER_TRIGGER_SECRET_K1 now; later add K2 and switch callers to K2; then remove K1.

Quick start (PowerShell client):
1) Set secret (local session/user):
   ./Domain/Tool/automater-secret-set.ps1 -Kid K1 -Secret "<random>" -Scope User

2) Deploy worker (Cloudflare):
   cd Domain/Ai/agent-trigger/worker
   # ensure wrangler is available
   wrangler deploy

3) Call:
   ./Domain/Tool/automater-call.ps1 -Url "https://<your-worker>.workers.dev/dispatch" -Task health -Kid K1

Docs:
- docs/component-scope.md
- docs/api.md
- docs/usage.md
- docs/demo.md
- docs/security.md

CI:
- .github/workflows/automater-ci.yml runs worker unit tests (node --test).
