Demo / Discovery

Local (Windows):
1) Set secret:
   ./Domain/Tool/automate-secret-set.ps1 -Kid K1 -Secret "<secret>" -Scope User -SetLegacy

2) Call health:
   ./Domain/Tool/automate-call.ps1 -Url "<worker>/dispatch" -Task health -Kid K1

CI:
- Use workflow ".github/workflows/automate-dispatch.yml" via workflow_dispatch.
