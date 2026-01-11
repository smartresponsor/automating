Security baseline

Controls:
- HMAC signature (SHA-256) + constant-time compare
- replay guard: timestamp window (AUTOMATER_TIME_SKEW_SEC)
- task allowlist: AUTOMATER_ALLOWED_TASK
- optional key rotation: K1/K2/K3 (per-kid secret)

Hard rules:
- never enable AUTOMATER_DEBUG in production
- keep skew window minimal (<= 300s)
- use per-repo secrets; do not share trigger secret across repos

Audit:
- The worker returns minimal JSON errors by default.
- If you need audit trails, attach platform logging at the edge (do not echo secrets).
