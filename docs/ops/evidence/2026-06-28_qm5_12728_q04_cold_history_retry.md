# QM5_12728 Q04 Cold-History Retry - 2026-06-28

Scope: branch `agents/board-advisor`; no `T_Live`, no AutoTrading, no
portfolio-gate or T_Live manifest edits.

## Decision

The strict 66-pair FX cointegration survivors, `QM5_12532` and `QM5_12533`,
already have logical-basket Q02 PASS evidence. The next EdgeLab baskets are
already built, so this pass advanced an existing forex basket through the
pipeline rather than creating a duplicate build.

Chosen basket: `QM5_12728` NZDUSD/GBPJPY. It had Q02 PASS evidence and a
completed Q04 infra failure with no pending or active Q04 duplicate.

## Evidence

| Field | Value |
|---|---|
| Source Q02 PASS | `14a6ae04-aad9-4561-bb0d-d7e350a83925` |
| Q02 evidence | `D:/QM/reports/work_items/14a6ae04-aad9-4561-bb0d-d7e350a83925/QM5_12728/20260628_003443/summary.json` |
| Prior Q04 row | `6a1a390b-7380-407e-a75d-6c64cec9a63f` |
| Prior Q04 evidence | `D:/QM/reports/work_items/6a1a390b-7380-407e-a75d-6c64cec9a63f/QM5_12728/Q04/QM5_12728_NZDUSD_GBPJPY_COINTEGRATION_D1/aggregate.json` |
| Prior Q04 verdict | `INFRA_FAIL` |
| Prior Q04 reason | F1/F2/F3 invalid summaries with `NO_HISTORY`, `INCOMPLETE_RUNS`, `BARS_ZERO`, `HISTORY_CONTEXT_INVALID`; F1/F2 also included `EMPTY_SYMBOL` |

Build guard before mutation:

```powershell
powershell -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel QM5_12728_edgelab-nzdusd-gbpjpy-cointegration -SkipCompile
```

Result: `PASS`, 0 failures, 16 existing framework advisory warnings.
Report: `D:/QM/reports/framework/21/build_check_20260628_041827.json`.

## Queue Action

SQLite backup before mutation:

`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_12728_q04_retry_20260628_041911Z.sqlite`

Inserted one non-duplicate Q04 work item:

| Field | Value |
|---|---|
| Work item | `b661cbc1-414a-4655-91c1-262a017c7f77` |
| EA | `QM5_12728` |
| Symbol | `QM5_12728_NZDUSD_GBPJPY_COINTEGRATION_D1` |
| Setfile | `C:/QM/repo/framework/EAs/QM5_12728_edgelab-nzdusd-gbpjpy-cointegration/sets/QM5_12728_edgelab-nzdusd-gbpjpy-cointegration_QM5_12728_NZDUSD_GBPJPY_COINTEGRATION_D1_D1_backtest.set` |
| Host symbol/timeframe | `NZDUSD.DWX`, `D1` |
| Payload scope | `portfolio_scope=basket` |
| Payload clamp | `q04_latest_full_year=2024` |
| Risk | `RISK_FIXED=1000`, `tester_currency=USD`, `tester_deposit=100000` |
| Supersedes | `6a1a390b-7380-407e-a75d-6c64cec9a63f` |
| Source Q02 PASS | `14a6ae04-aad9-4561-bb0d-d7e350a83925` |

Duplicate guard after insert: exactly one pending/active Q04 row for
`QM5_12728` / `QM5_12728_NZDUSD_GBPJPY_COINTEGRATION_D1`, the new retry above.

Verification after insert:

| Field | Value |
|---|---|
| Status | `active` |
| Claimed by | `T6` |
| Updated at | `2026-06-28T04:20:19+00:00` |

No manual MT5 backtest was launched. Execution is left to the paced worker fleet.
