Demo (deterministic)

Goal: prove signature verification + task allowlist without GitHub token.

1) Set worker vars:
- AUTOMATER_DEV_MODE="1"
- GH_TOKEN is NOT set

2) Set secret:
- AUTOMATER_TRIGGER_SECRET_K1 set in worker secrets

3) Call from PowerShell:
./Domain/Tool/automater-call.ps1 -Url "https://<worker>/dispatch" -Task health -Kid K1

Expected:
- ok=true
- verified=true
- dispatched=false
- reason mentions AUTOMATER_DEV_MODE=1
