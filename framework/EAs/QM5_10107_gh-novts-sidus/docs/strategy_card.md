---
ea_id: QM5_10107
slug: gh-novts-sidus
type: strategy
source_id: 3b3ec48a-0755-5187-9331-afb36e174175
source_citation: "NOVTS, ExpSidus.mq5 / Sidus.mqh, GitHub repository novts/MetaTrader-5-Creating-Trading-Robots-and-Indicators-with-MQL5, 2018, https://github.com/novts/MetaTrader-5-Creating-Trading-Robots-and-Indicators-with-MQL5/blob/master/Example%20of%20Creating%20Advisor/ExpSidus.mq5"
sources:
  - "[[sources/github-mql5-stars-20]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/moving-average-cross]]"
indicators:
  - "[[indicators/ema]]"
  - "[[indicators/lwma]]"
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX]
period: H1
expected_trade_frequency: "H1 four-moving-average state flip; selective trend-change cadence. Estimate 20-45 trades/year/symbol."
expected_trades_per_year_per_symbol: 30
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 source GitHub URL present; R2 deterministic four-MA entry/exit with ~30 trades/year/symbol; R3 testable on DWX FX/metals; R4 fixed-rule no ML/grid/martingale one-position."
---

# GitHub NOVTS Sidus Four-MA Flip

## Quelle
- Source: [[sources/github-mql5-stars-20]]
- Citation: NOVTS, `ExpSidus.mq5` / `Sidus.mqh`, GitHub, 2018.
- Primary URL: https://github.com/novts/MetaTrader-5-Creating-Trading-Robots-and-Indicators-with-MQL5/blob/master/Example%20of%20Creating%20Advisor/ExpSidus.mq5
- Supporting URL: https://github.com/novts/MetaTrader-5-Creating-Trading-Robots-and-Indicators-with-MQL5/blob/master/Example%20of%20Creating%20Advisor%20using%20OOP/Sidus.mqh
- Source attribution: file header `Copyright 2018, NOVTS`, link `http://novts.com`.

## Mechanik

### Entry
- Work on completed H1 bars.
- Compute EMA(18), EMA(28), LWMA(5), and LWMA(8).
- Buy when both LWMA(5) and LWMA(8) are above both EMA(18) and EMA(28) on the prior completed bar, and within the prior `numberBarOpenPosition = 5` bars both fast averages were previously below both slow averages.
- Sell when both LWMA(5) and LWMA(8) are below both EMA(18) and EMA(28) on the prior completed bar, and within the prior 5 bars both fast averages were previously above both slow averages.
- V5 constraint: one active position per symbol/magic.

### Exit
- Source primary exit is fixed SL/TP attached at entry.
- Additional signal close:
  - Close a buy if LWMA(5) crosses below LWMA(8) within the prior `numberBarStopPosition = 5` bars and recent highs do not break above the 5-bar high.
  - Close a sell if LWMA(5) crosses above LWMA(8) within the prior 5 bars and recent lows do not break below the 5-bar low.
- After a stop-loss exit, source suppresses new entries until the next D1 bar; preserve as a daily cooldown.

### Stop Loss
- Source default `StopLoss = 0.01` price units from entry.
- P1 should expose this as a symbol-normalized points or ATR-backed parameter because raw price-unit stops are not portable across DWX symbols.

### Position Sizing
- P2 baseline uses V5 default fixed risk $1,000.
- Source fixed `Lot = 1` is ignored for baseline sizing.

### Zusaetzliche Filter
- Source spread filter: skip if calculated spread exceeds `spreadLevel = 5.0`.
- Require at least 100 bars of history before signals.
- Use completed bars only; do not evaluate intrabar flips.

## Concepts
- [[concepts/trend-following]] - primary
- [[concepts/moving-average-cross]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full GitHub file URL and named NOVTS file attribution. |
| R2 Mechanical | PASS | Four moving-average state flip entries, fixed/procedural exits, daily cooldown, and spread filter are deterministic. |
| R3 DWX-testbar | PASS | EMA/LWMA, OHLC, spread, and H1 bars are available on DWX forex/metals. |
| R4 No ML | PASS | Fixed indicator rules, one-position V5 constraint, no ML, no grid, no martingale, and no adaptive parameters. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX. Not SP500-specific.

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10059_gh-puria]] - related MA/MACD trend-confirmation family.
- [[strategies/QM5_10051_gh-ma-cross]] - simpler two-MA crossover; this card requires both fast averages to flip around both slow averages.

## Lessons Learned
- TBD during pipeline run.

