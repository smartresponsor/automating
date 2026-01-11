API contract (stable)

Endpoints:
- GET /health
  - response: { ok: true, service: "<repo>-automater-trigger" }

- POST /dispatch
  Required headers:
  - X-AUTOMATER-Kid: K1 | K2 | ...
  - X-AUTOMATER-Timestamp: unix seconds (UTC)
  - X-AUTOMATER-Signature: lowercase hex

  Signing:
  - rawBody = exact request body string (JSON, no pretty-print requirement)
  - bodyHash = sha256hex(rawBody)
  - signed = "<ts>.<bodyHash>"
  - signature = hmac_sha256_hex(secret, signed)

  Body:
  - task: string (required)
  - ref: string (optional; default GH_REF)
  - inputs: object (optional)

  Success:
  - { ok: true, verified: true, dispatched: true, repo, workflow, ref, task }

  Errors:
  - 401 BadTimestamp / TimestampSkew / BadKid
  - 403 BadSignature
  - 400 BadJson / BadTask
  - 500 Misconfig
