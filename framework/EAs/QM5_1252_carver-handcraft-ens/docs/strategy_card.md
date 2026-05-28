---
ea_id: QM5_1252
slug: carver-handcraft-ens
type: strategy
source_id: 2a380bee-1ec4-50d1-a348-b10fac642c7a
g0_status: APPROVED
pipeline_phase: G0
last_updated: 2026-05-19
expected_trades_per_year_per_symbol: 35
---

# QM5_1252 Carver Handcrafted Live-Rule Ensemble

## Quelle
- Source: Rob Carver blog, 2021 live-system post.
- Supplemental code: pysystemtrade rules tree.
- Author: Rob Carver.

## Mechanik

Single-EA ensemble of Carver's live rule families using the hand-weighted forecast tree from the 2021 post. The EA combines already-mechanical component forecasts into one capped net forecast per symbol.

### Entry
- On each closed D1 bar, compute all component forecasts that have enough history and pass the cost speed limit:
  - EWMAC momentum: `4/16`, `8/32`, `16/64`, `32/128`, `64/256`.
  - Breakout: `10`, `20`, `40`, `80`, `160`, `320` day rolling range forecast.
  - Normalised momentum: `2`, `4`, `8`, `16`, `32`, `64`.
  - Skewabs `180/365`, mrinasset `160`, and accel `16/32/64`.
- Apply handcrafted Level-3-style weights, renormalising after unavailable or cost-forbidden components are removed.
- Cost gate: exclude any component whose expected annual turnover times `MedianSpread(20D)/ATR(20,D1)` exceeds `0.13` Sharpe-ratio cost units.
- Combined forecast = weighted sum of included forecasts, capped to `[-20,+20]`.
- LONG if combined forecast > `+5`.
- SHORT if combined forecast < `-5`.

### Exit
- Close LONG when combined forecast <= `+1`.
- Close SHORT when combined forecast >= `-1`.
- Flip only when the opposite entry threshold is met on a later closed bar.

### Stop Loss
- Emergency stop: `3.0 * ATR(20, D1)`.
- Optional P3 variants: `2.0`, `2.5`, `3.5` ATR.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD per trade.
- Live: `RISK_PERCENT = 0.5%`.
- Size from emergency stop distance. One position per symbol/magic.

### Zusaetzliche Filter
- Require at least `3` valid component families before opening a trade.
- Skip carry/relative-carry components when deterministic DWX carry input is unavailable; do not block the rest of the ensemble.
- Skip new entries when current spread exceeds `2 * MedianSpread(20D)`.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|-------------|
| R1 Source-Link | PASS | Named author, exact live-system source, and linked open-source rule implementations. |
| R2 Mechanical | PASS | Component list, weights, cost exclusion, combined forecast threshold, exits, and stop are deterministic. |
| R3 DWX-testbar | PASS | Most components use DWX OHLC/spread data; carry legs require deterministic swap/rate input and may be skipped if unavailable. |
| R4 No ML | PASS | Fixed handcrafted weights and fixed formulas; no online learning, adaptive PnL parameters, grid, or martingale. |

## Build Notes
- Local EA card copy is URL-sanitized for build checks; the APPROVED source card was not modified.
