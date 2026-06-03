# Codex Failed EA V2 Rework Batch 5 - 2026-06-02

Single-pass router cycle tasks moved to review:

| Task ID | Source EA | Failed evidence | V2 label |
| --- | --- | --- | --- |
| `2d83e1dc-6645-463b-87df-65adcfcd4666` | `QM5_12112` | multi-symbol Q-phase failures from pipeline evidence | `QM5_12112_channel-keltner-trend_v2` |
| `7c474fc4-2d99-43bb-9d0e-9caf251d47e2` | `QM5_12117` | multi-symbol Q-phase failures from pipeline evidence | `QM5_12117_demark-td-sequential-h4_v2` |
| `9bc1a94c-81f6-47e2-a9e6-31c80007d7ed` | `QM5_12116` | multi-symbol Q-phase failures from pipeline evidence | `QM5_12116_carter-ttm-squeeze-h1_v2` |
| `cb8c169e-4857-4a66-b046-eb6f41adfa4c` | `QM5_12115` | multi-symbol Q-phase failures from pipeline evidence | `QM5_12115_classic-pivot-points-fade-break_v2` |
| `df232a93-e897-4c0f-9fd8-f838d2687553` | `QM5_10429` | Q02 failure from pipeline evidence | `QM5_10429_et-rsi2-es_v2` |

## Evidence Inspected

- Task payloads and work-item IDs from the router.
- Work-item logs under `D:/QM/strategy_farm/logs/work_item_<id>.log`.
- Source EAs and setfiles under `C:/QM/repo/framework/EAs/`.

The active source directories existed for all five EAs. Codex created new `_v2` directories by copying the original directories and renaming the `.mq5` source file to match the `_v2` EA label. Original source directories were not modified.

## Source Fix

This batch uses the shared framework fix recorded in `docs/ops/CODEX_FAILED_EA_V2_REWORK_BATCH3_2026-06-02.md`:

- `framework/include/QM/QM_RiskSizer.mqh` now falls back to `OrderCalcMargin` when custom `.DWX` symbols do not expose usable `SYMBOL_MARGIN_INITIAL`.
- The fallback caps fixed-risk lot size by available margin and quantizes through `QM_RiskSizerQuantizeLots`.

No per-EA strategy logic was changed in this batch beyond creating `_v2` copies. The rebuilt `.ex5` artifacts include the shared risk-sizer guard.

## Focused Verification

Compiles used isolated `APPDATA=C:/QM/repo/.tmp_compile_appdata` to avoid locked MetaQuotes include files. One QM5_12117 retry against T2 reached a bad MetaEditor data directory missing `Trade/Trade.mqh`; the successful QM5_12117 compile used the T1 path after the lock cleared.

Static symbol-scope validation:

| V2 label | Validator verdict |
| --- | --- |
| `QM5_12112_channel-keltner-trend_v2` | `SINGLE_SYMBOL_OK` |
| `QM5_12117_demark-td-sequential-h4_v2` | `SINGLE_SYMBOL_OK` |
| `QM5_12116_carter-ttm-squeeze-h1_v2` | `SINGLE_SYMBOL_OK` |
| `QM5_12115_classic-pivot-points-fade-break_v2` | `SINGLE_SYMBOL_OK` |
| `QM5_10429_et-rsi2-es_v2` | `SINGLE_SYMBOL_OK` |

Direct compile evidence:

| V2 label | Compile verdict | EX5 bytes | Compile log |
| --- | --- | ---: | --- |
| `QM5_12112_channel-keltner-trend_v2` | PASS, `0 errors, 0 warnings` | 191090 | `C:/QM/repo/framework/build/compile/20260602_205840/QM5_12112_channel-keltner-trend_v2.compile.log` |
| `QM5_12117_demark-td-sequential-h4_v2` | PASS, `0 errors, 0 warnings` | 191832 | `C:/QM/repo/framework/build/compile/20260602_210316/QM5_12117_demark-td-sequential-h4_v2.compile.log` |
| `QM5_12116_carter-ttm-squeeze-h1_v2` | PASS, `0 errors, 0 warnings` | 193708 | `C:/QM/repo/framework/build/compile/20260602_205931/QM5_12116_carter-ttm-squeeze-h1_v2.compile.log` |
| `QM5_12115_classic-pivot-points-fade-break_v2` | PASS, `0 errors, 0 warnings` | 192062 | `C:/QM/repo/framework/build/compile/20260602_205959/QM5_12115_classic-pivot-points-fade-break_v2.compile.log` |
| `QM5_10429_et-rsi2-es_v2` | PASS, `0 errors, 0 warnings` | 190598 | `C:/QM/repo/framework/build/compile/20260602_210022/QM5_10429_et-rsi2-es_v2.compile.log` |

Structured compile result paths:

- `D:/QM/reports/compile/QM5_12112_channel-keltner-trend_v2/result.json`
- `D:/QM/reports/compile/QM5_12117_demark-td-sequential-h4_v2/result.json`
- `D:/QM/reports/compile/QM5_12116_carter-ttm-squeeze-h1_v2/result.json`
- `D:/QM/reports/compile/QM5_12115_classic-pivot-points-fade-break_v2/result.json`
- `D:/QM/reports/compile/QM5_10429_et-rsi2-es_v2/result.json`

## Review Boundary

No `T_Live`, `AutoTrading`, or `terminal64.exe` references were added. No MT5 smoke/backtest run was started by this cycle.

These tasks are ready for Codex review of the `_v2` code/artifacts and the shared risk-sizer guard. Pipeline verdicts must come only from subsequent Q-phase evidence after review/enqueue.
