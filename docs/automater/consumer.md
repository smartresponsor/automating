Automater kit consumer

What it does:
- Polls the source repo latest release (or reacts to repository_dispatch).
- Downloads release assets: automater-kit.zip and automater-kit.sha256.
- Verifies sha256.
- Copies payload into this repository (overwriting same-path files, with backup).
- Creates a branch automater-kit/<tag> and opens a PR.

Opt-in knobs (repo variables):
- AUTOMATER_KIT_OWNER: source owner (e.g. taa0662621456)
- AUTOMATER_KIT_REPO: source repo (e.g. Automating)
- AUTOMATER_BASE_BRANCH: base branch in this repo (default: master)
- AUTOMATER_KIT_BRANCH_PREFIX: default: automater-kit
- AUTOMATER_KIT_LOCK_PATH: default: .automater/automater-kit.lock.json

Secrets:
- AUTOMATER_SOURCE_TOKEN (optional): if source repo is private or rate-limited.
  Needs read access to source releases.
