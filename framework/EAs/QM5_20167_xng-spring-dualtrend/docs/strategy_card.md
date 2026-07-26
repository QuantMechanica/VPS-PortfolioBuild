---
card_schema_version: 2
ea_id: QM5_20167
slug: xng-spring-dualtrend
type: strategy
strategy_id: EIA-MOP-XNG-SPRING-DUALTREND-2026_S01
variant_id: EIA-MOP-XNG-SPRING-DUALTREND-2026_S01
source_id: EIA-MOP-XNG-SPRING-DUALTREND-2026
status: APPROVED
g0_status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20167_xng-spring-dualtrend_card.md
execution_contract_status: DRAFT
created: 2026-07-26
created_by: Research+Development
last_updated: 2026-07-26
source_citation: "U.S. EIA (2015), Natural gas use features two seasonal peaks per year; Moskowitz, Ooi and Pedersen (2012), Time Series Momentum, JFE 104(2)."
sources:
  - "[[sources/EIA-MOP-XNG-SPRING-DUALTREND-2026]]"
strategy_type_flags: [natural-gas, spring-shoulder, dual-trend, short-only, atr-hard-stop, low-frequency]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
markets: [commodities, energy, natural_gas]
single_symbol_only: true
logical_symbol: QM5_20167_XNG_SPRING_DUALTREND_D1
symbol: XNGUSD.DWX
period: D1
timeframe: D1
timeframes: [D1]
expected_trade_frequency: "Friday-segmented April-May trend packages; approximately 5-10 completed trades/year when the dual-trend state is valid."
expected_trades_per_year_per_symbol: 7
expected_pf: 1.01
expected_dd_pct: 25.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PASS
q02_status: ENQUEUED
q02_work_item_id: 3be82258-5dda-4e5b-b82c-9ea3ef546e62
review_focus: "Adds spring-shoulder short trend exposure distinct from the incumbent XNG RSI pullback. The April-May window plus falling 21/84-D1 trend stack are jointly load-bearing; Q09 alone may establish realized orthogonality."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [low_frequency_sample, natural_gas_gaps, friday_close, magic_schema, risk_mode_dual, portfolio_correlation]
g0_approval_reasoning: "APPROVED under the OWNER commodity/energy sleeve mission: R1 PASS official EIA seasonality plus peer-reviewed JFE trend lineage; R2 PASS fixed April-May window, falling 21/84-D1 trend stack, ATR stop and deterministic exits; R3 PASS registered XNGUSD.DWX D1 carrier; R4 PASS native MT5 data only with no ML, banned indicator, grid or martingale. Non-duplicate versus QM5_12567 RSI pullback, QM5_12703 calendar-only spring allocation, QM5_20166 autumn channel breakout, and winter/summer long dual-trend variants."
---

# QM5_20167 XNG Spring-Shoulder Dual-Trend Short

## Hypothesis

Natural-gas winter heating and summer power demand create two recurring peaks, with an intervening spring shoulder, but calendar
exposure alone is too blunt. This card enters short only when the April-May
window overlaps a negative and accelerating completed-bar price trend.

## Source and evidence boundary

The governed packet at
`strategy-seeds/sources/EIA-MOP-XNG-SPRING-DUALTREND-2026/source.md` records the
official EIA seasonality lineage and peer-reviewed time-series-momentum lineage.
The exact moving-average and risk parameters are QM hypotheses, not source
claims. No return, correlation, or profitability claim is imported.

## Rules

### Entry rules

- Exact carrier `XNGUSD.DWX`, D1, magic slot 0.
- Evaluate once per new D1 bar during April and May.
- Require completed close below SMA(21), SMA(21) below SMA(84), SMA(21) below
  its value five completed bars earlier, and SMA(84) below its value five
  completed bars earlier.
- Require spread no greater than 1000 points and valid ATR(20).
- SELL with a frozen `3.5 * ATR(20)` hard stop and no take profit.
- One position per magic and one entry attempt per broker D1 bar. Friday close
  remains enabled, so a still-valid trend may form a new weekly package.

### Exit rules

- Close outside April-May.
- Close if completed close is at or above SMA(21), SMA(21) is at or above
  SMA(84), or either five-day SMA slope is non-negative.
- Close after 35 calendar days as a stale safety override.
- Framework Friday close and kill switch remain authoritative.

## Parameters to test

| parameter | default | authorized values |
|---|---:|---|
| `strategy_fast_period` | 21 | [21] |
| `strategy_slow_period` | 84 | [84] |
| `strategy_slope_bars` | 5 | [5] |
| `strategy_atr_period` | 20 | [20] |
| `strategy_atr_sl_mult` | 3.5 | [3.5] |
| `strategy_max_hold_days` | 35 | [35] |
| `strategy_max_spread_points` | 1000 | [1000] |

All baseline parameters are locked. Changing the season, trend stack, direction,
or exit logic is a new card, not a rescue sweep.

## Non-duplicate decision

- `QM5_12567` buys short-horizon cumulative-RSI pullbacks; this uses no
  oscillator or oversold condition.
- `QM5_12703` checks a spring calendar state with one slow-mean confirmation;
  this requires a daily negative 21/84 stack with both five-day slopes falling.
- `QM5_20063` uses a monthly 63-D1 return sign in either direction and no
  seasonal window; this is short-only and spring-gated.
- Existing XNG freeze, storage, expiry, LNG, weekday and breakout cards use
  different event clocks or triggers.

## Risk, acceptance and kill criteria

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Retire below five completed trades/year at Q02. Fail on
wrong-season entry, invalid trend-state entry, repeated same-bar entry,
nondeterminism, risk mismatch, or governed PF/DD failure. Q09 correlation is
authoritative; structural difference does not guarantee decorrelation.

## Framework alignment

- no_trade: exact carrier, timeframe, slot and locked-input validation.
- trade_entry: spring-shoulder falling dual-SMA short entry with spread/ATR guards.
- trade_management: season, trend-state and max-hold exits.
- trade_close: framework strategy close or broker ATR stop.

## Safety boundary

This authorizes card, build, strict compile, one RISK_FIXED setfile and Q02
enqueue only. It does not authorize a live setfile, T_Live access,
AutoTrading, deploy manifest, portfolio gate or portfolio manifest change.
