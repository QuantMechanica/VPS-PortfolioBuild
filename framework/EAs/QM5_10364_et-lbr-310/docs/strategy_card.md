---
ea_id: QM5_10364
slug: et-lbr-310
type: strategy
source_id: d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
source_citation: "DonKee, FREE ES Trading Strategy that works, Elite Trader, 2009-04-29, https://www.elitetrader.com/et/threads/free-es-trading-strategy-that-works.162375/"
sources:
  - "[[sources/elite-trader-algo-mech]]"
concepts:
  - "[[concepts/macd-pullback]]"
  - "[[concepts/intraday-session-pattern]]"
  - "[[concepts/fixed-risk-reward]]"
indicators: [EMA, MACD]
target_symbols: [SP500.DWX, NDX.DWX, WS30.DWX, GER40.DWX]
period: M1
expected_trade_frequency: "Source reports 3-10 ES signals/day on 1000-tick bars; V5 bar-port and session filters conservatively estimate 250 trades/year/symbol."
expected_trades_per_year_per_symbol: 250
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-21
g0_approval_reasoning: "R1 source URL/handle present; R2 MACD/EMA pullback entries and fixed exits mechanical with ~250 trades/year/symbol; R3 index CFDs incl SP500.DWX backtest and NDX/WS30/GER40 ports; R4 fixed-rule no ML/martingale."
---

# Elite Trader LBR 3-10-16 First Cross Pullback

## Quelle
- Source: [[sources/elite-trader-algo-mech]]
- URL: https://www.elitetrader.com/et/threads/free-es-trading-strategy-that-works.162375/
- Author / handle: `DonKee`.
- Date: 2009-04-29.
- Location: post #1 plus same-page follow-up. The post defines ES 1000-tick chart, 9/34 EMA context, MACD 3/10/16, first-cross pullback entry, 2-point target, 2-point stop, and optional breakeven after +1.5 points.

## Mechanik

### Entry
- Port the 1000-tick ES chart to M1/M2 index-CFD bars for Darwinex testing.
- Compute MACD with fast 3, slow 10, signal 16. Use the MACD signal line as the source's "16 line" proxy and MACD histogram as the "3-10 histogram".
- Long setup: signal line crosses above zero for the first time after being below zero.
- Enter long when the histogram pulls below zero and then turns upward for one closed bar toward the positive signal-line trend.
- Short setup: signal line crosses below zero for the first time after being above zero.
- Enter short when the histogram pulls above zero and then turns downward for one closed bar toward the negative signal-line trend.
- Optional filter: require EMA(9) > EMA(34) for longs and EMA(9) < EMA(34) for shorts.
- Trade only regular index session; skip FOMC/news windows through P8 defaults.

### Exit
- Profit target: ES source 2 points; V5 port uses 0.25 ATR(14) or calibrated point equivalent per symbol.
- Stop loss: ES source 2 points; V5 port uses same distance as target for baseline.
- Move stop to breakeven after +0.75 target distance, matching the source's +1.5 on a 2-point target.
- Exit at session close.

### Stop Loss
- Initial fixed stop at target-distance risk.
- No averaging, scaling, or runners in baseline.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Zusaetzliche Filter
- `SP500.DWX` is the closest ES proxy for backtest-only; live-port candidates are `NDX.DWX`, `WS30.DWX`, and `GER40.DWX`.
- Skip when spread exceeds 2.5x rolling median spread.

## Concepts
- [[concepts/macd-pullback]] - MACD 3/10/16 first-cross establishes intraday momentum, then the first histogram pullback provides entry.
- [[concepts/intraday-session-pattern]] - intended for liquid index-session day trading.
- [[concepts/fixed-risk-reward]] - source starts with symmetric 2-point stop and target.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full Elite Trader thread URL plus author handle `DonKee`. |
| R2 Mechanical | PASS | Indicator settings, entry, stop, target, and breakeven rule are explicit; tick-chart-to-time-bar port is deterministic. |
| R3 DWX-testbar | PASS | ES logic is testable on `SP500.DWX`; live candidates are NDX/WS30/GER40 CFDs. |
| R4 No ML | PASS | Fixed indicator rules; no ML, adaptive parameters, grid, martingale, or multi-position requirement. |

## R3
Primary P2 basket: `SP500.DWX`, `NDX.DWX`, `WS30.DWX`, `GER40.DWX`.

Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- The source says it is a "profitable ES trading strategy".
- The source says signals "should get anywhere from 3-10" per day.

## Parameters To Test
- MACD: 3/10/16 fixed; optional 4/13/21 robustness check.
- EMA filter: off, 9/34, 20/50.
- Target/stop: 0.20, 0.25, 0.35 ATR(14).
- Breakeven trigger: none, 0.75R, 1.0R.
- Session: first 90 minutes, last 90 minutes, full regular session.

## Initial Risk Profile
Intraday momentum-pullback scalp with tight targets. Main risks are spread/slippage, chop after the first cross, and degrading the tick-chart concept during time-bar porting.

## Pipeline-Verlauf
- G0: 2026-05-21, PENDING.

## Lessons Learned
- TBD during pipeline run.
