---
ea_id: QM5_10750
slug: tv-rev-brk-orb
type: strategy
source_id: d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
source_citation: "Stock_Reaver, Reversal & Breakout Strategy with ORB, TradingView open-source strategy, https://www.tradingview.com/script/D94ChhXj-Reversal-Breakout-Strategy-with-ORB/"
sources:
  - "[[sources/tradingview-mechanical-strategy-scripts]]"
concepts:
  - "[[concepts/opening-range-breakout]]"
  - "[[concepts/momentum-breakout]]"
  - "[[concepts/mean-reversion]]"
indicators:
  - "[[indicators/ema]]"
  - "[[indicators/sma]]"
  - "[[indicators/rsi]]"
  - "[[indicators/vwap]]"
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id present with direct TradingView URL and named author handle Stock_Reaver."
r2_mechanical: PASS
r2_reasoning: "Reversal, breakout, and ORB submodel entry conditions with EMA/SMA/RSI/VWAP/ATR indicators, ATR structure stop, 2R target, and breakeven are all explicitly defined."
r3_data_available: PASS
r3_reasoning: "NDX.DWX, WS30.DWX, GER40.DWX, XAUUSD.DWX, EURUSD.DWX, and GBPUSD.DWX are available DWX instruments; VWAP and volume use broker-session approximation and DWX tick volume proxy."
r4_ml_forbidden: PASS
r4_reasoning: "No ML, martingale, or grid; source pyramiding is explicitly disabled in V5 baseline; one position per magic enforced."
pipeline_phase: G0
expected_trades_per_year_per_symbol: 160
last_updated: 2026-05-22
g0_approval_reasoning: "R1 exact TradingView URL/author; R2 mechanical reversal/breakout/ORB entries and ATR exits with ~160 trades/yr/symbol; R3 portable to DWX using tick-volume/VWAP proxies; R4 non-ML with pyramiding disabled."
---

# TradingView Reversal Breakout ORB Mashup

## Quelle
- Source: [[sources/tradingview-mechanical-strategy-scripts]]
- Page / Timestamp: TradingView script `Reversal & Breakout Strategy with ORB`, author handle `Stock_Reaver`, open-source strategy, published 2025-03-25, https://www.tradingview.com/script/D94ChhXj-Reversal-Breakout-Strategy-with-ORB/

## Mechanik

### Entry
Use M5 baseline. V5 treats the three source entry families as one confluence strategy sharing the same stop/target model.

- Compute EMA(9), EMA(20), SMA(50), SMA(200), RSI(14), VWAP, ATR(14), and opening range high/low over default 15 bars.
- Long may trigger from any enabled submodel:
  - Reversal: SMA50 cross condition, RSI(14) < 30, price below VWAP, and SMA200 uptrend context.
  - Breakout: EMA9 > EMA20, price above VWAP, and SMA200 uptrend context.
  - ORB: price breaks above opening range high with volume > 1.5x opening-range average volume.
- Short mirrors:
  - Reversal: SMA50 cross condition, RSI(14) > 70, price above VWAP, and SMA200 downtrend context.
  - Breakout: EMA9 < EMA20, price below VWAP, and SMA200 downtrend context.
  - ORB: price breaks below opening range low with volume confirmation.
- P2 baseline disables pyramiding and opens only one full-position trade.

### Exit
- Stop loss is based on lowest low / highest high over 7 bars plus or minus 1.5 ATR.
- V5 collapses the source two-target partial exits to one full-position target at 2R.
- Move stop to breakeven after +1R can be tested in P3.
- Opposite signal may close if it appears before target.

### Stop Loss
- Long stop = lowest low over 7 bars - ATR(14) * 1.5.
- Short stop = highest high over 7 bars + ATR(14) * 1.5.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per symbol/magic. Source 5% equity risk is not used.

### Zusatzliche Filter
- Session filter: US RTH for ORB submodel; reversal/breakout can be restricted to liquid hours.
- Volume confirmation uses DWX tick volume where exchange volume is unavailable.
- Disable source pyramiding up to 2 positions.

## Concepts (was ist das fur eine Strategie)
- [[concepts/opening-range-breakout]] - one source submodel catches early-session breaks with volume.
- [[concepts/momentum-breakout]] - EMA/VWAP/SMA200 alignment catches continuation.
- [[concepts/mean-reversion]] - RSI extremes plus SMA50/VWAP context catch pullback reversals.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `Stock_Reaver` are cited. |
| R2 Mechanical | PASS | Source defines indicators, long/short entries, ATR structure stop, 1R/2R exits, breakeven, and risk settings. |
| R3 Data Available | UNKNOWN | OHLC indicators are portable; volume confirmation must use DWX tick volume. |
| R4 ML Forbidden | PASS | No ML, martingale, or grid. Source pyramiding is explicitly disabled in V5 baseline. |

## R3
Primary P2 basket: NDX.DWX, WS30.DWX, GER40.DWX, XAUUSD, EURUSD.DWX, GBPUSD.DWX. VWAP is broker-session VWAP approximation; volume uses DWX tick volume. SP500.DWX is optional backtest-only. Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- Source says the strategy combines "reversals, trend breakouts, and opening range breakouts (ORB)" into one system.
- Source says the ORB submodel breaks the high/low of a default 15-bar opening range with volume confirmation.
- Source says stop loss is based on lowest low/highest high over 7 bars plus/minus 1.5x ATR.

## Parameters To Test
- Enabled submodels: ORB only, breakout only, reversal only, all three.
- Opening range bars: 5, 10, 15, 30.
- ATR stop multiplier: 1.0, 1.5, 2.0.
- Structure lookback: 5, 7, 10 bars.
- Volume filter: off, 1.25x, 1.5x, 2.0x tick volume.
- Target: 1.5R, 2.0R, 2.5R.
- Breakeven after +1R: off vs on.

## Initial Risk Profile
Mixed intraday strategy with higher implementation breadth than a clean single-model ORB. Main risks are overfitting from three submodels, volume proxy mismatch, and duplicate position pressure if V5 one-position enforcement is not strict.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING, drafted from TradingView script page.

## Verwandte Strategien
- QM5_10668 tv-vwap-orb-pb
- QM5_10669 tv-cleighty-bos
- QM5_10752 tv-nq-vwap-orb

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
