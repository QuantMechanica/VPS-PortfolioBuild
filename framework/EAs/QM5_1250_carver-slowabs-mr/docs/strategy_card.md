---
ea_id: QM5_1250
slug: carver-slowabs-mr
type: strategy
source_id: 2a380bee-1ec4-50d1-a348-b10fac642c7a
sources:
  - "[[sources/rob-carver-blog]]"
concepts:
  - "[[concepts/mean-reversion]]"
  - "[[concepts/normalised-price]]"
  - "[[concepts/volatility-normalisation]]"
indicators:
  - "[[indicators/normalised-price]]"
  - "[[indicators/ewma-volatility]]"
  - "[[indicators/atr-stop]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-19
expected_trades_per_year_per_symbol: 6
g0_approval_reasoning: "Carver qoppac 2025/2017 very-slow vol-normalised mean reversion; mechanical z-score thresholds + ATR + time stop; portable to DWX FX/idx/metals/oil; R1-R4 PASS"
---

# QM5_1250 Carver Very Slow Absolute Mean Reversion

## Quelle
- Source: [[sources/rob-carver-blog]]
- Primary URL: qoppac.blogspot.com/2025/03/very-slow-mean-reversion-and-some.html
- Supplemental URL: qoppac.blogspot.com/2017/06/some-more-trading-rules.html
- Author: Rob Carver. The 2025 post revisits very slow mean reversion and explicitly warns that the original test had problems; the 2017 post supplies the normalised-price machinery used by Carver's mean-reversion family.

## Mechanik

Contrarian rule on very slow volatility-normalised price displacement. The EA sells markets that have moved far above their long-run normalised level and buys markets that have moved far below it, with deliberately slow turnover.

### Entry
- On each closed D1 bar:
  - Compute daily return normalised by 25-day exponentially weighted volatility.
  - Build `normalised_price = cumulative_sum(normalised_return)`.
  - Compute `anchor = SMA(normalised_price, LookbackDays)`.
  - Default `LookbackDays = 1000`.
  - Compute `z = (normalised_price - anchor) / RollingStd(normalised_price - anchor, LookbackDays)`.
- LONG if `z < -EntryZ`.
- SHORT if `z > +EntryZ`.
- Defaults: `EntryZ = 1.5`, `ExitZ = 0.25`.

### Exit
- Close LONG when `z >= -ExitZ`.
- Close SHORT when `z <= +ExitZ`.
- Flip only after flat or on a later D1 close with opposite entry threshold.

### Stop Loss
- Emergency stop: `3.0 * ATR(20, D1)`.
- Time stop: close any position open longer than `180` trading days.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD per trade.
- Live: `RISK_PERCENT = 0.5%`.
- Size from emergency stop distance. One position per symbol/magic.

### Zusätzliche Filter
- Require at least `LookbackDays + 250` D1 bars before trading.
- Skip new entries when spread exceeds `2 * MedianSpread(20D)`.
- Default portfolio universe: major FX, index, gold, and oil DWX CFDs; no cross-symbol slotting required.

## Concepts
- [[concepts/mean-reversion]] - primary
- [[concepts/normalised-price]] - primary
- [[concepts/volatility-normalisation]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Named author and exact qoppac URLs for the slow mean-reversion discussion and normalised-price method. |
| R2 Mechanical | PASS | Normalised price, slow anchor, z-score thresholds, exits, stop, and time stop are deterministic. |
| R3 DWX-testbar | PASS | Uses only DWX daily OHLC-derived returns and ATR; portable to FX, indices, metals, and oil CFDs. |
| R4 No ML | PASS | Fixed thresholds/lookbacks, one position per magic, no ML, online learning, grid, or martingale. |

## R3 - T6 Live-Promotion-Caveat
N/A - proposed universe uses broker-routable DWX symbols only. SP500.DWX is not required.

## Pipeline-Verlauf
- G0: 2026-05-18 - drafted from Rob Carver blog fifth batch, PENDING. Carver's own 2025 post flags weak/problematic evidence; pipeline should treat this as an exploratory wide-net candidate.

## Verwandte Strategien
- [[strategies/QM5_1209_carver-mrinasset]] - within-asset cross-sectional mean-reversion cousin.
- [[strategies/QM5_1220_carver-mrwings]] - EWMAC mean reversion only at extremes.

## Lessons Learned (wahrend Pipeline-Lauf)
- (noch keine)
