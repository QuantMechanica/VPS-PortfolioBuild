# Codex Failed EA V2 Rework Batch 4 - 2026-06-02

Single-pass router cycle tasks moved to review:

| Task ID | Source EA | Failed evidence | V2 label |
| --- | --- | --- | --- |
| `58529de4-4470-43c9-9098-66740f45c1a1` | `QM5_10562` | Q02 `GBPJPY.DWX`: `ONINIT_FAILED;INCOMPLETE_RUNS` | `QM5_10562_mql5-donch-sys_v2` |
| `f229d72a-d379-4174-b686-71d2699b00d2` | `QM5_10567` | Q02 `GBPJPY.DWX`: `ONINIT_FAILED;INCOMPLETE_RUNS` | `QM5_10567_mql5-aroonhorn_v2` |
| `7f23e6cb-1df9-4ca4-acaa-08bc68e991dc` | `QM5_10569` | Q07 `EURJPY.DWX`: `seeds_with_invalid_pf:[17]`; later rerun invalid reports on all seeds | `QM5_10569_mql5-supertrend_v2` |
| `64d8e1e8-e085-43fb-852b-5aee489a1ce8` | `QM5_10478` | Q02 `USDJPY.DWX`: `ONINIT_FAILED;INCOMPLETE_RUNS` | `QM5_10478_mql5-bago_v2` |
| `98208be5-fdfa-4546-b679-5ac088849e31` | `QM5_10705` | Q02 `USDJPY.DWX`: `ONINIT_FAILED;INCOMPLETE_RUNS`; report also flagged `BARS_ZERO` / `HISTORY_CONTEXT_INVALID` | `QM5_10705_tv-liq-trap_v2` |

## Evidence Inspected

- Router payloads for the five `IN_PROGRESS` build tasks.
- Work-item logs under `D:/QM/strategy_farm/logs/work_item_<id>.log`.
- Q-phase summaries under `D:/QM/reports/work_items/<id>/.../summary.json`.
- Tester log excerpts where present.
- Source EAs and setfiles under `C:/QM/repo/framework/EAs/`.

## Source Artifacts

Created new `_v2` EA directories for the four source EAs that did not already have one:

- `C:/QM/repo/framework/EAs/QM5_10478_mql5-bago_v2/`
- `C:/QM/repo/framework/EAs/QM5_10562_mql5-donch-sys_v2/`
- `C:/QM/repo/framework/EAs/QM5_10567_mql5-aroonhorn_v2/`
- `C:/QM/repo/framework/EAs/QM5_10569_mql5-supertrend_v2/`

Reused the existing `C:/QM/repo/framework/EAs/QM5_10705_tv-liq-trap_v2/` directory and refreshed its compile artifact. Originals were not overwritten.

## Focused Verification

Static symbol-scope validation:

| V2 label | Validator verdict |
| --- | --- |
| `QM5_10478_mql5-bago_v2` | `SINGLE_SYMBOL_OK` |
| `QM5_10562_mql5-donch-sys_v2` | `SINGLE_SYMBOL_OK` |
| `QM5_10567_mql5-aroonhorn_v2` | `SINGLE_SYMBOL_OK` |
| `QM5_10569_mql5-supertrend_v2` | `SINGLE_SYMBOL_OK` |
| `QM5_10705_tv-liq-trap_v2` | `SINGLE_SYMBOL_OK` |

Direct compile evidence:

| V2 label | Compile verdict | EX5 bytes | Compile log |
| --- | --- | ---: | --- |
| `QM5_10478_mql5-bago_v2` | PASS, `0 errors, 0 warnings` | 194666 | `C:/QM/repo/framework/build/compile/20260602_210046/QM5_10478_mql5-bago_v2.compile.log` |
| `QM5_10562_mql5-donch-sys_v2` | PASS, `0 errors, 0 warnings` | 195186 | `C:/QM/repo/framework/build/compile/20260602_210120/QM5_10562_mql5-donch-sys_v2.compile.log` |
| `QM5_10567_mql5-aroonhorn_v2` | PASS, `0 errors, 0 warnings` | 192400 | `C:/QM/repo/framework/build/compile/20260602_210207/QM5_10567_mql5-aroonhorn_v2.compile.log` |
| `QM5_10569_mql5-supertrend_v2` | PASS, `0 errors, 0 warnings` | 193806 | `C:/QM/repo/framework/build/compile/20260602_210243/QM5_10569_mql5-supertrend_v2.compile.log` |
| `QM5_10705_tv-liq-trap_v2` | PASS, `0 errors, 0 warnings` | 190614 | `C:/QM/repo/framework/build/compile/20260602_210308/QM5_10705_tv-liq-trap_v2.compile.log` |

Structured compile result paths:

- `D:/QM/reports/compile/QM5_10478_mql5-bago_v2/result.json`
- `D:/QM/reports/compile/QM5_10562_mql5-donch-sys_v2/result.json`
- `D:/QM/reports/compile/QM5_10567_mql5-aroonhorn_v2/result.json`
- `D:/QM/reports/compile/QM5_10569_mql5-supertrend_v2/result.json`
- `D:/QM/reports/compile/QM5_10705_tv-liq-trap_v2/result.json`

## Review Boundary

No MT5 smoke/backtest run was started by this cycle. No `T_Live`, `AutoTrading`, or `terminal64.exe` references were added to the `_v2` directories. Pipeline verdicts must come only from subsequent Q-phase evidence after review/enqueue.
