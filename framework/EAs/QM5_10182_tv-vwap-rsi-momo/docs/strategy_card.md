---
ea_id: QM5_10182
slug: tv-vwap-rsi-momo
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/momentum]]"
  - "[[concepts/trend-following]]"
indicators:
  - "[[indicators/vwap]]"
  - "[[indicators/rsi]]"
  - "[[indicators/sma]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 120
last_updated: 2026-05-19
g0_approval_reasoning: "R1 exact TradingView URL/author cited; R2 deterministic VWAP-RSI/SMA entries, exhaustion exits, stops and ~120 trades/year/symbol; R3 portable to DWX index/gold/FX CFDs; R4 no ML/grid/martingale/pyramiding."
---

# TradingView VWAP RSI Momentum

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script `Tideflow VWAP-RSI [Momentum Strategy]`, author handle `wielkieef`, published 2026-05-19, https://www.tradingview.com/script/G9OpWCtf-Tideflow-VWAP-RSI-Momentum-Strategy/

## Mechanik

### Entry
Use M30 or H1 bars, long and short.

- Compute rolling 20-bar VWAP from typical price weighted by tick volume.
- Compute RSI(14) on the rolling VWAP series and smooth it with EMA(3).
- Compute SMA_fast(50) and SMA_slow(100).
- Long trend filter: SMA_fast > SMA_slow and close > SMA_fast.
- Short trend filter: SMA_fast < SMA_slow and close < SMA_fast.
- Long entry can trigger from any one source pattern while long trend filter is true:
  - Extreme reversal: VWAP-RSI was below 35 and turns upward.
  - Color flip: VWAP-RSI crosses above 50.
  - Shallow dip reentry: VWAP-RSI previously reached 75, dipped to 70 or lower within the lookback window, and turns upward again.
- Short entry mirrors the three triggers using 65, 50, 25, and 30 zones.
- One open position maximum.

### Exit
- Long exhaustion exit: VWAP-RSI reaches >= 65 and then turns downward.
- Short exhaustion exit: VWAP-RSI reaches <= 35 and then turns upward.
- Hard stop: 4.0% adverse move from entry as source default; baseline also caps risk at 2.0 ATR(14) if ATR cap is tighter.
- Time stop: close after 64 bars if neither exhaustion nor stop was reached.

### Stop Loss
- Static percentage stop from source, frozen at 4.0%.
- For DWX non-crypto ports, use min(4.0% price stop, 2.0 ATR(14)) to avoid unbounded index/FX stop distance.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per magic number.

### Zusatzliche Filter
- Source targets crypto majors; DWX port uses NDX.DWX, WS30.DWX, GER40.DWX, XAUUSD.DWX, and EURUSD.DWX.
- Spread must be <= 15% of stop distance.
- No pyramiding, no breakeven move, no trailing stop.

## Concepts (was ist das fur eine Strategie)
- [[concepts/momentum]] - VWAP-weighted RSI state changes drive entries and exhaustion exits.
- [[concepts/trend-following]] - SMA filter constrains trades to trend direction.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `wielkieef` are cited. |
| R2 Mechanical | PASS | Source specifies VWAP-RSI construction, three deterministic entry triggers, SMA trend filter, exhaustion exit, and static stop. |
| R3 Data Available | PASS | Uses OHLC, tick volume, VWAP, RSI, and SMA primitives; crypto source can be ported to DWX index, gold, and FX CFDs. |
| R4 ML Forbidden | PASS | Source states no pyramiding and uses fixed-rule indicators, static stop, and confirmed bars. No ML, grid, martingale, or live performance-adaptive parameters. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from TradingView script page.

## Verwandte Strategien
- [[strategies/QM5_10174_tv-rsi-atr-3tp]] - same author but different RSI/ATR trend-continuation mechanic.

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
