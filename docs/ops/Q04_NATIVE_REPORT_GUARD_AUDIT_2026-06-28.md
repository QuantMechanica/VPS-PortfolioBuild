# Q04 Native Report Guard Audit - 2026-06-28

Scope: audit the six OWNER-specified candidates against native MT5 fold
reports after discovering that Q04's Common Files trade stream can miss closing
deals and inflate `pf_net`.

## Runner Fix

`framework/scripts/q04_walkforward.py` now guards the preferred stream/self-report
PF against the native MT5 `summary.json` fold metrics:

- if stream trade count differs from native report trade count, Q04 falls back
  to the native report metrics and records `native_report_guard_fallback`;
- if stream PF materially exceeds native report PF, Q04 falls back and records
  `pf_contradicts_report`;
- matching stream/report folds continue to use the shared worst-case commission
  stream path.

This prevents an incomplete EA-side stream from turning a losing native report
into a Q04 PASS.

## Candidate Recheck

| EA | symbol | old Q04 verdict | guarded Q04 read | action |
|---|---|---|---|---|
| `QM5_11476` | `USDJPY.DWX` | `PASS_SOFT` | `PASS_SOFT`; folds `0.871 / 1.516 / 1.120` | Keep as top near-miss rescue. |
| `QM5_9636` | `GBPUSD.DWX` | `PASS_SOFT` | `PASS_SOFT`; native folds `1.20 / 0.87 / 1.80` | Valid Q04, but Q05 drawdown remains high. |
| `QM5_10198` | `GBPUSD.DWX` | `PASS` | `PASS`; native folds `1.18 / 1.39 / 1.02` | Valid Q04, but Q05 drawdown remains high. |
| `QM5_10041` | `GBPUSD.DWX` | `PASS` | `FAIL`; native folds `0.69 / 0.73 / 1.38` | Remove from rescue queue; old Q04 aggregate was false-positive. |
| `QM5_11708` | `AUDUSD.DWX` | `PASS_LOWFREQ` | `FAIL`; native folds `0.23 / 0.91 / 0 trades` | Remove from rescue queue; lowfreq pooled pass was stream-driven. |
| `QM5_10300` | `XTIUSD.DWX` | `PASS_SOFT` | `FAIL`; native folds `0.74 / 1.07 / 1.00` | Remove from rescue queue; not a clean commodity sleeve candidate. |

## Implication

The current actionable Q05 near-miss pool from this batch is reduced to:

1. `QM5_11476 USDJPY.DWX` - real near miss: Q05 PF `0.98`, DD `9.65%`.
2. `QM5_10198 GBPUSD.DWX` - Q04 valid, but Q05 DD `41.80%`; needs drawdown work.
3. `QM5_9636 GBPUSD.DWX` - Q04 valid, but Q05 DD `36.85%`; needs drawdown work.

`QM5_10041`, `QM5_11708`, and `QM5_10300` should not be rerun unchanged as
portfolio rescues. Any future work on them is strategy redesign or explicit
rebuild, not pipeline admission.

No `T_Live` files, terminals, or AutoTrading state were touched.
