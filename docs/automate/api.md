API (Cloudflare Worker)

Endpoints:
- GET /health
  returns JSON { ok: true, service, ts, version? }

- POST /dispatch
  Body JSON:
    { "task": "<task>", "ref": "master", "inputs": { ... } }

Headers (preferred):
- X-AUTOMATE-Kid: K1 | K2 | K3 ...
- X-AUTOMATE-Timestamp: unix seconds
- X-AUTOMATE-Signature: hmac_sha256_hex( secret, "<timestamp>.<sha256(body)>" )

Legacy accepted (transition):
- X-AUTOMATER-* and X-SR-* equivalents.

Env (preferred):
- AUTOMATE_TRIGGER_SECRET_K1 / K2 / ...
- AUTOMATE_ALLOWED_TASK
- AUTOMATE_TIME_SKEW_SEC
- AUTOMATE_DEBUG
- AUTOMATE_DEV_MODE
