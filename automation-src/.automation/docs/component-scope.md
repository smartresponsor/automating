domain_name: Automate Kit
declared_responsibility:
- Secure dispatch of GitHub Actions workflows via Cloudflare Worker.
- Client tooling to sign requests and run tasks in GitHub Actions.
- Consumer delivery model: source release -> clients sync -> direct push to master.

explicit_exclusions:
- No business-domain logic.
- No long-running workflow engine.
- No vendor-specific CI/CD beyond GitHub Actions + Cloudflare Worker.

target_usage:
- SmartResponsor ecosystem repositories that opt-in to automation patch syncing.

status:
- maturity: growing
- delivery: patch-kit
