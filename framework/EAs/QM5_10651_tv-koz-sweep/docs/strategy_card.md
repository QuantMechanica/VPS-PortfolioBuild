---
ea_id: QM5_10651
slug: tv-koz-sweep
type: strategy
source_id: d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
sources:
  - "[[sources/tradingview-mechanical-strategy-scripts]]"
concepts:
  - "[[concepts/liquidity-sweep]]"
  - "[[concepts/smc-ict]]"
  - "[[concepts/session-filter]]"
indicators: []
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id (d11962d5) with exact TradingView URL and author handle M_LOADING cited."
r2_mechanical: PASS
r2_reasoning: "Mechanical: M15 swing-structure bias, M5 sweep of PDL/PDH or swing level, OB/FVG confluence, rejection-candle entry trigger, sweep-wick stop, TP1/TP2 exits; all rules specified."
r3_data_available: PASS
r3_reasoning: "NDX.DWX, WS30.DWX, XAUUSD.DWX, and EURUSD.DWX are live-tradable DWX instruments using OHLC structure levels."
r4_ml_forbidden: PASS
r4_reasoning: "No ML, no grid, no martingale; baseline enforces full-close at TP1 to preserve one-position-per-magic compliance."
pipeline_phase: G0
expected_trades_per_year_per_symbol: 120
last_updated: 2026-05-22
g0_approval_reasoning: "R1 TradingView URL cited; R2 mechanical sweep/bias/session/exit rules with defaults, ~120 trades/year/symbol; R3 OHLC structure portable to DWX CFDs; R4 no ML/grid/martingale, use one-position-compatible full-close variant."
---

# TradingView KOZ SMC ICT Sweep

## Quelle
- Source: [[sources/tradingview-mechanical-strategy-scripts]]
- Page / Timestamp: TradingView script `KOZ Algo SMC/ICT Strategy`, author handle `M_LOADING`, published 2026-03-28, https://www.tradingview.com/script/cWLDZXrh-KOZ-Algo-SMC-ICT-Strategy/

## Mechanik

### Entry
Use M5 execution with M15 structure bias.

- Determine M15 bias from confirmed swing structure:
  - bullish bias when structure forms higher highs and higher lows.
  - bearish bias when structure forms lower highs and lower lows.
  - mixed structure means no trade.
- Plot Previous Day High, Previous Day Low, most recent M15 swing high, and most recent M15 swing low as liquidity levels.
- Long setup:
  - M15 bias is bullish.
  - M5 price sweeps below PDL or a recent M15 swing low.
  - candle closes back above the swept level.
  - an order block or fair value gap confluence is present.
  - entry trigger candle is bullish engulfing or bullish pin bar.
- Short setup:
  - M15 bias is bearish.
  - M5 price sweeps above PDH or a recent M15 swing high.
  - candle closes back below the swept level.
  - an order block or fair value gap confluence is present.
  - entry trigger candle is bearish engulfing or bearish pin bar.

### Exit
- TP1 at nearest opposite M15 swing level.
- TP2 at 2.5R extension.
- Baseline implementation closes 50% at TP1 and the remainder at TP2 only if V5 slot accounting permits; otherwise use full close at TP1 or TP2 variant in P3.

### Stop Loss
- Stop at the extreme of the sweep wick.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline.

### Zusatzliche Filter
- Trade only during New York windows 09:30-11:00 ET and 14:00-15:30 ET.
- Primary DWX symbols: NDX.DWX, WS30.DWX, XAUUSD.DWX, EURUSD.DWX.

## Concepts (was ist das fur eine Strategie)
- [[concepts/liquidity-sweep]] - fade a stop-run that rejects through prior liquidity.
- [[concepts/smc-ict]] - requires HTF structure, OB/FVG confluence, and rejection candle.
- [[concepts/session-filter]] - trades only during specified NY windows.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `M_LOADING` are cited. |
| R2 Mechanical | PASS | Source gives bias, level, sweep, confluence, rejection, stop, target, and session rules. |
| R3 Data Available | PASS | Uses OHLC structure levels portable to DWX index, metal, and FX CFDs. |
| R4 ML Forbidden | UNKNOWN | No ML/grid/martingale, but partial-close handling must remain compatible with one-position-per-magic rules. |

## R3
Primary P2 basket: NDX.DWX, WS30.DWX, XAUUSD.DWX, EURUSD.DWX.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING, drafted from TradingView script page.

## Verwandte Strategien
- [[strategies/QM5_10645_tv-sweep-react]] - simpler fractal sweep reversal; this card adds HTF bias, OB/FVG confluence, and session windows.

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
