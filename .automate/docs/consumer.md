Consumer sync

Workflow:
- .github/workflows/automate-kit-sync.yml

Manual:
- ./Domain/Tool/automate-kit-sync.ps1 -SourceOwner <owner> -SourceRepo <repo> -ReleaseTag latest -AssetName automate-kit.zip

Apply targets:
- .automate/**
- .github/workflows/automate-*.yml
- .github/prompts/automate-*.md
- Domain/Tool/automate-*.ps1 (bootstrap wrappers)
- docs/automate/**
