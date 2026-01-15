Consumer sync

Workflow:
- .github/workflows/automate-kit-sync.yml

Manual:
- ./Domain/tool/automate-kit-sync.ps1 -SourceOwner <owner> -SourceRepo <repo> -ReleaseTag latest -AssetName automate-kit.zip

Apply targets:
- .automation/**
- .github/workflows/automate-*.yml
- .github/prompts/automate-*.md
- Domain/tool/automate-*.ps1 (bootstrap wrappers)
- docs/automate/**
