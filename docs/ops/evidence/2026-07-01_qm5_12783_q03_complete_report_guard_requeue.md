# QM5_12783 Q03 Complete-Report Guard Requeue

Date: 2026-07-01
Branch: `agents/board-advisor`

## Scope

- Mission: grow/advance the FX market-neutral cointegration basket funnel.
- Target advanced: `QM5_12783_edgelab-audusd-audjpy-cointegration`.
- Logical basket: `QM5_12783_AUDUSD_AUDJPY_COINTEGRATION_D1`.
- Host: `AUDUSD.DWX`, `D1`.
- Backtest risk mode: RISK_FIXED via the existing basket backtest setfile.

No `T_Live` files were touched, AutoTrading was not changed, and no portfolio
gate files were edited.

## Funnel Check

The strict 66-pair FX cointegration scan in
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` remains exhausted for
new non-duplicate strict survivors:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, Q04 PASS, later Q05 timeout
  CPU-ceiling shape documented separately.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, later Q04 FAIL.

Per mission fallback, this pass advanced an existing FX basket instead of
minting a duplicate card.

## Diagnosis

`QM5_12783` Q03 work item
`ab3c2b44-f749-407b-8a56-b38c0d368fe7` was previously requeued after the basket
history-claim guard repair, then failed again as `NO_HISTORY;INCOMPLETE_RUNS`.

The generated `tester.ini` was correctly scoped to:

- Expert: `QM\QM5_12783_edgelab-audusd-audjpy-cointegration`
- Symbol: `AUDUSD.DWX`
- Period: `D1`
- Window: `2024.01.01` to `2024.12.31`

The exported HTML report was a blank/incomplete MT5 report (`M0`/1970 shape,
empty Expert/Symbol, zero bars). `run_smoke.ps1` treated file existence as
report materialization before requiring complete metrics, so the blank report
could be classified downstream as `NO_HISTORY` instead of an infra report
export miss.

## Repair

Changed `framework/scripts/run_smoke.ps1`:

- `Wait-ForReportExport` now accepts `-RequireCompleteMetrics`.
- The main MT5 report wait path uses that switch.
- The legacy relative report fallback also rejects reports that lack complete
  Expert/Symbol/Period/Bars metrics.

Added `framework/scripts/tests/Test-RunSmokeWaitForCompleteReport.ps1` to assert
that incomplete M0/1970 reports are rejected while valid zero-trade reports are
still accepted.

Adjusted `framework/scripts/tests/Test-RunSmokeWaitsForChildTerminal.ps1` so the
test double matches the current `Start-TesterRun` polling contract.

## Queue Mutation

SQLite backup before mutation:

`D:\QM\strategy_farm\state\backups\farm_state_before_qm5_12783_q03_complete_report_guard_requeue_20260701T055736Z.sqlite`

Archived stale evidence root:

`D:\QM\reports\work_items\ab3c2b44-f749-407b-8a56-b38c0d368fe7.requeued_20260701T0557380000`

Reopened the existing Q03 row and parent task in place:

| Field | Value |
|---|---|
| Work item | `ab3c2b44-f749-407b-8a56-b38c0d368fe7` |
| Parent task | `c7afca44-6c60-4d56-acd6-8e92117e3417` |
| Work item before | `done` / `INFRA_FAIL` |
| Work item after | `pending` / `NULL` |
| Parent before | `done` |
| Parent after | `pending` |
| Duplicate pending/active Q03 rows | `0` before mutation, `1` after mutation (the target row only) |
| Requeue reason | `run_smoke_complete_report_guard_patch` |

Verification:

```text
python -m tools.strategy_farm.farmctl work-items --ea QM5_12783
Q02 done PASS; Q03 pending; Q04 done INFRA_FAIL.
```

No manual MT5 backtest was launched. The paced terminal workers own the Q03 run.

## Validation

```text
powershell -ExecutionPolicy Bypass -File framework\scripts\tests\Test-RunSmokeWaitForCompleteReport.ps1
powershell -ExecutionPolicy Bypass -File framework\scripts\tests\Test-RunSmokeWaitsForChildTerminal.ps1
powershell -ExecutionPolicy Bypass -File framework\scripts\tests\Test-RunSmokeRealTicksReportEvidence.ps1
powershell -ExecutionPolicy Bypass -File framework\scripts\tests\Test-RunSmokeNoHistoryScope.ps1
python -m pytest tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py -q
```

Result: all PASS (`24 passed` for the pytest suite).
