---
ea_id: QM5_10329
slug: imbalance-rev
type: strategy
source_id: fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9
source_citation: "Tarun Chordia, Avanidhar Subrahmanyam, Richard W. Roll, Orderimbalance, Liquidity and Market Returns, SSRN abstract 261876, 2001, https://papers.ssrn.com/sol3/papers.cfm?abstract_id=261876"
sources:
  - "[[sources/ssrn-microstructure-hft]]"
concepts:
  - "[[concepts/order-imbalance]]"
  - "[[concepts/liquidity-reversal]]"
  - "[[concepts/market-wide-reversal]]"
indicators:
  - "[[indicators/daily-return]]"
  - "[[indicators/tick-volume-delta]]"
  - "[[indicators/atr]]"
target_symbols: [SP500.DWX, NDX.DWX, WS30.DWX, GER40.DWX]
period: D1
expected_trade_frequency: "Daily reversal after large same-direction return and tick-volume-imbalance proxy; conservative estimate 30-60 trades/year/symbol."
expected_trades_per_year_per_symbol: 45
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
r1_reasoning: "Single source_id with SSRN URL and named authors (Chordia, Subrahmanyam, Roll 2001)."
r2_reasoning: "Daily return and tick-volume percentile rules, next-close exit, ATR stop are deterministic."
r3_reasoning: "Signed tick-volume proxy is available in MT5; NDX.DWX, WS30.DWX, GER40.DWX are testable DWX instruments."
r4_reasoning: "Fixed percentile thresholds and stops; no ML, adaptive sizing, or martingale."
pipeline_phase: G0
last_updated: 2026-05-21
g0_approval_reasoning: "R1 PASS SSRN paper URL/attribution; R2 PASS deterministic daily return plus tick-volume imbalance reversal with next-close exit and 45 trades/year/symbol; R3 PASS port-testable on DWX indices with SP500 T6 caveat; R4 PASS fixed rules no ML/grid/martingale."
---

# Imbalance Rev

## Quelle
- Source: [[sources/ssrn-microstructure-hft]]
- Paper URL: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=261876
- Paper: Tarun Chordia, Avanidhar Subrahmanyam, Richard W. Roll, "Orderimbalance, Liquidity and Market Returns", SSRN, 2001.
- Source location: SSRN abstract. The abstract documents market-wide return reversal after high negative imbalance and large negative return days.

## Mechanik

### Entry
- Evaluate after each daily close.
- Build a DWX order-imbalance proxy from intraday tick volume: sum signed M30 tick volume where sign is `close - open`.
- Long next session open if prior daily return is below `-1.0 * ATR(14,D1)` and signed tick-volume imbalance is in the bottom 20% of its 252-day history.
- Short next session open if prior daily return is above `1.0 * ATR(14,D1)` and signed tick-volume imbalance is in the top 20% of its 252-day history.
- If true broker order-flow data is unavailable, keep the tick-volume proxy explicit and let G0/CTO decide whether R3 remains acceptable.

### Exit
- Exit at the next daily close.
- No multi-day hold unless P3 explicitly creates a fixed 2-day variant.

### Stop Loss
- Stop at `1.25 * ATR(14,D1)` from entry.
- One signal per symbol per day.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.

### Zusaetzliche Filter
- Skip if current spread at entry exceeds rolling 80th percentile.
- Skip days with missing M30 volume bars.
- Skip if prior day range is below the 20-day median range; the source effect is tied to large price-pressure days.

## Concepts
- [[concepts/order-imbalance]] - primary
- [[concepts/liquidity-reversal]] - primary
- [[concepts/market-wide-reversal]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | SSRN URL plus named authors and institutional affiliations. |
| R2 Mechanical | PASS | Daily return, imbalance proxy, percentile threshold, next-day exit, and ATR stop are deterministic. |
| R3 DWX-testbar | UNKNOWN | Source uses NYSE buy-minus-sell order imbalance; DWX port requires a tick-volume proxy unless true signed flow is available. |
| R4 No ML | PASS | Fixed percentile rules and stops; no ML, adaptive online parameters, grid, or martingale. |

## R3
Primary P2 basket: `SP500.DWX`, `NDX.DWX`, `WS30.DWX`, `GER40.DWX`. SP500.DWX caveat if used: "Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable."

## Author Claims
- "buy orders less sell orders" (SSRN abstract).
- "Market returns reverse themselves after high negative imbalance, large negative return days" (SSRN abstract).

## Pipeline-Verlauf
- G0: 2026-05-21, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10327_eod-reversal]] - intraday final-half-hour reversal.
- [[strategies/QM5_10328_residual-rev]] - residual return reversal.

## Lessons Learned
- TBD during pipeline run.

