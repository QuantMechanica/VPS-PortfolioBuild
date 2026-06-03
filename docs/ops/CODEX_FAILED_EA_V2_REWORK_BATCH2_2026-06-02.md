# Codex Failed EA V2 Rework Batch 2 - 2026-06-02

Single-pass router cycle tasks moved to review:

| Task ID | Source EA | Failed symbols | V2 label |
| --- | --- | --- | --- |
| `d36d5b71-8698-489c-8166-c5f0e5e8aebd` | `QM5_10677` | `SP500.DWX` | `QM5_10677_tv-session-sweep_v2` |
| `de448769-d15f-4af5-931d-eee6a9eb99c4` | `QM5_10694` | `GDAXI.DWX`, `SP500.DWX`, `USDJPY.DWX` | `QM5_10694_tv-ict-silver_v2` |
| `95edd8d3-9957-49a2-9bfb-cc9f858d3410` | `QM5_10743` | `WS30.DWX` | `QM5_10743_tv-nq-orb_v2` |
| `70a29f36-8861-4b71-8b1b-c3d18330e262` | `QM5_10759` | `SP500.DWX` | `QM5_10759_tv-scp-score_v2` |
| `3e541bbb-2b2f-4eec-bc84-d0b6bb1a5538` | `QM5_10772` | `GDAXI.DWX`, `USDJPY.DWX`, `WS30.DWX` | `QM5_10772_tv-ny-vwap-ret_v2` |

## Source Fixes

The `_v2` EA directories already existed in `C:/QM/repo` when this cycle inspected the tasks. Codex did not overwrite them. Two concrete source correctness fixes were applied before compile:

- `framework/EAs/QM5_10694_tv-ict-silver_v2/QM5_10694_tv-ict-silver_v2.mq5`: `qm_ea_id` changed from placeholder `9999` to `10694`.
- `framework/EAs/QM5_10772_tv-ny-vwap-ret_v2/QM5_10772_tv-ny-vwap-ret_v2.mq5`: `qm_ea_id` changed from placeholder `9999` to `10772`.

No `T_Live`, `AutoTrading`, or `terminal64.exe` references were found in the five `_v2` EA directories. No MT5 terminal/backtest/smoke run was started by this cycle.

## Focused Verification

Static symbol-scope validation:

| V2 label | Validator verdict |
| --- | --- |
| `QM5_10677_tv-session-sweep_v2` | `SINGLE_SYMBOL_OK` |
| `QM5_10694_tv-ict-silver_v2` | `SINGLE_SYMBOL_OK` |
| `QM5_10743_tv-nq-orb_v2` | `SINGLE_SYMBOL_OK` |
| `QM5_10759_tv-scp-score_v2` | `SINGLE_SYMBOL_OK` |
| `QM5_10772_tv-ny-vwap-ret_v2` | `SINGLE_SYMBOL_OK` |

Direct compile evidence:

| V2 label | Compile verdict | EX5 bytes | Compile log |
| --- | --- | ---: | --- |
| `QM5_10677_tv-session-sweep_v2` | PASS, `0 errors, 0 warnings` | 195618 | `C:/QM/repo/framework/build/compile/20260602_195235/QM5_10677_tv-session-sweep_v2.compile.log` |
| `QM5_10694_tv-ict-silver_v2` | PASS, `0 errors, 0 warnings` | 195304 | `C:/QM/repo/framework/build/compile/20260602_195323/QM5_10694_tv-ict-silver_v2.compile.log` |
| `QM5_10743_tv-nq-orb_v2` | PASS, `0 errors, 0 warnings` | 193594 | `C:/QM/repo/framework/build/compile/20260602_195356/QM5_10743_tv-nq-orb_v2.compile.log` |
| `QM5_10759_tv-scp-score_v2` | PASS, `0 errors, 0 warnings` | 198270 | `C:/QM/repo/framework/build/compile/20260602_195421/QM5_10759_tv-scp-score_v2.compile.log` |
| `QM5_10772_tv-ny-vwap-ret_v2` | PASS, `0 errors, 0 warnings` | 198754 | `C:/QM/repo/framework/build/compile/20260602_195443/QM5_10772_tv-ny-vwap-ret_v2.compile.log` |

Structured compile result paths were refreshed after direct compile:

- `D:/QM/reports/compile/QM5_10677_tv-session-sweep_v2/result.json`
- `D:/QM/reports/compile/QM5_10694_tv-ict-silver_v2/result.json`
- `D:/QM/reports/compile/QM5_10743_tv-nq-orb_v2/result.json`
- `D:/QM/reports/compile/QM5_10759_tv-scp-score_v2/result.json`
- `D:/QM/reports/compile/QM5_10772_tv-ny-vwap-ret_v2/result.json`

## Review Boundary

These tasks are ready for Codex review of the `_v2` code and compile evidence. Pipeline verdicts must come only from subsequent Q-phase evidence after review/enqueue.
