---
ea_id: QM5_10708
slug: tv-crypto-ils
type: strategy
source_id: d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
source_citation: "TradingView script `Crypto Institutional Liquidity Sweep Strategy`, author handle `Danish7421`, open-source strategy, published 2026-02-04, https://www.tradingview.com/script/ZhJzjmAk-Crypto-Institutional-Liquidity-Sweep-Strategy/"
sources:
  - "[[sources/tradingview-mechanical-strategy-scripts]]"
concepts:
  - "[[concepts/liquidity-sweep]]"
  - "[[concepts/trend-following]]"
  - "[[concepts/reversal-confirmation]]"
indicators:
  - "[[indicators/ema]]"
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
r1_reasoning: "Single source_id present; exact TradingView URL and author handle Danish7421 provide unambiguous lineage."
r2_reasoning: "EMA(200) bias, pivot sweep/reclaim, reversal-candle filter, ATR stop, fixed 2R target, and 48-bar time exit are all deterministic."
r3_reasoning: "Crypto-origin OHLC logic ports directly to DWX index, metal, and FX CFDs (NDX, GER40, XAUUSD, EURUSD, GBPUSD) without requiring unavailable features."
r4_reasoning: "Fixed indicator and price-action rules only; no ML, no grid, no martingale, single position per magic."
pipeline_phase: G0
expected_trades_per_year_per_symbol: 80
last_updated: 2026-05-22
g0_approval_reasoning: "R1 PASS exact TradingView URL and author handle; R2 PASS mechanical EMA bias, pivot sweep/reclaim, reversal candle, ATR stop/2R/time exit with plausible 80 trades/year/symbol; R3 PASS OHLC-derived crypto logic portable to DWX index/gold/FX CFDs; R4 PASS fixed non-ML one-position logic."
---

# TradingView Crypto Institutional Liquidity Sweep

## Quelle
- Source: [[sources/tradingview-mechanical-strategy-scripts]]
- Page / Timestamp: TradingView script `Crypto Institutional Liquidity Sweep Strategy`, author handle `Danish7421`, open-source strategy, published 2026-02-04, https://www.tradingview.com/script/ZhJzjmAk-Crypto-Institutional-Liquidity-Sweep-Strategy/

## Mechanik

### Entry
Use H1 bars for the first DWX port and trade both directions.

- Compute EMA(200).
- Long bias only when close is above EMA(200), with optional buffer disabled for baseline.
- Short bias only when close is below EMA(200), with optional buffer disabled for baseline.
- Detect pivot swing highs/lows using a configurable pivot length.
- Long trigger: price pierces a recent pivot low, then reclaims the level with a bullish reversal candle.
- Short trigger: price pierces a recent pivot high, then reclaims the level with a bearish reversal candle.
- Reversal candle filter: long candle closes bullish and in the upper 40% of its range; short candle closes bearish and in the lower 40% of its range.
- Secondary filter baseline: require linear-regression slope over 20 bars to align with the EMA bias.

### Exit
- Static take profit at 2.0R.
- Static stop remains fixed after entry.
- Time stop after 48 H1 bars if neither target nor stop is reached.

### Stop Loss
- Stop distance is ATR(14) multiplied by the source volatility setting; baseline uses 1.5 * ATR(14).
- Skip trades with stop distance greater than 3.5 * ATR(14) or spread greater than 15% of stop distance.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per magic number.

### Zusatzliche Filter
- Source is crypto-specific; port first to NDX.DWX, GER40.DWX, XAUUSD.DWX, EURUSD.DWX, and GBPUSD.DWX.
- Disable any volume-only confirmation for the first pass unless DWX tick-volume behavior is explicitly tested.

## Concepts (was ist das fur eine Strategie)
- [[concepts/liquidity-sweep]] - trades stop-run reclaims at recent structural pivots.
- [[concepts/trend-following]] - only fades sweeps in the EMA(200) trend direction.
- [[concepts/reversal-confirmation]] - requires candle location and body direction before entry.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `Danish7421` are cited. |
| R2 Mechanical | PASS | Source specifies EMA bias, pivot sweeps, reclaim/reversal candle filters, ATR stop, and fixed 1:2 exits. |
| R3 Data Available | UNKNOWN | Crypto-origin logic must be ported to DWX index/gold/FX CFDs; required inputs are OHLC-derived. |
| R4 ML Forbidden | PASS | Fixed indicator and price-action rules, no ML, no grid, no martingale, one-position compatible. |

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING, drafted from TradingView mechanical strategy source.

## Verwandte Strategien
- [[strategies/QM5_10705_tv-liq-trap]] - related PDH/PDL trap reversal with ATR stop.
- [[strategies/QM5_10692_tv-ls-ms]] - related liquidity sweep plus market-structure break.

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
