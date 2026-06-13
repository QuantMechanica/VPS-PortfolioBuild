---
ea_id: QM5_10363
slug: et-exp-cont
type: strategy
source_id: d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
source_citation: "OffShoreTrader, Offshore's Trading Journal, Elite Trader, 2003-08-17, https://www.elitetrader.com/et/threads/offshores-trading-journal.21184/"
sources:
  - "[[sources/elite-trader-algo-mech]]"
concepts:
  - "[[concepts/options-expiration]]"
  - "[[concepts/calendar-effect]]"
  - "[[concepts/momentum-continuation]]"
indicators: []
target_symbols: [SP500.DWX, NDX.DWX, WS30.DWX]
period: D1
expected_trade_frequency: "Monthly third-Friday expiration continuation setup; conservative estimate 12 trades/year/symbol."
expected_trades_per_year_per_symbol: 12
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id present; Elite Trader URL and handle `OffShoreTrader` provide full lineage."
r2_mechanical: PASS
r2_reasoning: "Third-Friday calendar condition, lookback direction comparison, and bar-count time exit are fully deterministic."
r3_data_available: PASS
r3_reasoning: "S&P futures rule ports to SP500.DWX for backtest and NDX.DWX/WS30.DWX for live per DWX index-CFD coverage."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed calendar and price-comparison rule; no ML, adaptive parameters, grid, martingale, or pyramiding."
pipeline_phase: G0
last_updated: 2026-05-21
card_body_incomplete: true
card_body_missing: "period"
g0_approval_reasoning: "R1 PASS Elite Trader URL/handle cited; R2 PASS mechanical calendar entry and time/ATR exit with 12 trades/year/symbol; R3 PASS SP500.DWX backtest plus NDX/WS30 caveat; R4 PASS fixed non-ML one-position rules."
---

# Elite Trader Expiration Continuation

## Quelle
- Source: [[sources/elite-trader-algo-mech]]
- URL: https://www.elitetrader.com/et/threads/offshores-trading-journal.21184/
- Author / handle: `OffShoreTrader`.
- Date: 2003-08-17.
- Location: post #2. The post describes and codes an S&P futures expiration-continuation rule.

## Mechanik

## Period
D1

### Entry
- Determine the Monday following standard third-Friday monthly expiration.
- Baseline `TimeToExit = 7` daily bars.
- On the setup day, compare Friday close to the close `TimeToExit` bars earlier.
- If `FridayClose - Close[TimeToExit] > 0`, enter long next bar at market.
- Otherwise enter short next bar at market.
- V5 conversion: if market holiday shifts the next session, enter at the first tradable session after expiration Friday.

### Exit
- Exit after `TimeToExit` bars on close.
- V5 adds a protective stop at `2.5 * ATR(20)` from entry.
- Friday close enforced by framework if holding period overlaps weekend close policy.

### Stop Loss
- Baseline stop: `2.5 * ATR(20)` because the source code only exits by time.
- Skip if ATR data is missing or stop distance is less than four spreads.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Zusaetzliche Filter
- S&P/index basket only.
- One active position per symbol/magic.
- Do not trade non-standard holiday expiration weeks until calendar mapping is verified.

## Concepts
- [[concepts/options-expiration]] - setup is anchored to monthly third-Friday expiration.
- [[concepts/calendar-effect]] - rule trades a recurring calendar window.
- [[concepts/momentum-continuation]] - direction follows pre-expiration move.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full Elite Trader thread URL plus author handle `OffShoreTrader`. |
| R2 Mechanical | PASS | Source gives calendar condition, direction rule, entry, and time exit. |
| R3 DWX-testbar | PASS | S&P futures rule is testable on SP500.DWX and index CFD analogs. |
| R4 No ML | PASS | Fixed calendar and price-comparison rule; no ML, adaptive parameters, grid, martingale, or pyramiding. |

## R3
Primary P2 basket: `SP500.DWX`, `NDX.DWX`, `WS30.DWX`.

Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- The source says 7-day and 9-day continuations after expiration were the most profitable in a 10-year S&P continuous futures test.
- The source code buys or sells Monday morning in the direction of the prior expiration-window move and exits `TimeToExit` days later.

## Parameters To Test
- TimeToExit: 1, 5, 7, 9 daily bars.
- Direction lookback: same as TimeToExit, 5 bars, 10 bars.
- ATR stop: 1.5, 2.5, 3.5 ATR.
- Index basket: SP500.DWX only, SP500.DWX plus NDX.DWX/WS30.DWX.

## Initial Risk Profile
Low-cadence monthly calendar effect with simple directional continuation. Main risk is sparse sample size; do not promote on SP500.DWX alone without cross-index confirmation.

## Pipeline-Verlauf
- G0: 2026-05-21, PENDING.

## Lessons Learned
- TBD during pipeline run.
