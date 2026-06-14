---
ea_id: QM5_10775
slug: tv-liq-ims
type: strategy
source_id: d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
source_citation: "TradingView script `Liquidity + Internal Market Shift Strategy`, author handle `The_Forex_Steward`, open-source strategy, 2025-03-22, https://www.tradingview.com/script/vfcGHwNP-Liquidity-Internal-Market-Shift-Strategy/"
sources:
  - "[[sources/tradingview-mechanical-strategy-scripts]]"
concepts:
  - "[[concepts/liquidity-sweep]]"
  - "[[concepts/market-structure-shift]]"
indicators: [local-high-low, internal-shift]
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX, GER40.DWX]
period: M15
expected_trade_frequency: "Local high/low liquidity touches with internal shift confirmation should be active on intraday charts; conservative estimate 90 trades/year/symbol."
expected_trades_per_year_per_symbol: 90
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id with TradingView URL and author handle The_Forex_Steward cited."
r2_mechanical: PASS
r2_reasoning: "Local high/low liquidity zones, internal shift trigger, long/short mode, time filter, and SL/TP are mechanically translatable."
r3_data_available: PASS
r3_reasoning: "OHLC swing pivots, session clock, and ATR price brackets available on DWX CFDs; target symbols EURUSD/GBPUSD/USDJPY/XAUUSD/GER40 are all DWX."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed price-action rules; no ML, grid, martingale, or adaptive online parameters; one position per magic."
pipeline_phase: G0
last_updated: 2026-05-22
card_body_incomplete: true
card_body_missing: "period"
g0_approval_reasoning: "R1 direct TradingView source URL; R2 mechanical liquidity-zone plus internal-shift entries with SL/TP, ~90 trades/year/symbol; R3 OHLC/ATR/session logic testable on DWX CFDs; R4 fixed non-ML one-position rules."
---

# TradingView Liquidity Internal Market Shift

## Quelle
- Source: [[sources/tradingview-mechanical-strategy-scripts]]
- Page / Timestamp: TradingView script `Liquidity + Internal Market Shift Strategy`, author handle `The_Forex_Steward`, open-source strategy, published 2025-03-22, https://www.tradingview.com/script/vfcGHwNP-Liquidity-Internal-Market-Shift-Strategy/
- Source location: public page defines local high/low liquidity zones, bullish/bearish internal shifts, mode options, customizable SL/TP, and time range control.

## Mechanik

### Entry
- Build liquidity zones from local swing highs and lows.
- Long setup:
  - Price interacts with or sweeps a recent local low liquidity zone.
  - A bullish internal shift occurs, defined for P2 as close above the most recent bearish internal pivot high.
  - Strategy mode is `Both` or `Bullish Only`.
  - Current time is inside the configured time range.
- Short setup:
  - Price interacts with or sweeps a recent local high liquidity zone.
  - A bearish internal shift occurs, defined for P2 as close below the most recent bullish internal pivot low.
  - Strategy mode is `Both` or `Bearish Only`.

### Exit
- Exit at configured take-profit level.
- Exit at configured stop-loss level.
- Optional opposite internal shift exit is disabled in P2 unless source code review shows it is native.

### Stop Loss
- Long: below the touched/swept liquidity-zone low plus ATR buffer.
- Short: above the touched/swept liquidity-zone high plus ATR buffer.
- P2 baseline target: 2R.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- One open position per symbol/magic.

### Zusaetzliche Filter
- Swing lookback baseline: 5 bars left/right.
- Internal pivot lookback baseline: 2 bars left/right.
- Session/time range baseline: London + New York.

## Concepts
- [[concepts/liquidity-sweep]] - local highs/lows mark liquidity zones.
- [[concepts/market-structure-shift]] - entry waits for internal shift after liquidity interaction.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Direct TradingView URL plus author handle `The_Forex_Steward`. |
| R2 Mechanical | PASS | Local high/low liquidity zones, internal shift trigger, long/short modes, time filter, and SL/TP are mechanically translatable. |
| R3 DWX-testbar | PASS | OHLC swing pivots, session clock, and ATR/price brackets are available on DWX CFDs. |
| R4 No ML | PASS | Fixed price-action rules; no ML, grid, martingale, or adaptive online parameters. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD, GER40.DWX, NDX.DWX.
Primary P2 timeframe: M15.

## Author Claims
- Source says it combines liquidity zone analysis with internal market structure for high-probability entries.
- Source says bullish shifts occur when price breaks previous bearish levels, and bearish shifts happen when price breaks previous bullish levels.
- Source says customizable stop-loss and take-profit levels are integrated.

## Parameters To Test
- Liquidity swing lookback: 3, 5, 8.
- Internal shift lookback: 2, 3, 5.
- ATR stop buffer: 0.25, 0.50, 1.00.
- R:R target: 1.5, 2.0, 2.5.

## Initial Risk Profile
Good SMC-style structure but the exact internal-shift implementation is source-visible prose rather than code. P2 should use deterministic pivot definitions and keep the first implementation simple.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING.

## Lessons Learned
- TBD during pipeline run.
