---
ea_id: QM5_11903
slug: lawler-supply-demand-zones-20-dma-h1
source_id: 6e4b9c5a-2f78-5d36-a917-c8b3d5e4f1a2
source_citation: "Jasper Lawler, 'Price Action Trading Strategy: Supply & Demand Zones' (FlowBank, 28 June 2021). URL https://www.flowbank.com/en/research. Wyckoff market structure references R. Wyckoff's 1930s work (canonical TA literature)"
title: "Lawler Supply/Demand Zone Retest + 20-DMA Trend Filter H1"
edge_type: zone_retest_with_trend_filter
period: H1
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, USDCAD.DWX, USDCHF.DWX, AUDUSD.DWX, NZDUSD.DWX, EURJPY.DWX, GBPJPY.DWX, AUDJPY.DWX]
risk_mode_backtest: RISK_FIXED
risk_fixed: 1000
risk_mode_live: RISK_PERCENT
risk_percent: 0.5
expected_trades_per_year_per_symbol: 30
status: cards_ready
r1_verdict: PARTIAL
r1_note: "Jasper Lawler is FlowBank head of research, ex-CMC Markets; Wyckoff base concept is canonical"
r2_verdict: UNKNOWN
r3_verdict: UNKNOWN
r4_verdict: UNKNOWN
strategy_params:
  timeframe: H1
  dma_period: 20
  zone_base_min_candles: 1
  zone_base_max_candles: 10
  erc_atr_multiple: 2.0
  atr_period: 14
  zone_fresh_required: true
  entry_method: limit_at_zone_edge
  zone_validity_bars: 240
  target_rr: 3.0
r1_track_record: PASS
r1_reasoning: "Single source_id with FlowBank/Lawler URL citation satisfies R1's one-source-per-card requirement."
r2_mechanical: PASS
r2_reasoning: "Base detection (1-10 narrow bars vs ATR), ERC breakout (2×ATR), SMA20 slope filter, freshness filter, limit-order entry at zone edge, SL at zone extreme, 3:1 RR TP, and DMA-invalidation exit are all mechanically defined."
r3_data_available: PASS
r3_reasoning: "DWX forex majors are the target universe and are directly testable in the MT5 pipeline on H1."
r4_ml_forbidden: PASS
r4_reasoning: "Deterministic zone-detection rules based solely on price and ATR, no ML or PnL-adaptive logic, 1-position-per-magic compatible."
card_body_incomplete: true
card_body_missing: "source_citation"
g0_status: APPROVED
g0_approval_reasoning: "R1 PASS single source_id with FlowBank Lawler attribution; R2 PASS mechanical H1 base/ERC zone retest entries and exits with plausible >=2 trades/year/symbol despite declared 30/year needing validation; R3 PASS forex DWX majors testable; R4 PASS deterministic ML-free single-position-compatible rules"
last_updated: 2026-05-25
---

# QM5_11903 — Lawler Supply/Demand Zone Retest + 20-DMA Filter (H1)

## Setup

Wyckoff-inspired zone retest system. When a strong directional move
("Extended Range Candle" — ATR-multiple of >= 2×) breaks out of a
narrow consolidation base (1-10 H1 candles), the base price range
becomes a future Supply Zone (for downside breakouts) or Demand Zone
(for upside breakouts). The 20-period H1 DMA acts as a trend filter:
only trade demand-zone retests when the DMA is sloping up; only trade
supply-zone retests when the DMA is sloping down.

The expected edge: institutional accumulation/distribution zones leave
"unfilled order" footprints that price tends to retest before continuing
the dominant trend. Trading the retest gives a defined entry with a
tight invalidation level (the far side of the zone).

## Entry Rules

Detected on H1 closed bars:

1. **Base detection**: Identify a sequence of 1-10 consecutive H1 bars
   where the high-low range of each bar is less than `1.0 × ATR(14)`
   at that bar's time. This is the "base" / consolidation.
2. **Breakout candle (ERC)**: The bar immediately following the base
   must have a range >= `2.0 × ATR(14)` at base-end, AND must close
   beyond the base's high (bullish breakout, marks Demand Zone) or
   below the base's low (bearish breakout, marks Supply Zone).
3. **Zone definition**:
   - Demand Zone: from `base_low` to `base_high` (the original base
     range, which becomes future support).
   - Supply Zone: same range, but reframed as future resistance.
4. **Trend filter for long entry (demand-zone retest)**: 20-period SMA
   on H1 must satisfy `SMA20[now] > SMA20[10 bars ago]` (positive slope
   over last 10 bars) at the time of zone formation.
5. **Trend filter for short entry**: `SMA20[now] < SMA20[10 bars ago]`
   at the time of zone formation.
6. **Zone retest entry (long)**: Place a buy-limit pending order at
   `demand_zone_high - 1 pip` (the upper edge of the demand zone — the
   first level price re-enters). Order valid for 240 H1 bars (10 days).
7. **Zone retest entry (short)**: Sell-limit at `supply_zone_low + 1 pip`.
8. **Freshness filter**: If price has already tested the zone (entered
   the zone range) between the breakout and the current bar, the zone
   is "used" and the limit order is canceled. Only fresh zones trigger.

## Exit Rules

- **Stop loss (long)**: Below the demand zone's low minus 5 pips.
  Mirror for shorts above supply zone high plus 5 pips.
- **Take profit (primary)**: 3.0 × initial pip-risk in trade direction
  (fixed 3:1 reward-to-risk ratio, per source recommendation).
- **Alternative target**: The next visible H1 ZigZag(12,10,3) pivot in
  the trade direction, IF closer than the 3:1 target. Take whichever
  is closer.
- **Trend-invalidation exit**: Close immediately if the 20-DMA slope
  reverses (long trade: SMA20[now] < SMA20[10 bars ago]).
- **Hard timeout**: Close at H1 bar 480 (20 days) after entry.
- **Risk**: backtest RISK_FIXED `risk_fixed = 1000`; live RISK_PERCENT
  `risk_percent = 0.5`.

## Universe

target_symbols: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, USDCAD.DWX, USDCHF.DWX,
AUDUSD.DWX, NZDUSD.DWX, EURJPY.DWX, GBPJPY.DWX, AUDJPY.DWX

H1 forex majors — Lawler explicitly says the strategy is "market-neutral"
and applies to forex, commodities, indices, CFDs. Forex majors basket is
the natural QM application.

## Source

source_citation: Jasper Lawler, "Price Action Trading Strategy: Supply &
Demand Zones" published on FlowBank.com (28 June 2021), URL
https://www.flowbank.com/en/research. The underlying
S/D zone concept derives from Richard Wyckoff's 1930s market-structure
work (Accumulation/Markup/Distribution/Markdown phases) — canonical TA
literature. The specific "S/D with 20 DMA" combination at the end of
the article is the original contribution from this source.
