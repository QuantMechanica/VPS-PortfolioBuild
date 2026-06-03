# Codex Failed EA V2 Rework Batch 3 - 2026-06-02

Single-pass router cycle tasks moved to review:

| Task ID | Source EA | Failed evidence | V2 label |
| --- | --- | --- | --- |
| `68a9ba8c-9b13-4c6e-905d-42badc7dbfd5` | `QM5_10760` | Q02 `WS30.DWX`: `ONINIT_FAILED;INCOMPLETE_RUNS` | `QM5_10760_tv-iu-orb_v2` |
| `7584a464-6eb7-4fb6-8d61-0df859e7de39` | `QM5_10542` | Q02 `GDAXI.DWX`: `ONINIT_FAILED;INCOMPLETE_RUNS` | `QM5_10542_mql5-bigdog_v2` |
| `78460a75-1b8a-4570-b710-485aa615ac7f` | `QM5_10676` | Q05 `NDX.DWX`: `missing_pf_or_dd_in_summary` | `QM5_10676_tv-pdh-vwap_v2` |
| `bbb0cdb2-6c41-444d-854c-906db563fe39` | `QM5_10762` | Q02 `GDAXI.DWX`, `USDJPY.DWX`, `WS30.DWX`: `ONINIT_FAILED` / report missing | `QM5_10762_tv-trend-brk_v2` |
| `dba5fb5f-1e0a-42e9-9296-05bec819ebca` | `QM5_10587` | Q02 `GBPJPY.DWX`, `USDJPY.DWX`: `ONINIT_FAILED;INCOMPLETE_RUNS` | `QM5_10587_mql5-modopt_v2` |

## Evidence Inspected

- Work-item logs under `D:/QM/strategy_farm/logs/work_item_<id>.log`.
- Q02/Q05 summaries under `D:/QM/reports/work_items/<id>/.../summary.json`.
- Framework evidence markdown under `D:/QM/reports/framework/22/`.
- Source EAs and setfiles under `C:/QM/repo/framework/EAs/`.

Key finding: the recurring EA-side runtime symptom in the raw tester logs is oversized order volume, e.g. `not enough money` / `failed market ... [No money]`, caused by fixed-risk sizing on custom `.DWX` symbols when `SYMBOL_MARGIN_INITIAL` is absent or zero. The current framework only capped by static `SYMBOL_MARGIN_INITIAL`, so custom symbols could send margin-impossible orders.

The QM5_10676 Q05 failures are report/metric invalidation (`REPORT_FORMAT_DRIFT`, stale news calendar in later reruns, and missing PF/DD aggregate fields). The EA also shows `No money` evidence in NDX runs, so the same margin-cap fix is relevant, but Q05 verdict recovery must come from fresh Q-phase evidence.

## Source Fix

Patched `framework/include/QM/QM_RiskSizer.mqh`:

- Preserve existing fixed-risk and symbol-snapshot sizing.
- If `SYMBOL_MARGIN_INITIAL > 0`, keep the existing static margin cap.
- If `SYMBOL_MARGIN_INITIAL <= 0`, fall back to `OrderCalcMargin(ORDER_TYPE_BUY, symbol, 1.0, ask, margin_one_lot)` and cap lots by `ACCOUNT_MARGIN_FREE / margin_one_lot`.
- Quantize the capped lot size through the existing `QM_RiskSizerQuantizeLots` path.

The five `_v2` EA directories already existed in `C:/QM/repo` before this cycle inspected them. Codex did not overwrite those source directories. The rebuilt `.ex5` artifacts below include the risk-sizer margin fallback.

## Focused Verification

Initial compile attempts using the default system-profile `APPDATA` failed during include sync because MetaQuotes include files were locked by another process. The successful compile pass used an isolated temporary `APPDATA` path (`C:/QM/repo/.tmp_compile_appdata`) and synced only `D:/QM/mt5/T1/MQL5/Include`.

Static symbol-scope validation:

| V2 label | Validator verdict |
| --- | --- |
| `QM5_10760_tv-iu-orb_v2` | `SINGLE_SYMBOL_OK` |
| `QM5_10542_mql5-bigdog_v2` | `SINGLE_SYMBOL_OK` |
| `QM5_10676_tv-pdh-vwap_v2` | `SINGLE_SYMBOL_OK` |
| `QM5_10762_tv-trend-brk_v2` | `SINGLE_SYMBOL_OK` |
| `QM5_10587_mql5-modopt_v2` | `SINGLE_SYMBOL_OK` |

Direct compile evidence:

| V2 label | Compile verdict | EX5 bytes | Compile log |
| --- | --- | ---: | --- |
| `QM5_10760_tv-iu-orb_v2` | PASS, `0 errors, 0 warnings` | 193374 | `C:/QM/repo/framework/build/compile/20260602_201450/QM5_10760_tv-iu-orb_v2.compile.log` |
| `QM5_10542_mql5-bigdog_v2` | PASS, `0 errors, 0 warnings` | 192560 | `C:/QM/repo/framework/build/compile/20260602_201458/QM5_10542_mql5-bigdog_v2.compile.log` |
| `QM5_10676_tv-pdh-vwap_v2` | PASS, `0 errors, 0 warnings` | 199786 | `C:/QM/repo/framework/build/compile/20260602_201752/QM5_10676_tv-pdh-vwap_v2.compile.log` |
| `QM5_10762_tv-trend-brk_v2` | PASS, `0 errors, 0 warnings` | 189748 | `C:/QM/repo/framework/build/compile/20260602_201652/QM5_10762_tv-trend-brk_v2.compile.log` |
| `QM5_10587_mql5-modopt_v2` | PASS, `0 errors, 0 warnings` | 188946 | `C:/QM/repo/framework/build/compile/20260602_201719/QM5_10587_mql5-modopt_v2.compile.log` |

Structured compile result paths:

- `D:/QM/reports/compile/QM5_10760_tv-iu-orb_v2/result.json`
- `D:/QM/reports/compile/QM5_10542_mql5-bigdog_v2/result.json`
- `D:/QM/reports/compile/QM5_10676_tv-pdh-vwap_v2/result.json`
- `D:/QM/reports/compile/QM5_10762_tv-trend-brk_v2/result.json`
- `D:/QM/reports/compile/QM5_10587_mql5-modopt_v2/result.json`

## Review Boundary

No `T_Live`, `AutoTrading`, or `terminal64.exe` references were added. No MT5 smoke/backtest run was started by this cycle.

These tasks are ready for Codex review of the `_v2` code/artifacts and the shared risk-sizer guard. Pipeline verdicts must come only from subsequent Q-phase evidence after review/enqueue.
