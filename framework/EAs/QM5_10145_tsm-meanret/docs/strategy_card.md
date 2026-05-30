---
ea_id: QM5_10145
slug: tsm-meanret
type: strategy
source_id: d3c009d7-a8d6-5251-b572-4777b207c2b9
sources:
  - "[[sources/raposa-trade-python-backtesting]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/trend-following]]"
indicators:
  - "[[indicators/rolling-return]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
period: D1
expected_trades_per_year_per_symbol: 50
last_updated: 2026-05-19
g0_approval_reasoning: "R1 verifiable Raposa/Medium source URL; R2 deterministic rolling mean return sign entries/exits with ~50 trades/year/symbol; R3 close-only rule portable to DWX incl SP500.DWX caveat; R4 fixed rules no ML/grid/martingale."
---

# Rolling Mean Return Time-Series Momentum

## Quelle
- Source: [[sources/raposa-trade-python-backtesting]]
- Primary URL: https://raposa.trade/blog/how-to-build-your-first-momentum-trading-strategy-in-python/
- Medium mirror used for rule extraction: https://medium.com/raposa-technologies/how-to-build-your-first-momentum-trading-strategy-in-python-baf8c87087f0
- Author / institution: Raposa.Trade / Raposa Technologies
- Date: Feb. 26, 2021 on Medium mirror; Raposa archive lists the same tutorial family in 2021.
- Page / Timestamp: `TSMStrategy`

## Mechanik

### Entry
- Compute daily log return: `log(Close[t] / Close[t-1])`.
- Compute rolling mean return over lookback `N`; source tests `N = 1, 3, 5, 15, 30, 90`.
- Long-only default: enter or stay long when rolling mean return is positive.
- Optional long/short mode: enter or stay short when rolling mean return is less than or equal to zero.

### Exit
- Long-only mode: exit to flat when rolling mean return is less than or equal to zero.
- Long/short mode: reverse to short when rolling mean return is less than or equal to zero, and reverse to long when it becomes positive.

### Stop Loss
- Source suggests risk overlays are needed but does not define one.
- Research default: emergency stop at `3 * ATR(14)` from entry; rolling-return state remains primary exit.

### Position Sizing
- Source code tracks full-position returns and does not define lots.
- Use V5 fixed-risk P2 baseline and standard live risk conventions if approved.

### Zusaetzliche Filter
- D1 timeframe.
- Use previous completed bar values only; execute on next bar open.
- Transaction-cost sensitivity is high at `N = 1`; use `N = 15` as conservative default because the source reports the 15-day variant had the best absolute and risk-adjusted returns in the example.

## Concepts
- [[concepts/time-series-momentum]] - primary
- [[concepts/trend-following]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|-------------|
| R1 Track Record | PASS | Verifiable Raposa/Medium URL with named author handle and date. |
| R2 Mechanical | PASS | Rolling mean return sign maps directly to long/flat or long/short position state. |
| R3 Data Available | PASS | Close-only rule portable to DWX instruments. |
| R4 ML Forbidden | PASS | Fixed lookback windows and deterministic position mapping; no ML/adaptive/grid/martingale. |

## R3
Raposa example used GME, but the rule is close-only and can port to SP500.DWX, NDX.DWX, WS30.DWX, FX, metals, and oil CFDs. If SP500.DWX is used: Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- Source defines a simple time-series momentum rule that buys after positive recent average returns and either exits or shorts after non-positive recent average returns.
- Source reports the 15-day momentum indicator gave the best absolute and risk-adjusted returns among the tested lookbacks in the GME example, while warning the spread across results shows limited robustness.

## Parameters To Test
- `lookback_n`: 3, 5, 15, 30, 90
- `shorts_enabled`: false, true
- `atr_stop_mult`: 2.5, 3.0, 4.0
- `min_abs_mean_return`: 0.0, 0.00025, 0.0005

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, Research draft from Raposa momentum tutorial.

## Verwandte Strategien
- [[strategies/QM5_1056_moskowitz-tsmom-multiasset]] - longer-horizon academic multi-asset TSMOM.
- [[strategies/QM5_10143_rsi-momentum]] - oscillator momentum sibling from Raposa.

## Lessons Learned
- TBD
