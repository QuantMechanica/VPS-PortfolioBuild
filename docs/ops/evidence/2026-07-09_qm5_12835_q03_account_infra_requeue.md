# QM5_12835 Q03 Infra Requeue - 2026-07-09

## Scope

- EA: `QM5_12835`
- EA directory: `framework/EAs/QM5_12835_wti-usdchf-brk`
- Instrument sleeve: XTI/USDCHF D1 basket
- Work item: `59d05469-0a18-4430-a961-a9f2c7bd9709`
- Parent task: `1a1b1f76-4544-411a-bba1-6b30787f9b79`
- Phase: `Q03`

## Diagnosis

`QM5_12835` had already passed Q02, but the Q03 work item was sealed as `INFRA_FAIL`.
The failed Q03 summary and work-item log showed report-missing/incomplete-run failures with the tester log line:

`Tester tester not started because the account is not specified`

This is terminal/account infrastructure, not an EA package, ONINIT, or history defect.

## Validation

- `build_check`: PASS
- Failures: 0
- Warnings: 0
- Report: `D:\QM\reports\framework\21\build_check_20260709_012721.json`
- Compiled artifact present: `framework/EAs/QM5_12835_wti-usdchf-brk/QM5_12835_wti-usdchf-brk.ex5`

## Action

Requeued the existing Q03 work item rather than creating a duplicate:

- `work_items.status`: `done` -> `pending`
- `work_items.verdict`: `INFRA_FAIL` -> `NULL`
- `work_items.attempt_count`: `2` -> `0`
- `tasks.status`: `done` -> `pending`
- Requeue reason: `q03_terminal_account_not_specified_infra`
- Updated at: `2026-07-09T01:28:45+00:00`

The old failed report root was archived before requeue:

`D:\QM\reports\work_items\59d05469-0a18-4430-a961-a9f2c7bd9709.requeued_20260709T0128450000`

SQLite backup before mutation:

`D:\QM\strategy_farm\state\backups\farm_state_before_qm5_12835_q03_account_requeue_20260709T012845Z.sqlite`

No backtest was launched by this unit of work.
