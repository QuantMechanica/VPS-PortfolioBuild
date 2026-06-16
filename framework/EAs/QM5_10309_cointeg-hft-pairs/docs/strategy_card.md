---
ea_id: QM5_10309
slug: cointeg-hft-pairs
type: strategy
source_id: fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9
sources:
  - "[[sources/ssrn-microstructure-hft]]"
concepts:
  - "[[concepts/cointegration]]"
  - "[[concepts/pairs-trading]]"
  - "[[concepts/statistical-arbitrage]]"
indicators:
  - "[[indicators/cointegration-residual]]"
  - "[[indicators/spread-zscore]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-21
expected_trades_per_year_per_symbol: 12
g0_approval_reasoning: "R1 PASS SSRN URL and named authors; R2 PASS deterministic cointegration residual entry/exit/stops with ~120 trades/year/symbol; R3 PASS ports to DWX FX/index/metal pairs; R4 PASS fixed non-ML bounded 1-package rules."
---

# Cointegrated HFT Pairs Reversion

## Quelle
- Source: [[sources/ssrn-microstructure-hft]]
- Paper URL: https://ssrn.com/abstract=2147012
- Paper: "Statistical Arbitrage Trading Strategies and High Frequency Trading", Thomas A. Hanson and Joshua Hall, SSRN, 2012/2013.
- Page / Timestamp: SSRN abstract and citation page. The abstract describes statistical arbitrage built on cointegration and studies how HFT changes pairs-trading profitability.

## Mechanik

### Entry
On M15 bars for a fixed DWX candidate pair:
- Formation window: 90 trading days of M15 closes.
- Run Engle-Granger cointegration check on log prices; require p-value `<= 0.05`.
- Estimate hedge ratio `beta` by OLS: `log(A) = alpha + beta * log(B) + residual`.
- Compute residual z-score using the last 20 trading days of M15 residuals.
- If `z >= +2.0`, short A and long `beta` units of B.
- If `z <= -2.0`, long A and short `beta` units of B.
- Enter only once per pair until the prior package is flat.

### Exit
- Exit when residual z-score crosses `0.0` or after 48 M15 bars, whichever comes first.
- Exit early if the rolling cointegration p-value over the last 30 days rises above `0.20`.

### Stop Loss
- Stop when `abs(z) >= 3.5`.
- Catastrophic package stop: realized package loss equals $1,000 P2 baseline risk.

### Position Sizing
Dollar-neutral synthetic package. Fixed $1,000 P2 risk equivalent across both legs; scale leg notionals by hedge ratio and recent volatility.

### Zusätzliche Filter
- Skip if either leg has missing bars in the formation window.
- Skip if estimated half-life of residual mean reversion is below 2 bars or above 96 bars.
- Skip if combined spread cost is larger than 15% of entry-to-mean distance.

## Concepts (was ist das für eine Strategie)
- [[concepts/cointegration]] - primary
- [[concepts/pairs-trading]] - secondary
- [[concepts/statistical-arbitrage]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | SSRN URL and named authors are present. |
| R2 Mechanical | PASS | Cointegration test, residual z-score entry, exit, and stops are deterministic. |
| R3 Data Available | PASS | Cointegration pairs can be tested on DWX FX, index, and metal CFDs after porting. |
| R4 ML Forbidden | PASS | Fixed econometric rules; no ML/neural/adaptive online parameter updates. |

## R3
Candidate DWX tests: `EURUSD.DWX`/`GBPUSD.DWX`, `AUDUSD.DWX`/`NZDUSD.DWX`, `GER40.DWX`/`FRA40.DWX` if available, and `SP500.DWX`/`NDX.DWX`. SP500.DWX caveat if used: "Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable."

## Pipeline-Verlauf
- G0: 2026-05-21, PENDING, drafted from SSRN microstructure/HFT batch 1.
- P1: TBD
- P2: TBD

## Verwandte Strategien
- [[strategies/QM5_10308_hft-pairs-z]] - simpler distance/z-score pairs variant.
- [[strategies/QM5_10310_ust-pairs-risk]] - pairs variant with explicit extreme-risk control.

## Lessons Learned (während Pipeline-Lauf)
- TBD

