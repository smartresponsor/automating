Automating

This repository hosts AutomateKit (industrial automation patch) for SmartResponsor ecosystem.

Single source of truth:

- .automating/ # everything for this responsibility (tools, worker, docs, templates, payload)

Execution-required copies:

- .github/workflows/*        # GitHub mandates location; generated from .automating/payload/.github/workflows
- .github/prompts/*          # optional; generated from .automating/payload/.github/prompts

Preferred prefixes:

- Env: AUTOMATE_*
- HTTP: X-AUTOMATE-*
- Code identifiers: Automator*

Migration helpers:

- .automating/tool/automate-clean.ps1 # removes legacy folders (Domain/Tool, tool/, docs/automate) after migration

Compatibility:

- AUTOMATER_* and SR_* are still accepted temporarily in worker/client for migration.
