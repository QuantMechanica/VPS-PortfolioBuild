---
card_schema_version: 2
ea_id: QM5_20168
slug: xng-autumn-dualtrend
type: strategy
strategy_id: EIA-MOP-XNG-AUTUMN-DUALTREND-2026_S01
variant_id: EIA-MOP-XNG-AUTUMN-DUALTREND-2026_S01
source_id: EIA-MOP-XNG-AUTUMN-DUALTREND-2026
status: APPROVED
g0_status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20168_xng-autumn-dualtrend_card.md
execution_contract_status: DRAFT
created: 2026-07-26
created_by: Research+Development
last_updated: 2026-07-26
source_citation: "U.S. EIA (2015), Natural gas use features two seasonal peaks per year; Moskowitz, Ooi and Pedersen (2012), Time Series Momentum, JFE 104(2)."
sources:
  - "[[sources/EIA-MOP-XNG-AUTUMN-DUALTREND-2026]]"
strategy_type_flags: [natural-gas, autumn-transition, dual-trend, long-short, atr-hard-stop, low-frequency]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
markets: [commodities, energy, natural_gas]
single_symbol_only: true
logical_symbol: QM5_20168_XNG_AUTUMN_DUALTREND_D1
symbol: XNGUSD.DWX
period: D1
timeframe: D1
timeframes: [D1]
expected_trade_frequency: "Friday-segmented September-November trend packages; approximately 6-13 completed trades/year when either dual-trend state is valid."
expected_trades_per_year_per_symbol: 9
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
q02_work_item_id: bf21065b-53cf-49ce-bbce-9a3f95e550af
review_focus: "Adds autumn natural-gas transition trend exposure distinct from the incumbent XNG RSI pullback. The September-November window and symmetric 21/84-D1 trend state are jointly load-bearing; Q09 alone may establish realized orthogonality."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [low_frequency_sample, natural_gas_gaps, friday_close, magic_schema, risk_mode_dual, portfolio_correlation]
g0_approval_reasoning: "APPROVED under the OWNER commodity/energy sleeve mission: R1 PASS official EIA seasonality plus peer-reviewed JFE trend lineage; R2 PASS fixed September-November window, symmetric 21/84-D1 moving trend stack, ATR stop and deterministic exits; R3 PASS registered XNGUSD.DWX D1 carrier; R4 PASS native MT5 data only with no ML, banned indicator, grid or martingale. Non-duplicate versus QM5_12567 RSI pullback and QM5_20166 autumn channel breakout."
---

# QM5_20168 XNG Autumn Dual-Trend

## Hypothesis

The transition from summer power demand toward winter heating demand can
produce persistent natural-gas repricing, but calendar exposure alone is too
blunt. Trade only when September-November overlaps an aligned, still-moving
completed-bar price trend.

## Source and evidence boundary

The governed packet at
`strategy-seeds/sources/EIA-MOP-XNG-AUTUMN-DUALTREND-2026/source.md` records
official EIA seasonality and peer-reviewed time-series-momentum lineage. Exact
parameters are QM hypotheses, not source claims. No profitability or
correlation claim is imported.

## Rules

### Entry rules

- Exact carrier `XNGUSD.DWX`, D1, magic slot 0.
- Evaluate once per new D1 bar during September, October, and November.
- BUY when completed close is above SMA(21), SMA(21) is above SMA(84), and
  both averages exceed their values five completed bars earlier.
- SELL under the exact mirror image.
- Require spread no greater than 1000 points and valid ATR(20).
- Enter with a frozen `3.5 * ATR(20)` hard stop and no take profit.
- One position per magic and one entry attempt per broker D1 bar. Friday close
  remains enabled, allowing weekly trend packages.

### Exit rules

- Close outside September-November.
- Close when the completed-bar state no longer supports the position side.
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

All baseline parameters are locked. Changing the season, stack, or exits is a
new card, not a rescue sweep.

## Non-duplicate decision

- `QM5_12567` buys short-horizon cumulative-RSI pullbacks; this uses no
  oscillator, oversold condition, or mean-reversion entry.
- `QM5_20166` is an autumn price-channel breakout; this card requires an
  aligned fast/slow state and supports either direction without channel levels.
- Winter, spring, and summer dual-trend cards have disjoint seasonal clocks.

## Risk, acceptance and kill criteria

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Retire below five completed trades/year at Q02. Fail on
wrong-season entry, trend-side mismatch, repeated same-bar entry,
nondeterminism, risk mismatch, or governed PF/DD failure. Q09 correlation is
authoritative; structural difference does not guarantee decorrelation.

## Framework alignment

- no_trade: exact carrier, timeframe, slot and locked-input validation.
- trade_entry: autumn symmetric dual-SMA trend entry with spread/ATR guards.
- trade_management: season, directional state and max-hold exits.
- trade_close: framework strategy close or broker ATR stop.

## Safety boundary

This authorizes card, build, strict compile, one RISK_FIXED setfile and Q02
enqueue only. It does not authorize a live setfile, T_Live access,
AutoTrading, deploy manifest, portfolio gate or portfolio manifest change.
