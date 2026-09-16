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

## Source
- Source: [[sources/rob-carver-blog]]
- Primary URL: https://qoppac.blogspot.com/2020/12/dynamic-trend-following.html
- Author: Rob Carver. The post describes the Leveraged Trading starter system as a 16/64 moving-average binary rule with a 0.5 annual-standard-deviation stop, then tests a dynamic-vol-control variant.

## Mechanics

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

### Additional filters
- Require at least `100` D1 bars before trading.
- Spread cap: skip new entries when spread exceeds `2 * MedianSpread(20D)`.
- Recalculate only on closed D1 bars; no intraday stop movement except broker-side emergency stop sync.

## Concepts
- [[concepts/trend-following]] - primary
- [[concepts/dynamic-volatility-control]] - primary
- [[concepts/discrete-trend-system]] - secondary

## R1-R4 assessment
| Criterion | Status | Rationale |
|-----------|--------|------------|
| R1 Source-Link | PASS | Named author and exact qoppac URL for the starter-system mechanics and dynamic-vol variant. |
| R2 Mechanical | PASS | MA crossover entry, same-direction whipsaw guard, trailing stop, and dynamic-vol sizing are deterministic. |
| R3 DWX-testbar | PASS | Uses only daily OHLC-derived moving averages and volatility; portable to DWX FX, indices, metals, and oil. |
| R4 No ML | PASS | Fixed lookbacks and fixed volatility formula; no ML, online learning, martingale, or unbounded grid. |

## R3 - T6 Live-Promotion-Caveat
N/A - proposed universe uses broker-routable DWX symbols only. SP500.DWX is not required.

## Pipeline history
- G0: 2026-05-18 - drafted from Rob Carver blog fourth batch, PENDING.

## Related strategies
- [[strategies/QM5_1066_carver-ewmac-trend]] - continuous EWMAC trend cousin.
- [[strategies/QM5_1228_carver-volatten-ewmac]] - trend rule with volatility attenuation rather than discrete dynamic-vol management.

## Lessons Learned (wahrend Pipeline-Lauf)
- (none yet)

---

*Node maintenance: update `pipeline_phase` + `last_updated` on every pipeline-phase change. On FAIL: `pipeline_phase: DEAD` + a lessons-learned entry.*

## Approved Amendment (2026-09-14) — DSR Single Configuration

- Authority: `OWNER-DEC-Q08-CONTEXT-REPAIR-V2-20260914`, OWNER receipt `3415f6c0…` (YES: "ABC & D freigegeben zur Umsetzung").
- This EA was never part of a sealed factory search (no DL-089 ledger); it carries exactly one configuration: the card defaults overlaid by the set file below. No optimisation search took place, research_trial_count is 0.
- This declaration locks the exact NDX.DWX/D1 configuration used by Q08 (set file `QM5_1230_carver-dynvol-mav_NDX.DWX_D1_backtest.set`). It changes no strategy mechanics, threshold, or stored verdict.

```qm-dsr-single-configuration
{
  "complete": true,
  "ea_id": "QM5_1230",
  "locked_parameters": {
    "PORTFOLIO_WEIGHT": "1",
    "RISK_FIXED": "1000",
    "RISK_PERCENT": "0",
    "qm_ea_id": "1230",
    "qm_filter_news_enabled": "1",
    "qm_filter_news_mode": "3",
    "qm_filter_regime_bear_return_pct": "2.0",
    "qm_filter_regime_bull_return_pct": "2.0",
    "qm_filter_regime_enabled": "0",
    "qm_filter_regime_lookback_bars": "100",
    "qm_filter_volatility_atr_period": "14",
    "qm_filter_volatility_compression_ratio": "0.75",
    "qm_filter_volatility_enabled": "0",
    "qm_filter_volatility_expansion_ratio": "1.25",
    "qm_filter_volatility_lookback_bars": "50",
    "qm_friday_close_enabled": "true",
    "qm_friday_close_hour_broker": "21",
    "qm_magic_slot_offset": "3",
    "qm_news_compliance": "QM_NEWS_COMPLIANCE_NONE",
    "qm_news_min_impact": "high",
    "qm_news_mode_legacy": "QM_NEWS_OFF",
    "qm_news_stale_max_hours": "336",
    "qm_news_temporal": "QM_NEWS_TEMPORAL_OFF",
    "qm_rng_seed": "42",
    "qm_stress_reject_probability": "0.0",
    "strategy_cooldown_bars": "20",
    "strategy_daily_vol_period": "25",
    "strategy_derisk_step": "0.10",
    "strategy_dynamic_derisk": "true",
    "strategy_exit_on_ma_flip": "true",
    "strategy_fast_ema_period": "16",
    "strategy_min_d1_bars": "100",
    "strategy_slow_ema_period": "64",
    "strategy_spread_cap_points": "0",
    "strategy_stop_gap_vol_mult": "8.0"
  },
  "no_optimization_search": true,
  "research_trial_count": 0,
  "schema": "qm.dsr-single-configuration-declaration/v1",
  "spec_sha256": "95168464a47e60cf0e0ec73b849dc3c451b885d699960466852acd79135ac465",
  "symbol": "NDX.DWX",
  "timeframe": "D1"
}
```
