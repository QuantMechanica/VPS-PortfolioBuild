---
ea_id: QM5_10369
slug: et-magnet-limits
type: strategy
source_id: d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
source_citation: "WhiteWolf, \"Magnet\" test system, Elite Trader, 2005-10-16, https://www.elitetrader.com/et/threads/magnet-test-system.57181/"
sources:
  - "[[sources/elite-trader-algo-mech]]"
concepts:
  - "[[concepts/intraday-limit-reversion]]"
  - "[[concepts/session-time-gate]]"
  - "[[concepts/fixed-risk-reward]]"
indicators: []
target_symbols: [SP500.DWX, NDX.DWX, WS30.DWX, GER40.DWX]
period: M1
expected_trade_frequency: "Daily index session setup, but cancelled if the open is outside the bracket or no fill before 11:00; conservative estimate 120 trades/year/symbol."
expected_trades_per_year_per_symbol: 120
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-21
g0_approval_reasoning: "R1 PASS: Elite Trader URL/handle cited; R2 PASS: mechanical bracket limit entries, cancel, stop, target, time exit with ~120 trades/year/symbol; R3 PASS: index CFD/SP500.DWX backtest plus NDX/WS30/GER40 live-test caveat; R4 PASS: fixed non-ML single-position rules."
---

# Elite Trader Magnet Limit Bracket

## Quelle
- Source: [[sources/elite-trader-algo-mech]]
- URL: https://www.elitetrader.com/et/threads/magnet-test-system.57181/
- Author / handle: `WhiteWolf`.
- Date: 2005-10-16.
- Location: posts #1-#3. The thread gives daily ES buy/sell limit levels, requires the 08:30 Chicago open to be inside the bracket, cancels if unfilled by 11:00, uses a 3-point protective stop, a first target near the bracket midpoint, a breakeven move after target one, and a 15:00 exit.

## Mechanik

### Entry
- Build a daily symmetric bracket around the regular-session open using the source examples as calibration.
- Baseline bracket distance: 0.35% above/below the session open, rounded to symbol tick size.
- Trade only if the session open is between the computed buy and sell limit prices.
- Place one long limit below the open and one short limit above the open.
- First fill wins; cancel the opposite entry immediately to preserve one-position-per-magic behavior.
- Cancel all unfilled entries at 11:00 Chicago-equivalent broker time.

### Exit
- Hard stop: 3 ES points in the source; V5 baseline uses 0.30 ATR(14) on M1/M5 index bars.
- Target: midpoint between the two bracket levels, approximating the source's first target.
- Optional runner from source is disabled in baseline; V5 exits the whole position at the target.
- Time exit at 15:00 Chicago-equivalent broker time.

### Stop Loss
- Fixed hard stop from entry.
- No averaging, partial exits, or second contract runner in the baseline.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Zusaetzliche Filter
- Skip high-impact news windows through P8.
- Skip if bracket width is less than 4x current spread or greater than 1.2x ATR(14).
- `SP500.DWX` is the closest ES proxy for backtest-only; live candidates are NDX/WS30/GER40 CFDs.

## Concepts
- [[concepts/intraday-limit-reversion]] - the strategy fades toward precomputed intraday magnet levels.
- [[concepts/session-time-gate]] - entries and exits are bounded by Chicago session times.
- [[concepts/fixed-risk-reward]] - target, stop, and cancel times are fixed at entry.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full Elite Trader thread URL plus author handle `WhiteWolf`. |
| R2 Mechanical | PASS | Source gives deterministic open-in-bracket condition, limit entries, cancel time, stop, targets, and time exit; V5 fills daily bracket construction. |
| R3 DWX-testbar | PASS | ES logic ports to `SP500.DWX` and live-tradable index CFDs. |
| R4 No ML | PASS | Fixed intraday rules; source two-contract partial exit is converted to a single-position full exit. |

## R3
Primary P2 basket: `SP500.DWX`, `NDX.DWX`, `WS30.DWX`, `GER40.DWX`.

Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- The author describes it as a "test system" and reports one example Monday result as "+4 and +0".
- The source states the open "must be between buy and sell numbers" and "a fill must happen before 11am".

## Parameters To Test
- Bracket distance: 0.25%, 0.35%, 0.50% of open.
- Stop: 0.20, 0.30, 0.40 ATR(14).
- Target: midpoint, 0.5R, 1.0R.
- Cancel time: 10:30, 11:00, 11:30 Chicago-equivalent.
- Period: M1, M5.

## Initial Risk Profile
Intraday limit-reversion system with high sensitivity to bracket calibration and morning trend days. Main risks are catching directional breakouts with limit entries and slippage around the hard stop.

## Pipeline-Verlauf
- G0: 2026-05-21, PENDING.

## Lessons Learned
- TBD during pipeline run.
