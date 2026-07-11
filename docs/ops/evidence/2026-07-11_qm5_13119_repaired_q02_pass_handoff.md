# QM5_13119 repaired FX basket Q02 PASS handoff

- **Recorded:** 2026-07-11 06:14 UTC
- **Branch:** `agents/board-advisor`
- **EA:** `QM5_13119_usdjpy-euraud`
- **Logical basket:** `QM5_13119_USDJPY_EURAUD_COINTEGRATION_D1`

## Outcome

The repaired USDJPY/EURAUD D1 cointegration basket passed its full real-tick
Q02 baseline. This is the promotion-eligible result for the binary repaired in
commit `b92667599587ad889b24f4be4d25427981b9a0d3`; the earlier pre-repair PASS
remains superseded because its USDJPY host order bypassed the mandatory trade
manager path.

| Metric | Repaired Q02 |
|---|---:|
| Verdict | PASS |
| Window | 2018-07-02 through 2022-12-31 |
| Model / period | Real ticks (`4`) / D1 |
| Trades | 136 (minimum 25) |
| Profit factor | 1.06 |
| Net profit | 966.39 |
| Maximum drawdown | 3,033.82 (2.92%) |
| Attempts / non-OK attempts | 1 / 0 |
| ONINIT failure | false |
| Real-tick marker | true |
| Log bomb | false |

Canonical evidence:
`D:/QM/reports/work_items/77ec9572-e064-44bd-a756-51647aa383b9/QM5_13119/20260711_054814/summary.json`.

## Why this was the non-duplicate continuation

The published positive-hedge 66-pair screen has only the already-built
EURJPY/GBPJPY and AUDUSD/NZDUSD survivors. The strict sign-aware reproduction
adds GBPUSD/USDCAD, USDCAD/NZDUSD, AUDUSD/EURGBP, EURGBP/AUDJPY, and
USDJPY/EURAUD; every one now has an EA build. Creating another card would
duplicate or weaken the reputable-source frontier.

The two requested anchors are not Q02 setup blockers:

- `QM5_12532`: logical-basket Q02 PASS, Q04 PASS, then Q05 FAIL.
- `QM5_12533`: logical-basket Q02 PASS, then Q04 FAIL.

`QM5_13119` was therefore the correct existing forex card to advance. It is
the final strict sign-aware row and was awaiting the repaired-binary Q02 after
the mechanical framework review finding was cleared.

## Structural and risk contract

- Traded legs: `USDJPY.DWX` and `EURAUD.DWX`.
- Conversion-only histories: `AUDUSD.DWX` and `EURUSD.DWX`.
- Basket manifest is present and was used by the runner.
- Backtest risk is `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- The fixed beta, prior-60-bar z-score calibration, entry/exit thresholds, and
  ATR hard-stop rules were unchanged.
- The repaired USDJPY host leg uses `QM_TM_OpenPosition`; EURAUD remains the
  explicit basket companion.

The repaired result closely matches the superseded binary (136 trades, PF
1.06, net 954.43, drawdown 3,024.38 / 2.91%), showing that framework routing
was corrected without changing the screened edge.

## Capacity and safety

The run used the repository-supported targeted worker under
`FACTORY_OFF.flag`, claiming exactly work item
`77ec9572-e064-44bd-a756-51647aa383b9` on T2. No other T1-T5 tester was
started; T2 exited cleanly after classification, so the CPU ceiling was not
reached.

No Q03 run or global cascade was launched. No `T_Live`, AutoTrading, live
manifest, portfolio gate, `portfolio_admission`, portfolio KPI, or Q08
contribution path was touched.

Machine-readable evidence is in
`artifacts/qm5_13119_repaired_q02_pass_handoff_20260711.json`.
