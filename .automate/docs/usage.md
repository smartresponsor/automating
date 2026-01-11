A) Local worker dev

cd .automate/automator/agent-trigger/worker
# copy .dev.vars.example to .dev.vars and fill secrets
wrangler dev

B) Signed dispatch (PowerShell)

pwsh ./.automate/tool/automate-call.ps1 -Url "https://<worker>/dispatch" -Task health -Kid K1

C) Client sync (direct push)

This is executed by GitHub Actions via .github/workflows/automate-kit-sync.yml.
