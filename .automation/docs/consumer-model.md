A) Consumer model (direct push to master)

This kit supports two delivery channels:
1) Pull (schedule): each client checks for updates and applies them.
2) Signal (repository_dispatch): source repo notifies clients on every release.

Target behavior for clients:
- apply the latest kit release into the same repository
- commit changes directly to master (no PR)
- throttle schedule runs using AUTOMATE_PUSH_TIMER, but repository_dispatch bypasses throttling

B) Required tokens and storage

1) Client side (pull token)
- Name: AUTOMATE_SOURCE_TOKEN
- Scope: read-only access to the source repo releases (and assets)
- Storage: GitHub Organization Secret recommended, scoped to selected repos

2) Source side (dispatch token)
Preferred: GitHub App (installation token) with permission to trigger repository_dispatch in client repos.
Fallback: AUTOMATE_DISPATCH_TOKEN (PAT / fine-grained token) stored in the source repo secrets.

C) Enable on client repo

1) Add workflow:
- .github/workflows/automate-kit-sync.yml

2) Configure repo variables (or org-level vars):
- AUTOMATE_KIT_OWNER
- AUTOMATE_KIT_REPO
- AUTOMATE_PUSH_TIMER (example: PT6H)

3) Ensure GitHub Actions can push to master:
- branch protection must allow github-actions[bot] (or the App) to push.

D) Source allowlist

Source repo stores allowlist in:
- .automating/client/allowlist.json

It can also discover opt-in clients by topic:
- automate-client
