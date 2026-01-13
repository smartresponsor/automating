Security

- Signature: HMAC-SHA256, constant-time compare in worker.
- Replay guard: timestamp window (AUTOMATE_TIME_SKEW_SEC).
- Allowlist: AUTOMATE_ALLOWED_TASK controls permitted tasks.
- Secrets: store as Cloudflare worker secrets / environment variables and GitHub Actions secrets.
- Audit: rely on GitHub Actions run logs; optional extra logging can be enabled via AUTOMATE_DEBUG.
