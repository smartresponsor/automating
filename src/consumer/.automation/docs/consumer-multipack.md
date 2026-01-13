consumer model (multi-pack)

what it does
- engine reads .automating/packs.json and applies packs from source releases
- each pack is downloaded as a release asset zip + sha256
- sha256 is verified before apply
- apply mode: copy-overwrite into targetRoot
- backups (only overwritten files): .automating/backup/<packId>/<tag>/...
- lock: .automating/lock/<packId>.json
- throttle: ISO8601 duration via AUTOMATER_PUSH_TIMER (fallback AUTOMATE_PUSH_TIMER)

required tools on runner
- git
- gh (GitHub CLI)
- pwsh

dispatch (optional)
- repository_dispatch types supported:
  - automate-pack-release, automater-pack-release
  - automate-kit-release, automater-kit-release
payload
  { packId, tag }
