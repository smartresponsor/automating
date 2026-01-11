Scope (фиксируем ответственность)

Domain name: AutomateKit
Repository role: source-of-truth for industrial automation patch used by SmartResponsor ecosystem.

Declared responsibility:
- Cloudflare Worker endpoint /dispatch + /health that verifies HMAC signature and dispatches GitHub workflow_dispatch.
- PowerShell client tooling for signing requests, setting secrets, initializing worker, and running workflow tasks.
- GitHub Actions workflows for dispatch, packaging kit as release asset, and consumer sync.

Explicit exclusions:
- Business/domain logic of any SmartResponsor component.
- Any non-GitHub CI/CD orchestrator.
- Storing secrets outside GitHub/Cloudflare standard secret stores.
- Any agent “thinking” logic; only dispatch + plumbing.

Target usage:
- Developers/maintainers of SmartResponsor components who want secure “agent trigger” and repeatable automation commands.
