---
ea_id: QM5_1232
slug: carver-fastmom-cost
type: strategy
source_id: 2a380bee-1ec4-50d1-a348-b10fac642c7a
sources:
  - "[[sources/rob-carver-blog]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/trading-cost-filter]]"
  - "[[concepts/forecast-combination]]"
indicators:
  - "[[indicators/ewmac]]"
  - "[[indicators/spread-cost]]"
  - "[[indicators/atr-stop]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
expected_trades_per_year_per_symbol: 55
g0_approval_reasoning: "R1 qoppac source URLs present; R2 deterministic EWMAC/cost-gate entries and exits; R3 uses DWX OHLC/spread data across CFDs; R4 fixed formulas and one position per magic, no ML/grid/martingale."
---

# QM5_1232 Carver Cost-Conditioned Fast Momentum

## Quelle
- Source: [[sources/rob-carver-blog]]
- Primary URL: qoppac.blogspot.com/2023/02/fast-but-not-furious-do-fast-trading.html
- Supplemental URL: qoppac.blogspot.com/2015/09/python-code-for-two-trading-rules-in.html
- Author: Rob Carver. The 2023 post tests whether faster momentum rules can be included when forecast combination, buffering, dynamic optimisation, and per-instrument costs are considered; the 2015 post supplies the EWMAC implementation.

## Mechanik

Fast/slow EWMAC ensemble with a deterministic cost gate. Cheap instruments may use fast EWMAC variants, while expensive instruments are restricted to slower variants so expected annual trading cost stays under Carver's speed-limit idea.

### Entry
- On each closed D1 bar for each symbol:
  - Estimate `cost_per_trade_sr = MedianSpread(20D) / ATR(20,D1)`.
  - Assume quarterly roll equivalent is unavailable for CFDs, so `rolls_per_year = 0`.
  - `max_forecast_turnover = MaxAnnualCostSR / max(cost_per_trade_sr, 0.0001) - rolls_per_year`.
  - Default `MaxAnnualCostSR = 0.13`.
  - Candidate EWMAC variants:
    - Fast set: `2/8`, `4/16`, `8/32`.
    - Slow set: `16/64`, `32/128`, `64/256`.
  - Include a variant only if its expected turnover is <= `max_forecast_turnover`.
  - Expected turnover defaults: `2/8=25`, `4/16=18`, `8/32=12`, `16/64=8`, `32/128=5`, `64/256=3`.
  - Compute included EWMAC forecasts and equal-weight them.
  - Cap combined forecast to `[-20,+20]`.
- LONG if combined forecast > `+4`.
- SHORT if combined forecast < `-4`.

### Exit
- Close LONG when combined forecast <= `0`.
- Close SHORT when combined forecast >= `0`.
- Flip only on a later closed D1 bar with opposite threshold.

### Stop Loss
- Emergency stop: `2.5 * ATR(20, D1)`.
- Optional P3 variants: `2.0`, `2.5`, `3.0` ATR.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD per trade.
- Live: `RISK_PERCENT = 0.5%`.
- Size from emergency stop distance. One position per symbol/magic.

### Zusätzliche Filter
- Require at least `320` D1 bars for the slowest variant; if unavailable, use only variants with valid history.
- If no variant passes the speed limit, do not open new positions for that symbol.
- Spread cap: skip new entries when current spread exceeds `2 * MedianSpread(20D)`.
- Recalculate the allowed variant set monthly; forecasts update daily.

## Concepts
- [[concepts/trend-following]] - primary
- [[concepts/trading-cost-filter]] - primary
- [[concepts/forecast-combination]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Named author and exact qoppac URLs for the cost-conditioned momentum discussion and EWMAC formula. |
| R2 Mechanical | PASS | Cost estimate, variant inclusion, EWMAC ensemble, thresholds, and exits are deterministic. |
| R3 DWX-testbar | PASS | Uses DWX OHLC and spread data; portable to FX, indices, metals, and oil CFDs. |
| R4 No ML | PASS | Fixed speed-limit formula, fixed variant list, one position per magic, no ML, grid, or martingale. |

## R3 - T6 Live-Promotion-Caveat
N/A - proposed universe uses broker-routable DWX symbols only. SP500.DWX is not required.

## Pipeline-Verlauf
- G0: 2026-05-18 - drafted from Rob Carver blog fourth batch, PENDING.

## Verwandte Strategien
- [[strategies/QM5_1066_carver-ewmac-trend]] - single EWMAC base rule.
- [[strategies/QM5_1208_carver-normmom]] - normalised momentum cousin.

## Lessons Learned (wahrend Pipeline-Lauf)
- (noch keine)

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Anderung `pipeline_phase` aktualisieren + `last_updated`.*
