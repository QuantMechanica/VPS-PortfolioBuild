---
ea_id: QM5_1075
slug: as-accel-dualmom
type: strategy
source_id: 2df06de7-6a3a-5b06-9e6d-446d1a01fab9
g0_status: APPROVED
pipeline_phase: G0
last_updated: 2026-05-18
---

# Allocate Smartly Accelerating Dual Momentum

## Quelle
- Source: `[[sources/allocate-smartly-strategies]]`
- Catalogue entry: Allocate Smartly "List of Strategies", line listing "Accelerating Dual Momentum" by Engineered Portfolio.
- Rule reference: Engineered Portfolio (2018), "Accelerating Dual Momentum Investing".

## Mechanik

### Entry
- Timeframe: D1.
- Evaluate the accelerating dual momentum score on the D1 close of the last trading day of the month.
- Open the new selection on the first session of the next month.

At the beginning of each month using prior month-end data:
- Compute accelerating momentum score for US stocks and international small-cap stocks:
  `score = 1-month return + 3-month return + 6-month return`.
- If both equity scores are below zero, allocate 100% to long-term Treasuries / defensive bond proxy.
- Otherwise allocate 100% to the equity asset with the higher accelerating momentum score.

DWX port:
- US stocks: `SP500.DWX` backtest-only and/or `NDX.DWX` / `WS30.DWX` live-tradable validation.
- International small-cap stocks: no exact DWX proxy; test `GER40.DWX` or broad non-US index proxy.
- Long-term Treasuries: no direct DWX bond ETF; default defensive state is flat/cash unless CEO approves another defensive proxy.

### Exit
- Exit and rotate at the next monthly rebalance when selected asset changes.
- Hold current selection otherwise.

### Stop Loss
- Source uses monthly absolute/relative momentum rotation rather than intramonth stop.
- Framework catastrophic stop only if required.

### Position Sizing
- Original: 100% in one of three assets.
- DWX port: one active position per magic.

### Zusätzliche Filter
- Monthly rebalance only.
- Framework spread/news filters.

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Allocate Smartly catalogue names Engineered Portfolio; original public article gives the rules. |
| R2 Mechanical | PASS | 1/3/6-month return score and negative-score defensive trigger are deterministic. |
| R3 Data Available | UNKNOWN | US index proxy is available; international small-cap and Treasury legs need approved DWX proxy/flat mapping. |
| R4 ML Forbidden | PASS | Fixed monthly lookbacks, no ML, no adaptive parameters, concentrated one-position rotation. |

## R3
Live promotion T6 gate: `SP500.DWX` is not broker-routable. If the EA passes P0-P9 on `SP500.DWX` only, T6 deploy requires a parallel-validation on `NDX.DWX` or `WS30.DWX` before AutoTrading enable.
