---
ea_id: QM5_1230
slug: carver-dynvol-mav
type: strategy
source_id: 2a380bee-1ec4-50d1-a348-b10fac642c7a
sources:
  - "[[sources/rob-carver-blog]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/dynamic-volatility-control]]"
  - "[[concepts/discrete-trend-system]]"
indicators:
  - "[[indicators/moving-average-cross]]"
  - "[[indicators/volatility-sizing]]"
  - "[[indicators/trailing-stop]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id present (rob-carver-blog) with named author Rob Carver and exact qoppac URL for the dynamic trend-following post."
r2_mechanical: PASS
r2_reasoning: "MA cross entry, trailing high/low-water stop, cooldown-bar reentry guard, and dynamic-vol position adjustment are all deterministic."
r3_data_available: PASS
r3_reasoning: "Uses D1 OHLC-derived moving averages and volatility only; portable to DWX FX, indices, metals, and oil CFDs without SP500.DWX."
r4_ml_forbidden: PASS
r4_reasoning: "Dynamic position sizing adjusts on price volatility history (not PnL); fixed MA periods, fixed stop formula, no ML, no grid, no martingale."
pipeline_phase: G0
last_updated: 2026-05-19
expected_trades_per_year_per_symbol: 12
g0_approval_reasoning: "R1 PASS Rob Carver named + qoppac 2020-12 dynamic-trend-following URL (Leveraged Trading starter system + dyn-vol variant); R2 PASS EMA(16)/EMA(64) MA-cross binary signal + trailing high/low-water + CooldownBars=20 reentry guard + StopGap=8*daily_vol deterministic; R3 PASS D1 portable to DWX FX/indi"
---

# QM5_1230 Carver Dynamic-Vol Starter MAV

## Quelle
- Source: [[sources/rob-carver-blog]]
- Primary URL: https://qoppac.blogspot.com/2020/12/dynamic-trend-following.html
- Author: Rob Carver. The post describes the Leveraged Trading starter system as a 16/64 moving-average binary rule with a 0.5 annual-standard-deviation stop, then tests a dynamic-vol-control variant.

## Mechanik

Discrete trend-following system. Unlike continuous EWMAC forecast trading, this opens a binary long/short position on a moving-average signal and then manages the open trade with a trailing stop and dynamic volatility position adjustment.

### Entry
- On each closed D1 bar:
  - `fast_ma = EMA(Close, 16)`.
  - `slow_ma = EMA(Close, 64)`.
  - `raw_signal = +1` if `fast_ma > slow_ma`, `-1` if `fast_ma < slow_ma`, else `0`.
- If flat and `raw_signal != 0`, open in the signal direction.
- Do not immediately reopen in the same direction after a stop-out; require either an opposite signal first or `CooldownBars=20`.

### Exit
- Maintain highest close since long entry or lowest close since short entry.
- Close LONG when `Close < high_water_mark - StopGap`.
- Close SHORT when `Close > low_water_mark + StopGap`.
- Optional conservative exit: close if the moving-average signal flips opposite before stop is hit.

### Stop Loss
- `daily_vol = StdDev(daily close-to-close price changes, 25)`.
- Dynamic-vol preferred variant:
  - `StopGap = 8 * current_daily_vol`, equivalent to Carver's 0.5 annual standard deviation using daily vol.
  - Position size is adjusted while open by `initial_vol / current_vol`.
- P3 comparison variants:
  - Static-vol: use `initial_daily_vol` for both position and stop gap.
  - Dynamic stop disabled by default because Carver reports a large Sharpe penalty for the aggressive dynamic-stop version.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD per trade.
- Live: `RISK_PERCENT = 0.5%`.
- Size from `StopGap`, then apply dynamic-vol multiplier while position is open.
- One position per symbol/magic.

### Zusätzliche Filter
- Require at least `100` D1 bars before trading.
- Spread cap: skip new entries when spread exceeds `2 * MedianSpread(20D)`.
- Recalculate only on closed D1 bars; no intraday stop movement except broker-side emergency stop sync.

## Concepts
- [[concepts/trend-following]] - primary
- [[concepts/dynamic-volatility-control]] - primary
- [[concepts/discrete-trend-system]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Named author and exact qoppac URL for the starter-system mechanics and dynamic-vol variant. |
| R2 Mechanical | PASS | MA crossover entry, same-direction whipsaw guard, trailing stop, and dynamic-vol sizing are deterministic. |
| R3 DWX-testbar | PASS | Uses only daily OHLC-derived moving averages and volatility; portable to DWX FX, indices, metals, and oil. |
| R4 No ML | PASS | Fixed lookbacks and fixed volatility formula; no ML, online learning, martingale, or unbounded grid. |

## R3 - T6 Live-Promotion-Caveat
N/A - proposed universe uses broker-routable DWX symbols only. SP500.DWX is not required.

## Pipeline-Verlauf
- G0: 2026-05-18 - drafted from Rob Carver blog fourth batch, PENDING.

## Verwandte Strategien
- [[strategies/QM5_1066_carver-ewmac-trend]] - continuous EWMAC trend cousin.
- [[strategies/QM5_1228_carver-volatten-ewmac]] - trend rule with volatility attenuation rather than discrete dynamic-vol management.

## Lessons Learned (wahrend Pipeline-Lauf)
- (noch keine)

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Anderung `pipeline_phase` aktualisieren + `last_updated`.*
