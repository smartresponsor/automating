Component scope (lock)

domain_name: Automater
responsibility: Secure dispatch of GitHub Actions via Cloudflare Worker + a small PowerShell task runner.
target_repos: SmartResponsor component repositories (embedded as a patch).
non_goals:
- not a workflow engine
- not a CI replacement
- not a secrets vault
compatibility:
- Worker: Cloudflare Workers runtime (WebCrypto)
- Client: PowerShell 7+ on Windows
