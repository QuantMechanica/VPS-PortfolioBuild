---
card_schema_version: 2
ea_id: QM5_20164
slug: xng-summer-dualtrend
type: strategy
strategy_id: EIA-MOP-XNG-SUMMER-DUALTREND-2026_S01
variant_id: EIA-MOP-XNG-SUMMER-DUALTREND-2026_S01
source_id: EIA-MOP-XNG-SUMMER-DUALTREND-2026
status: APPROVED
g0_status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20164_xng-summer-dualtrend_card.md
execution_contract_status: DRAFT
created: 2026-07-26
created_by: Research+Development
last_updated: 2026-07-26
source_citation: "U.S. EIA (2015), Natural gas use features two seasonal peaks per year; Moskowitz, Ooi and Pedersen (2012), Time Series Momentum, JFE 104(2)."
sources:
  - "[[sources/EIA-MOP-XNG-SUMMER-DUALTREND-2026]]"
strategy_type_flags: [natural-gas, summer-seasonality, dual-trend, long-only, atr-hard-stop, low-frequency]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
markets: [commodities, energy, natural_gas]
single_symbol_only: true
logical_symbol: QM5_20164_XNG_SUMMER_DUALTREND_D1
symbol: XNGUSD.DWX
period: D1
timeframe: D1
timeframes: [D1]
expected_trade_frequency: "Friday-segmented May-September trend packages; approximately 8-18 completed trades/year when the dual-trend state is valid."
expected_trades_per_year_per_symbol: 10
expected_pf: 1.01
expected_dd_pct: 25.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PENDING
q02_status: NOT_ENQUEUED
review_focus: "Adds summer electric-power-demand trend exposure distinct from the incumbent XNG RSI pullback. The May-Sep window plus rising 21/84-D1 trend stack are jointly load-bearing; Q09 alone may establish realized orthogonality."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [low_frequency_sample, natural_gas_gaps, friday_close, magic_schema, risk_mode_dual, portfolio_correlation]
g0_approval_reasoning: "R1 official EIA summer-demand plus peer-reviewed JFE trend lineage; R2 fixed May-Sep rising 21/84-D1 stack; R3 XNGUSD.DWX D1; R4 native deterministic no ML/grid/martingale"
---

# QM5_20164 XNG Summer Dual-Trend

## Hypothesis

Summer electric-power demand creates a recurring natural-gas regime, but calendar
exposure alone is too blunt. This card enters long only when the May-September
window overlaps a positive and accelerating completed-bar price trend.

## Source and evidence boundary

The governed packet at
`strategy-seeds/sources/EIA-MOP-XNG-SUMMER-DUALTREND-2026/source.md` records the
official EIA seasonality lineage and peer-reviewed time-series-momentum lineage.
The exact moving-average and risk parameters are QM hypotheses, not source
claims. No return, correlation, or profitability claim is imported.

## Rules

### Entry rules

- Exact carrier `XNGUSD.DWX`, D1, magic slot 0.
- Evaluate once per new D1 bar during May through September.
- Require completed close above SMA(21), SMA(21) above SMA(84), SMA(21) above
  its value five completed bars earlier, and SMA(84) above its value five
  completed bars earlier.
- Require spread no greater than 1000 points and valid ATR(20).
- BUY with a frozen `3.5 * ATR(20)` hard stop and no take profit.
- One position per magic and one entry attempt per broker D1 bar. Friday close
  remains enabled, so a still-valid trend may form a new weekly package.

### Exit rules

- Close outside May-September.
- Close if completed close is at or below SMA(21), SMA(21) is at or below
  SMA(84), or either five-day SMA slope is non-positive.
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
- `QM5_12704` checks only a monthly summer close above one SMA; this requires
  a daily positive 21/84 stack with both five-day slopes rising.
- `QM5_20063` uses a monthly 63-D1 return sign in either direction and no
  seasonal window; this is long-only and summer-gated.
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
- trade_entry: summer-only rising dual-SMA long entry with spread/ATR guards.
- trade_management: season, trend-state and max-hold exits.
- trade_close: framework strategy close or broker ATR stop.

## Safety boundary

This authorizes card, build, strict compile, one RISK_FIXED setfile and Q02
enqueue only. It does not authorize a live setfile, T_Live access,
AutoTrading, deploy manifest, portfolio gate or portfolio manifest change.
