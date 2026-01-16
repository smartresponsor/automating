A) Local worker dev

cd .automation/automator/agent-trigger/worker
# copy .dev.vars.example to .dev.vars and fill secrets
wrangler dev

B) Signed dispatch (PowerShell)

pwsh ./.automation/tool/automate-call.ps1 -Url "https://<worker>/dispatch" -Task health -Kid K1

C) Client sync (direct push)

This is executed by GitHub Actions via .github/workflows/automate-kit-sync.yml.
