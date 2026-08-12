# QM5_11167 Q03 infrastructure diagnosis: DWX history sharing violation

Date: 2026-07-20  
Branch: `agents/board-advisor`  
Scope: read-only diagnosis; no T_Live, AutoTrading, portfolio gate, or deploy manifest changes

## Candidate selection

The two remaining `build_ea` backlog rows were not valid build candidates:

- `QM5_1457_as-predict-bonds` requires Treasury yield, IEF, BIL, and DBC inputs that are absent from the approved DWX symbol matrix. Its farm row was already marked `non_dwx_rates_inputs_required_by_card`.
- `QM5_1459_as-lumber-gold` requires lumber and IEF inputs. Its card's detailed R3 evaluation is `UNKNOWN`, despite contradictory `r3_data_available: PASS` frontmatter.

The recovery lane was therefore selected. `QM5_11167_weiss-ichi2-ma` is a low-frequency forex EA stuck at Q03 on `EURUSD.DWX` with repeated `INFRA_FAIL` results.

## Farm evidence

Latest inspected work item:

- work item: `89368555-095f-4561-8b2e-829d64351dfd`
- phase: `Q03`
- symbol: `EURUSD.DWX`
- setfile: `QM5_11167_weiss-ichi2-ma_EURUSD.DWX_D1_backtest_ablation_01.set`
- terminal: `T6`
- attempts: 2
- final failure: `summary_missing_retries_exhausted`
- runner exit code: `0`

The runner log confirms that the current EX5 deployed successfully, the setfile resolved, and the tester INI was written. The terminal then exited without producing a report or structured logger file. The EX5 exists at 323,360 bytes and the EA's latest repository commit is `f1b1abd677694ebb1bb9f455af52eda8759efafd` (2026-07-14), excluding a missing or obviously stale build artifact as the immediate cause.

## Root cause

The T6 MT5 journal repeatedly records:

```text
History 'EURUSD.DWX' file opening or reading error [32]
Tester last test passed with result "some error after pass finished" in 0:00:00.000
```

Windows error 32 is a sharing violation. This explains the otherwise misleading `summary_missing`: MT5 cannot open the custom-symbol history, aborts before EA initialization/test execution, and therefore emits neither an HTML report nor the QM structured log. This is infrastructure failure, not ONINIT, trade-generation, or strategy logic failure.

The same `summary_missing_retries_exhausted` signature was present on multiple contemporaneous Q02/Q03 work items across T6/T7, so rebuilding QM5_11167 would not address the fault.

## Disposition

No backtest was launched and no row was re-enqueued. At the stop check, five factory terminals (`T2`, `T3`, `T8`, `T9`, `T10`) were actively running pipeline tests, which is the configured backtest CPU ceiling for this paced fleet. Re-enqueueing at the ceiling would add churn without validating the history-lock repair.

Required follow-up after capacity clears:

1. Identify and release the process or scanner holding `D:\QM\mt5\T6\Bases\Custom\history\EURUSD.DWX` (and check T7 equivalently).
2. Verify an exclusive read/open of the affected `.hcc` and cache files while the terminal is stopped.
3. Re-enqueue exactly one QM5_11167 Q03 ablation row and require a generated `summary.json` before expanding recovery.

