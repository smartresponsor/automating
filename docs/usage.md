Usage (operator-focused)

Worker configuration (wrangler.toml [vars]):
- GH_OWNER, GH_REPO, GH_WORKFLOW, GH_REF
- AUTOMATER_TIME_SKEW_SEC (default 300)
- AUTOMATER_ALLOWED_TASK (csv allowlist)
- AUTOMATER_DEV_MODE: "1" to allow signature verification without GITHUB_TOKEN (local/dev only)
- AUTOMATER_DEBUG: "1" to return debug details on BadSignature (never enable in prod)

Secrets:
- GITHUB_TOKEN (GitHub PAT with permission to dispatch workflow)
- AUTOMATER_TRIGGER_SECRET_K1 (and optional K2/K3...)

Rotation:
- Add K2 secret, switch clients to X-AUTOMATER-Kid: K2, then remove K1.

GitHub Action:
- .github/workflows/automater-dispatch.yml exposes workflow_dispatch inputs.task
- Runner calls: Domain/tool/automater-task.ps1

Codex prompt helper:
- Domain/tool/automater-task.ps1 -Task codex
  ensures .github/prompts/automater-repo-portrait-rwe.prompt.md exists
