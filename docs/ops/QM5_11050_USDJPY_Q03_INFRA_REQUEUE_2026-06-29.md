# QM5_11050 USDJPY Q03 Infra Requeue - 2026-06-29

## Scope

- EA: `QM5_11050_pst-ch15-tfcarry`
- Phase: `Q03`
- Symbol: `USDJPY.DWX`
- Setfile: `framework/EAs/QM5_11050_pst-ch15-tfcarry/sets/QM5_11050_pst-ch15-tfcarry_USDJPY.DWX_D1_backtest_ablation_02.set`
- Source work item: `e1ecbd9b-9299-419e-8aca-2d9297f8ad19`
- New queued work item: `94d2679a-55d9-43c6-8200-47d9fb95f115`

## Diagnosis

The latest Q03 attempt failed as `INFRA_FAIL`, not as a strategy verdict. Evidence at
`D:/QM/reports/work_items/e1ecbd9b-9299-419e-8aca-2d9297f8ad19/QM5_11050/20260629_110735/summary.json`
shows:

- `reason_classes`: `NO_HISTORY`, `INCOMPLETE_RUNS`
- Model: `4`
- `model4_log_marker_detected`: `true`
- `oninit_failure_detected`: `false`
- News calendar status: `OK`
- Three attempted runs, all invalid with `EMPTY_EXPERT`, `EMPTY_SYMBOL`, `M0_1970_PERIOD`, `BARS_ZERO`, and `HISTORY_CONTEXT_INVALID`

The work item log shows `.ex5` deployment succeeded, the setfile resolved, terminal `T3` launched and exited without timeout, and the failure was recorded by the smoke runner as `NO_HISTORY;INCOMPLETE_RUNS`.

## Action

Inserted pending farm DB work item `94d2679a-55d9-43c6-8200-47d9fb95f115` for the same EA, phase, symbol, and setfile after confirming no pending or active duplicate existed.

Payload marker:

- `enqueued_by`: `codex_board_advisor_qm5_11050_usdjpy_q03_infra_retry_20260629`
- `source_work_item`: `e1ecbd9b-9299-419e-8aca-2d9297f8ad19`
- `evidence_provenance`: `real_mt5`

No `.mq5`, `.ex5`, setfile, portfolio gate, T_Live manifest, or AutoTrading state was changed. No local backtest was launched.
