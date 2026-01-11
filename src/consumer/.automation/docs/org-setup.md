org setup (team plan, private repos)

required (org level preferred)
- var: AUTOMATER_APP_ID
- secret: AUTOMATER_APP_PRIVATE_KEY
- secret: AUTOMATE_SOURCE_TOKEN   (only if source repo is private; otherwise optional)

optional
- var: AUTOMATER_PUSH_TIMER=PT6H
- var: AUTOMATER_BASE_BRANCH=master

ruleset (org -> rulesets)
- target: repositories with topic 'automate-client' (optional) or selected repos
- branch: master
- block direct pushes for humans (require PR / restrict updates)
- bypass: GitHub App 'Automater' (Always allow)

install app
- install GitHub App 'Automater' into org
- grant access to the client repos (only select repositories)

first run
- Actions -> automate-pack-sync -> Run workflow
expected
- .automate/lock/<packId>.json created
- commit pushed to master by automater app token
