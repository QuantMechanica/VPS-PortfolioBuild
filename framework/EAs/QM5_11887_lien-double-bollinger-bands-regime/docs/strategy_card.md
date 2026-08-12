---
ea_id: QM5_11887
slug: lien-double-bollinger-bands-regime
source_id: b840c053-5cd2-5e17-b25b-d495e73a33ab
source_citation: "Lien, K. (2011), Battle Tested Forex Trading Strategies — BKForex Advisor educational session. URL: local PDF archive."
title: "Lien Double Bollinger Bands regime classifier + Uptrend/Downtrend Zone pullback entry (H4 trend-follow)"
edge_type: trend
period: H4
target_symbols:
  - EURUSD.DWX
  - GBPUSD.DWX
  - USDJPY.DWX
  - USDCAD.DWX
  - USDCHF.DWX
  - AUDUSD.DWX
  - NZDUSD.DWX
  - EURJPY.DWX
  - GBPJPY.DWX
  - AUDJPY.DWX
risk_mode_backtest: RISK_FIXED
risk_fixed: 1000
risk_mode_live: RISK_PERCENT
risk_percent: 0.5
expected_trades_per_year_per_symbol: 28
status: cards_ready
strategy_params:
  bb_period: 20
  bb_outer_stddev: 2.0
  bb_inner_stddev: 1.0
  range_zone_dwell_bars_min: 6
  trail_band: "inner_opposite"
  sl_pips_behind_zone_break: 15
g0_status: APPROVED
g0_approval_reasoning: "R1 PASS single source_id/citation; R2 PASS deterministic H4 Double-BB range-to-trend entry and range re-entry/trailing exit with plausible ~28 trades/year/symbol across liquid FX; R3 PASS DWX forex symbols listed; R4 PASS deterministic ML-free 1-position-compatible logic."
last_updated: 2026-05-24
r1_track_record: PASS
r1_reasoning: "Single source_id (b840c053) with Kathy Lien 2011 book citation — one canonical lineage anchor."
r2_mechanical: PASS
r2_reasoning: "Fully mechanical: BB(20,1σ/2σ) zone classification, ≥6-bar Range Zone dwell count, trend-zone crossover entry at next open, Range Zone re-entry exit, pips-behind-zone-boundary SL."
r3_data_available: PASS
r3_reasoning: "Ten DWX forex major pairs listed; Lien's own source covers EURUSD/GBPUSD/USDCAD/USDCHF/AUDUSD/NZDUSD on H4."
r4_ml_forbidden: PASS
r4_reasoning: "No ML; Bollinger Bands are deterministic price-history computations; trailing stop uses opposite BB line (price-derived); 1-position-per-magic compatible."
---

## Strategy

A regime-classifier trend-follow setup traded on the **H4** timeframe. Two
Bollinger Bands are plotted on the same chart: `BB(20, 2σ)` outer envelope
and `BB(20, 1σ)` inner envelope. Price action lives in one of three regimes:

- **Uptrend Zone**: close > BB(20, 1σ) upper band
- **Range Zone**: BB(20, 1σ) lower band <= close <= BB(20, 1σ) upper band
- **Downtrend Zone**: close < BB(20, 1σ) lower band

Entry on a new-trend transition: after at least 6 H4 bars of consecutive
Range-Zone closes, the first H4 close that crosses into Uptrend Zone (long)
or Downtrend Zone (short) is the entry signal.

## Entry Rules

**Long entry:**
- The prior 6 or more consecutive H4 bars closed inside the Range Zone.
- Current H4 bar closes above the inner upper band and below the outer upper band.
- Enter market at next H4 open.

**Short entry:** mirror — six bars of Range-Zone closes followed by an H4
close below the inner lower band and above the outer lower band.

## Exit Rules

- Primary exit: H4 close re-enters the Range Zone.
- No fixed take-profit; the inner-band re-entry is the trend-exhaustion exit.

## Risk and Sizing

- SL: 15 pips behind the crossed inner-band boundary.
- Backtest sizing: RISK_FIXED = $1000 per trade.
- Live sizing: RISK_PERCENT = 0.5% of equity.

## Source Citation and Target Symbols

Kathy Lien, *Battle Tested Forex Trading Strategies* (2011), Double
Bollinger Bands chapter slides 20–33. The approved ten-symbol DWX FX universe
is listed in frontmatter.
