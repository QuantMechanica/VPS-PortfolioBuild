---
ea_id: QM5_10199
slug: tv-vsa-absorb-fx
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
target_symbols: [EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, GER40.DWX, NDX.DWX]
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/mean-reversion]]"
  - "[[concepts/volume-spike]]"
indicators:
  - "[[indicators/atr]]"
  - "[[indicators/volume]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 80
last_updated: 2026-05-19
g0_approval_reasoning: "R1 exact TradingView URL/author cited; R2 deterministic VSA absorption entry/exit with SL/TP and ~80 trades/year/symbol; R3 OHLCV proxy logic portable to DWX FX/gold/index CFDs; R4 fixed rules, no ML/grid/martingale, one-position-per-magic compatible."
---

# TradingView VSA Absorption Proxy FX

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script `VSA with Absorption Proxy for Holmes and Bookmap Style`, author handle `uzair2join`, published 2026-02-10, https://www.tradingview.com/script/wPuAT5a1-VSA-with-Absorption-Proxy-for-Holmes-and-Bookmap-Style/

## Mechanik

### Entry
Use M5/M15 bars during liquid sessions.

- Compute directional volume proxy: `delta_proxy = volume * (close - open) / max(high - low, tick_size)`.
- Compute volume SMA(20) and ATR(14).
- Long absorption signal:
  - Volume > SMA(volume, 20) * volume_multiplier.
  - Bar range > ATR(14) * range_multiplier.
  - Candle is bullish: close > open.
  - `delta_proxy` turns positive after being negative on the prior bar.
- Short rejection signal is the mirror:
  - Volume and range conditions pass.
  - Candle is bearish: close < open.
  - `delta_proxy` turns negative after being positive on the prior bar.
- One open position maximum; ignore new signals while in a position.

### Exit
- Source exit is fixed risk/reward.
- Long SL = entry low adjusted by riskPct default 1%; TP = risk distance * 3.5.
- Short SL = entry high adjusted by riskPct default 1%; TP = risk distance * 3.5.

### Stop Loss
Use source fixed-percent stop, capped by a V5 sanity bound of 3.0 * ATR(14) where the percent stop is wider.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per magic number.

### Zusatzliche Filter
- Target symbols: EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, GER40.DWX, NDX.DWX.
- Session filter: London/NY overlap for FX; US regular/opening hours for index CFDs and gold.
- Do not use real bid/ask delta; this card intentionally freezes the source's OHLCV proxy.
- Spread must be <= 15% of stop distance.

## Concepts (was ist das fur eine Strategie)
- [[concepts/mean-reversion]] - fades climactic absorption/rejection bars.
- [[concepts/volume-spike]] - requires abnormal volume and wide range versus ATR.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `uzair2join` are cited. |
| R2 Mechanical | PASS | Source gives formula, high-volume/wide-range conditions, directional entries, stop, and target. |
| R3 Data Available | PASS | Uses OHLCV proxy data available on target DWX FX, gold, and index CFDs. |
| R4 ML Forbidden | PASS | Fixed OHLCV rules, no ML, no grid, no martingale, and one-position-per-magic compatible. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from TradingView script page after replacing QM5_10190, which was auto-rejected for missing `target_symbols`.

## Verwandte Strategien
- [[strategies/QM5_10191_tv-gold-vol2bar]] - volume-spike family, but this card uses reversal/absorption delta proxy.

## Lessons Learned (wahrend Pipeline-Lauf)
- 2026-05-19: Farm G0 tooling enforces `target_symbols`; future draft cards should include it in frontmatter even though the visible wiki template omits it.
