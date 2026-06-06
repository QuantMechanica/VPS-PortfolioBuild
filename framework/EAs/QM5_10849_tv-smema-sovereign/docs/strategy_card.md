---
ea_id: QM5_10849
slug: tv-smema-sovereign
type: strategy
source_id: d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
source_citation: "officialjackofalltrades, Sovereign Trend Strategy [JOAT], TradingView open-source strategy, Apr 21, https://www.tradingview.com/script/DGHCEcnB-Sovereign-Trend-Strategy-JOAT/"
sources:
  - "[[sources/tradingview-mechanical-strategy-scripts]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/moving-average-crossover]]"
  - "[[concepts/atr-risk-management]]"
indicators:
  - "[[indicators/ema]]"
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
  - "[[indicators/adx]]"
  - "[[indicators/rsi]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 120
last_updated: 2026-05-22
g0_approval_reasoning: "R1 cites TradingView URL/author; R2 mechanical SMEMA crossover with ATR exits/stops; R3 testable on DWX OHLC/indicator symbols with expected 120 trades/year/symbol; R4 fixed rules one-position compatible no ML/grid/martingale."
---

# TradingView Sovereign SMEMA Trend

## Quelle
- Source: [[sources/tradingview-mechanical-strategy-scripts]]
- Page / Timestamp: TradingView script `Sovereign Trend Strategy [JOAT]`, author handle `officialjackofalltrades`, open-source strategy, accessed 2026-05-22, page shows Apr 21, https://www.tradingview.com/script/DGHCEcnB-Sovereign-Trend-Strategy-JOAT/

## Mechanik

### Entry
Use M15/H1 baseline. Long/short symmetric source logic:

- Compute SMEMA fast = SMA(EMA(close, 2), 2).
- Compute SMEMA slow = SMA(EMA(close, 5), 5).
- Compute optional baseline SMEMA = SMA(EMA(close, 15), 15).
- Long when fast SMEMA crosses above slow SMEMA on a confirmed bar.
- Short when fast SMEMA crosses below slow SMEMA on a confirmed bar.
- Optional quality filters for P3: ADX(14) >= 18, RSI(14) >= 52 for long or <= 48 for short, ATR(14) / SMA(ATR(14), 20) >= 0.8, and close on the correct side of baseline SMEMA.
- Baseline P2 keeps filters off, matching source default high-frequency mode.

### Exit
- Initial stop = 1.8 * ATR(14) from entry.
- TP1 = 2.5 * ATR(14), close 50% equivalent in source. V5 baseline records TP1 as breakeven trigger, not a second live position.
- TP2 = 4.5 * ATR(14).
- After TP1, move stop to breakeven and trail by 1.5 * ATR(14).
- Close on opposite SMEMA crossover.
- Time exit after 10 bars.

### Stop Loss
- Hard stop = 1.8 * ATR(14).
- V5 spread guard: skip if spread > 15% of stop distance.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per symbol/magic. Partial source exit is implemented as bracket-state management without opening multiple positions.

### Zusatzliche Filter
- Disable date-window restrictions in P2.
- P3 can compare optional filters one at a time to avoid overfitting.

## Concepts (was ist das fur eine Strategie)
- [[concepts/trend-following]] - follows short-cycle double-smoothed moving average direction.
- [[concepts/moving-average-crossover]] - fast/slow SMEMA cross is the entry trigger.
- [[concepts/atr-risk-management]] - all hard stops and targets are ATR-multiple based.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `officialjackofalltrades` are cited. |
| R2 Mechanical | PASS | Source gives SMEMA formula, crossover entries, optional filters, ATR stop/targets, trailing, reversal exit, and max-bars exit. |
| R3 Data Available | PASS | EMA, SMA, ATR, ADX, RSI, OHLC, and bar-count exits are available on DWX FX, metals, oil, and index CFDs. |
| R4 ML Forbidden | PASS | Fixed indicators and fixed parameters; source says pyramiding is disabled and no ML/grid/martingale is used. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, GER40.DWX, NDX.DWX.

If this is later tested primarily on SP500.DWX, live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- Source says the strategy is built on an SMEMA crossover engine.
- Source says entries fire on fast/slow SMEMA crossovers.
- Source says pyramiding is disabled and entries only fire when no open trades exist.
- Source says trade management uses 1.8 ATR stop, 2.5 ATR TP1, 4.5 ATR TP2, 1.5 ATR trail, reversal exit, and max-bars exit.

## Parameters To Test
- Timeframe: M15, M30, H1.
- Fast/slow SMEMA: 2/5, 3/8, 5/13.
- ATR stop: 1.5, 1.8, 2.2.
- Max bars: 7, 10, 20.
- Optional filters: none, ADX only, ADX + RSI, ADX + volatility ratio.

## Initial Risk Profile
High-cadence trend crossover system. Main risks are whipsaw in ranges and overfitting if too many optional filters are enabled at once.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING, drafted from TradingView mechanical strategy source.

## Verwandte Strategien
- QM5_10843 tv-fracture-th
- QM5_10839 tv-momo-slope

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
