A) Worker endpoints

/health
- method: GET
- response: JSON with ok=true and minimal metadata

/dispatch
- method: POST
- body: JSON: { "task": "<name>", "payload": { ... } }
- behavior: validates signature + timestamp, checks allowlist, dispatches a GitHub Actions workflow_dispatch.

B) Headers (preferred)

X-AUTOMATE-Kid: K1|K2|K3
X-AUTOMATE-Ts: unix seconds
X-AUTOMATE-Signature: hex HMAC-SHA256 over "<ts>.<sha256hex(rawBody)>"

C) Env vars (preferred)

AUTOMATE_ALLOWED_TASK
AUTOMATE_TRIGGER_SECRET_K1 (+ K2, K3)
AUTOMATE_TS_SKEW_SEC
AUTOMATE_DEBUG
AUTOMATE_DEV_MODE

GitHub:
GH_OWNER
GH_REPO
GH_WORKFLOW
GH_REF
GH_TOKEN
