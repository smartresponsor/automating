consumer model (multi-pack)

what it does
- this repository runs a single consumer engine from .automate/tool/automate-pack-sync.ps1
- the engine reads .automate/packs.json and applies one or more packs
- each pack is downloaded from a source GitHub Release as an asset zip + sha256 file
- apply mode is copy-overwrite into targetRoot with backups in .automate/backup/<packId>/<tag>/...
- lock is stored in .automate/lock/<packId>.json
- commits are pushed directly to the base branch (default master)

required secrets
- AUTOMATE_SOURCE_TOKEN (org secret recommended): read-only token to download release assets from the source repo (if source is private)

required vars (repo or org vars)
- AUTOMATE_PUSH_TIMER: ISO8601 duration (example PT6H). throttle for scheduled runs.
- AUTOMATE_BASE_BRANCH: default master. can override per repo.

dispatch (optional)
- repository_dispatch event types supported:
  - automate-pack-release with client_payload { packId, tag }
  - automate-kit-release with client_payload { tag }
- dispatch with tag bypasses throttle for that pack.
