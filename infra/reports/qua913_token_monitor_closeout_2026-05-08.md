# QUA-913 Closeout — qm-token-monitor (2026-05-08)

## Scope delivered

- Deterministic token-burn monitor script:
  - `infra/monitoring/Invoke-QmTokenMonitor.ps1`
- Deterministic monitor contract test + fixtures:
  - `infra/scripts/tests/Test-QmTokenMonitor.ps1`
  - `infra/scripts/tests/fixtures/qm_token_monitor_agents_fixture.json`
  - `infra/scripts/tests/fixtures/qm_token_monitor_previous_state_fixture.json`
- Idempotent scheduler install script:
  - `infra/scripts/Install-QmTokenMonitorTask.ps1`
- Scheduler installer preview contract test:
  - `infra/scripts/tests/Test-QmTokenMonitorTaskInstall.ps1`
- Infra-audit integration:
  - `infra/scripts/Invoke-InfraAudit.ps1` now includes check `qm_token_monitor`
- Infra-audit wiring regression test:
  - `infra/scripts/tests/Test-InfraAuditQmTokenMonitorWiring.ps1`
- Infra docs updated:
  - `infra/README.md`

## Output contract implemented

`Invoke-QmTokenMonitor.ps1` emits deterministic JSON with:

- `spent_cents`
- `daily_delta`
- `org_cap_pct_used`
- `top3_agents`
- `anomalies[]`

Additional fields included for operations:

- `burn_trend.daily_delta_24h_cents`
- `burn_trend.daily_delta_7d_avg_cents`
- `days_to_exhaust`

Markdown summary output is also written for CoS consumption.

## Detection coverage

- Org-cap proximity thresholds from `framework/registry/token_budget.json` company section
- Burn trend 24h + rolling 7d average (state-backed)
- Top consumers (top 3 by `spentMonthlyCents`)
- Abnormal loop signal: `HEARTBEAT_STORM_SUSPECTED`

## Scheduler behavior

`Install-QmTokenMonitorTask.ps1`:

- Registers `QM_TokenBurnWatch_60min` as `SYSTEM`
- Re-run safe (`Register-ScheduledTask -Force`)
- Supports `-PreviewOnly`
- Wires explicit action args for API URL, company id, and output/state paths

## Verification evidence

Executed and passed:

1. `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\tests\Test-QmTokenMonitor.ps1`
2. `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\tests\Test-QmTokenMonitorTaskInstall.ps1`
3. `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\tests\Test-InfraAuditQmTokenMonitorWiring.ps1`

## Commit chain

1. `da00303f` — add deterministic qm token monitor + contract fixtures/tests
2. `824ac170` — add idempotent scheduler installer + preview wiring test + README task command
3. `fee236fa` — wire qm token monitor into infra audit + wiring regression test

## Operational command

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Install-QmTokenMonitorTask.ps1 -EveryMinutes 60
```

