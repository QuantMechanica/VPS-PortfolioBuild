---
ea_id: QM5_10356
slug: et-trigger-sar
type: strategy
source_id: d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
source_citation: "steve.k.tang / MarkBrown, Simple Intraday Trading System, Elite Trader, 2007-12-22/2007-12-24, https://www.elitetrader.com/et/threads/simple-intraday-trading-system.112548/"
sources:
  - "[[sources/elite-trader-algo-mech]]"
concepts:
  - "[[concepts/intraday-breakout]]"
  - "[[concepts/trailing-stop]]"
  - "[[concepts/stop-and-reverse]]"
indicators: []
target_symbols: [SP500.DWX, NDX.DWX, WS30.DWX, GER40.DWX]
period: M1
expected_trade_frequency: "Intraday high/low trigger system active during core session; conservative estimate 100 trades/year/symbol after one-position and session filters."
expected_trades_per_year_per_symbol: 100
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-21
g0_approval_reasoning: "R1 linked Elite Trader source; R2 mechanical intraday high/low trigger entries, trailing/session exits with ~100 trades/year/symbol; R3 testable on DWX index CFDs incl SP500.DWX backtest caveat; R4 fixed non-ML one-position logic."
---

# Elite Trader Intraday Trigger SAR

## Quelle
- Source: [[sources/elite-trader-algo-mech]]
- URL: https://www.elitetrader.com/et/threads/simple-intraday-trading-system.112548/
- Author / handle: `steve.k.tang`; code variant by `MarkBrown`.
- Dates: 2007-12-22 and 2007-12-24.
- Location: posts #1 and #7. The thread defines new intraday high/low trigger entries, bar-low/bar-high stop-and-reverse logic, trailing profit stops, and a Mark Brown EasyLanguage simplification with fixed risk and end-of-day exit.

## Mechanik

### Entry
- Evaluate M1 bars during the core session.
- Define bullish trigger as a new intraday high; buy stop one tick above trigger.
- Define bearish trigger as a new intraday low; sell stop one tick below trigger.
- Mark Brown variant: buy when the completed bar closes at/above prior intraday high and its low is also at/above that prior high.
- Sell when the completed bar closes at/below prior intraday low and its high is also at/below that prior low.
- Enter one position per symbol/magic only.

### Exit
- Initial long invalidation: low of the bar that crossed the trigger.
- Initial short invalidation: high of the bar that crossed the trigger.
- If price makes a new favorable bar high while long, trail stop to one point/tick below the previous bar low.
- If price makes a new favorable bar low while short, trail stop to one point/tick above the previous bar high.
- V5 conversion: stop-and-reverse is implemented as flat-then-optional-reentry on the next signal, not simultaneous reversal stacking.
- Exit on session close; Friday close enforced by framework.

### Stop Loss
- Baseline stop from source trigger bar high/low.
- Hard cap: `1.5 * ATR(14,M15)` if trigger-bar stop is too wide.
- Skip trade when stop distance is less than four current spreads.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Zusaetzliche Filter
- Index CFDs only for first pass because source is index-futures day-trading oriented.
- Skip first 5 minutes after session open and final 15 minutes before session close.
- Spread filter: skip if spread exceeds 2.5x rolling median.

## Concepts
- [[concepts/intraday-breakout]] - trigger is a fresh intraday high/low.
- [[concepts/trailing-stop]] - stop follows prior bar extremes after favorable movement.
- [[concepts/stop-and-reverse]] - source permits reversal; V5 converts it to flat-then-reenter.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full Elite Trader thread URL plus visible handles `steve.k.tang` and `MarkBrown`. |
| R2 Mechanical | PASS | Trigger, entry, stop, trailing stop, and session exit are explicit. |
| R3 DWX-testbar | PASS | Intraday index-futures logic ports to Darwinex index CFDs and SP500.DWX backtest-only. |
| R4 No ML | PASS | No ML; V5 disables simultaneous stop-and-reverse stacking to preserve one-position-per-magic. |

## R3
Primary P2 basket: `SP500.DWX`, `NDX.DWX`, `WS30.DWX`, `GER40.DWX`.

Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- The source describes trigger levels as new intraday highs/lows.
- The source follow-up code filters the opening and close and exits on close.

## Parameters To Test
- Trigger definition: new session high/low, prior intraday high/low, prior 30-minute high/low.
- Stop offset: 1, 2, 3 ticks or spread-normalized equivalent.
- ATR hard cap: 1.0, 1.5, 2.0 ATR(14,M15).
- Session exclusion: first 0, 5, 15 minutes; final 10, 15, 30 minutes.
- Period: M1, M5.

## Initial Risk Profile
Fast intraday breakout/trailing-stop profile. Main risks are spread sensitivity, whipsaw around session highs/lows, and overtrading; V5 limits entries and disables direct reversal stacking.

## Pipeline-Verlauf
- G0: 2026-05-21, PENDING.

## Lessons Learned
- TBD during pipeline run.
