---
ea_id: QM5_10308
slug: hft-pairs-z
type: strategy
source_id: fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9
sources:
  - "[[sources/ssrn-microstructure-hft]]"
concepts:
  - "[[concepts/pairs-trading]]"
  - "[[concepts/intraday-mean-reversion]]"
  - "[[concepts/statistical-arbitrage]]"
indicators:
  - "[[indicators/spread-zscore]]"
  - "[[indicators/rolling-correlation]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-21
expected_trades_per_year_per_symbol: 180
g0_approval_reasoning: "R1 PASS SSRN paper URL/citation; R2 PASS deterministic z-score pair entry/exit/stops with ~180 trades/year/symbol; R3 PASS ports to DWX FX/index/metal pairs; R4 PASS fixed non-ML bounded 1-package rules."
---

# HFT Pairs Z-Score Reversion

## Quelle
- Source: [[sources/ssrn-microstructure-hft]]
- Paper URL: https://ssrn.com/abstract=1611623
- Paper: "High Frequency Equity Pairs Trading: Transaction Costs, Speed of Execution and Patterns in Returns", David Bowen, Mark C. Hutchinson, Niall O'Sullivan, Journal of Trading, Summer 2010.
- Page / Timestamp: SSRN abstract and citation page. The abstract states that the paper examines high-frequency pairs trading on FTSE100 constituents, that transaction costs and execution delay matter, and that most returns occur in the first hour of trading.

## Mechanik

### Entry
On M5 bars for a preselected correlated DWX pair basket:
- Formation window: 60 trading days of M5 closes.
- Select pair only if rolling return correlation over the formation window is `>= 0.80`.
- Normalize both legs to cumulative return series from the formation-window start.
- Compute spread `S = norm_price_A - beta * norm_price_B`, with beta from OLS over the formation window.
- Compute rolling `z = (S - mean(S, 20 days)) / stdev(S, 20 days)`.
- If `z >= +2.0`, short leg A and long leg B.
- If `z <= -2.0`, long leg A and short leg B.
- One synthetic pair position per magic number; if V5 cannot manage two-leg synthetic execution under one EA, implement as the primary leg only against the stronger DWX proxy and mark R3 for reviewer escalation.

### Exit
- Exit both legs when `abs(z) <= 0.25`.
- Time exit after 24 M5 bars.
- Force flat at end of the first liquid session block if opened during the first trading hour.

### Stop Loss
- Pair stop when `abs(z) >= 3.5`.
- Catastrophic per-leg stop: `2.0 * ATR(14, M5)`.

### Position Sizing
Fixed $1,000 P2 risk equivalent across the synthetic pair, split 50/50 by leg volatility. One open pair package per magic number.

### Zusätzliche Filter
- Trade only during the most liquid 3-hour overlap for the tested symbols.
- Skip if combined spread cost exceeds 20% of the expected mean-reversion distance from entry to `z = 0`.
- No entries in the final 30 minutes of the configured session.

## Concepts (was ist das für eine Strategie)
- [[concepts/pairs-trading]] - primary
- [[concepts/intraday-mean-reversion]] - secondary
- [[concepts/statistical-arbitrage]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Named SSRN paper with authors, journal citation, DOI, and SSRN URL. |
| R2 Mechanical | PASS | Directional z-score pair entry, mean-reversion exit, time exit, and risk stop are deterministic. |
| R3 Data Available | PASS | Original equity universe ports to highly correlated DWX FX/index/metal pairs; M5 bars are available. |
| R4 ML Forbidden | PASS | Fixed statistical thresholds; no ML, online learning, martingale, or adaptive equity feedback. |

## R3
Primary DWX ports: `EURUSD.DWX`/`GBPUSD.DWX`, `AUDUSD.DWX`/`NZDUSD.DWX`, `SP500.DWX`/`NDX.DWX`, `XAUUSD.DWX`/`XAGUSD.DWX` if available. SP500.DWX caveat if used: "Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable."

## Pipeline-Verlauf
- G0: 2026-05-21, PENDING, drafted from SSRN microstructure/HFT batch 1.
- P1: TBD
- P2: TBD

## Verwandte Strategien
- [[strategies/QM5_10309_cointeg-hft-pairs]] - cointegration variant from the same SSRN lane.
- [[strategies/QM5_10310_ust-pairs-risk]] - pairs variant emphasizing extreme risk control.

## Lessons Learned (während Pipeline-Lauf)
- TBD

