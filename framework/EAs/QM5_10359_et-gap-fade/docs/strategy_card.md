---
ea_id: QM5_10359
slug: et-gap-fade
type: strategy
source_id: d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
source_citation: "WarEagle / Kirk, Fading The Opening Gap, Elite Trader, 2002-01-08, https://www.elitetrader.com/et/threads/fading-the-opening-gap.3473/"
sources:
  - "[[sources/elite-trader-algo-mech]]"
concepts:
  - "[[concepts/opening-gap-fade]]"
  - "[[concepts/mean-reversion]]"
  - "[[concepts/time-stop]]"
indicators: []
target_symbols: [SP500.DWX, NDX.DWX, WS30.DWX, GER40.DWX]
period: M5
expected_trade_frequency: "Opening gap fade only when the index gaps beyond 0.6%; conservative estimate 45 trades/year/symbol after spread and session filters."
expected_trades_per_year_per_symbol: 45
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-21
g0_approval_reasoning: "R1 Elite Trader URL+handle; R2 mechanical gap fade entry/target/time+stop with ~45 trades/year/symbol; R3 DWX index CFDs incl SP500.DWX backtest caveat; R4 fixed no ML/martingale/1-pos."
---

# Elite Trader Opening Gap Fade

## Quelle
- Source: [[sources/elite-trader-algo-mech]]
- URL: https://www.elitetrader.com/et/threads/fading-the-opening-gap.3473/
- Author / handle: `WarEagle` / Kirk.
- Date: 2002-01-08.
- Location: post #6. The post gives TradeStation code for fading Nasdaq futures opening gaps on 5-minute bars.

## Mechanik

### Entry
- Trade M5 bars during the primary index session.
- On the first completed session bar, compute `gap = abs(previous_close - session_open)`.
- If `gap >= previous_close * GapPercent` and session open is above previous day's high, prepare a short fade.
- If `gap >= previous_close * GapPercent` and session open is below previous day's low, prepare a long fade.
- Enter short on a stop through the first-bar low for gap-up fades.
- Enter long on a stop through the first-bar high for gap-down fades.

### Exit
- Profit target equals the opening gap size from entry, representing a gap-fill target.
- Time stop exits after `InactiveStop` bars if target has not filled.
- V5 adds a hard protective stop because the source leaves stop loss optional; baseline stop is `1.25 * gap`.
- Friday close enforced by framework.

### Stop Loss
- Baseline source stop input is disabled; V5 baseline enables `StopLoss = 1.25 * gap`.
- Skip trades if stop distance is less than four current spreads.
- Skip when first-bar range is wider than 0.8x ATR(14) on M5.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Zusaetzliche Filter
- Index CFDs only in initial P2 basket.
- Use exchange/session open mapped to broker time.
- One trade per symbol per session.

## Concepts
- [[concepts/opening-gap-fade]] - the setup fades large overnight/session gaps.
- [[concepts/mean-reversion]] - target is a retracement equal to the gap.
- [[concepts/time-stop]] - stagnant trades are closed after a fixed number of bars.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full Elite Trader thread URL plus author handle `WarEagle` / Kirk. |
| R2 Mechanical | PASS | Source gives threshold, direction, stop entries, target, and time exit. |
| R3 DWX-testbar | PASS | Nasdaq/S&P futures gap fade ports to SP500.DWX and live index CFDs. |
| R4 No ML | PASS | Fixed rules; no ML, adaptive parameters, martingale, grid, or pyramiding. |

## R3
Primary P2 basket: `SP500.DWX`, `NDX.DWX`, `WS30.DWX`, `GER40.DWX`.

Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- The source says the rules are simple: fade a 0.6% gap and exit at a target equal to the gap or after 15 M5 bars.
- The source reports 245 trades, 62.04% profitable, and profit factor 1.54 on a preliminary 1997-2001 Nasdaq futures backtest.

## Parameters To Test
- GapPercent: 0.004, 0.006, 0.008, 0.010.
- InactiveStop: 10, 15, 20, 30 M5 bars.
- Protective stop: 1.0, 1.25, 1.5, 2.0 gap units.
- Entry trigger: first-bar high/low, first 2-bar high/low.

## Initial Risk Profile
Mean-reversion gap fade with explicit time exit. Main risk is trend-day continuation after a news-driven gap; V5 protective stop is mandatory despite the source showing better historical tests without it.

## Pipeline-Verlauf
- G0: 2026-05-21, PENDING.

## Lessons Learned
- TBD during pipeline run.
