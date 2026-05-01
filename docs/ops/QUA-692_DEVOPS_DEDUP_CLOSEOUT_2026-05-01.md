# QUA-692 DevOps Closeout (2026-05-01)

## Scope

Suppress duplicate token-budget alarm issue creation while:

- `cap_is_placeholder=true`
- cap-review remains open (`QUA-542` / `QUA-543`)

Keep daily snapshot JSON and markdown summary output unchanged.

## Shipped Commits

- `3ab0b3ce` - initial dedup guards in token-budget monitor and runtime-health token notice path.
- `f005665f` - acceptance-aligned monthly same-threshold dedup with comment fan-in to existing issue.
- `2d311dce` - infra README documentation update for the dedup behavior.

## Implementation Notes

- `infra/monitoring/Test-TokenCostBudgetHealth.ps1` now:
  - checks open issues before creation,
  - gates placeholder dedup on open cap-review identifiers (`QUA-542`, `QUA-543`),
  - reuses open same-threshold monthly alarm issue,
  - posts a daily update comment to existing alarm issue instead of creating a new issue.
- `infra/scripts/Run-RuntimeHealthScan.ps1` now avoids duplicate `OWNER notice: token budget pressure` open issues in placeholder-cap review mode.

## Verification Evidence

1. Parse validation:
   - `Test-TokenCostBudgetHealth.ps1`: 0 parse errors.
   - `Run-RuntimeHealthScan.ps1`: 0 parse errors.
2. Mock API integration check (`AsOfUtc=2026-05-02T12:00:00Z`):
   - observed `GET /api/companies/testco/issues?limit=200`
   - observed `POST /api/issues/issue-alarm-688/comments`
   - not observed `POST /api/companies/testco/issues`

Result: tomorrow-style rollover updates existing monthly threshold alarm issue via comment; no duplicate alarm issue is created.
