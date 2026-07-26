---
card_schema_version: 2
ea_id: QM5_20166
slug: xng-shoulder-brk
type: strategy
strategy_id: EIA-XNG-SHOULDER-2026_S05
variant_id: EIA-XNG-SHOULDER-2026_S05
source_id: EIA-XNG-SHOULDER-2026
status: DRAFT
g0_status: APPROVED
execution_contract_status: DRAFT
created: 2026-07-26
created_by: Research+Development
source_authors: "U.S. Energy Information Administration"
strategy_mechanic: xng-shoulder-season-compression-breakout
source_citation: "U.S. EIA (2015), Natural gas consumption, production respond to seasonal changes."
source_citations:
  - type: official_government_source
    citation: "U.S. Energy Information Administration (2015). Natural gas consumption, production respond to seasonal changes."
    location: "https://www.eia.gov/todayinenergy/detail.php?id=22892; governed packet strategy-seeds/sources/EIA-XNG-SHOULDER-2026/source.md"
    quality_tier: A
    role: seasonal-demand-transition
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
markets: [commodities, energy, natural_gas]
single_symbol_only: true
logical_symbol: XNGUSD.DWX
symbol: XNGUSD.DWX
period: D1
timeframe: D1
timeframes: [D1]
expected_trade_frequency: "Approximately 5-15 trades/year; Q02 must prove or retire."
expected_trades_per_year_per_symbol: 8
expected_pf: 1.01
expected_dd_pct: 25.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PASS
q02_status: NOT_STARTED
g0_approval_reasoning: "OWNER 2026-07-26 commodity/energy sleeve mission: R1 official EIA governed source; R2 fixed seasonal window, channel, compression, exit and stop; R3 registered XNGUSD.DWX D1; R4 native OHLC/ATR only, no ML, grid, martingale or external runtime data."
---

# XNG Shoulder Transition Compression Breakout

## Hypothesis

EIA documents two natural-gas demand peaks separated by shoulder transitions.
Those transitions can compress the D1 range before the market reprices toward
the next demand regime. During March-April and September-October, enter in the
direction of a completed close outside the previous 20-bar range, provided
that range's average daily width is no more than 0.8 of completed ATR(20).
This translation is a falsifiable QM hypothesis, not an EIA performance claim.

## Non-Duplicate Decision

QM5_12567 is a two-day cumulative-RSI commodity pullback. QM5_12595 fades
failed shoulder rallies; QM5_12703 and QM5_12705 are directional calendar
shorts; QM5_12588 is a summer-only long squeeze. This candidate is symmetric,
transition-month-only, and follows rather than fades a compressed-range break.

## Entry Rules

Exact XNGUSD.DWX/D1/slot 0. In March-April or September-October, require the
mean high-low width of shifts 2-21 to be at most 0.8 ATR(20) at shift 1. Buy
when Close[1] exceeds their high; sell when it is below their low. Require
spread at most 2,500 points and attach a frozen 3 ATR stop.

## Exit Rules

Exit after 15 calendar days, at the end of an authorized month, at the broker
hard stop, framework kill switch, or governed Friday close. No target,
trailing, break-even, scale-in, grid, or martingale.

## Position Sizing

V5 fixed-risk sizing from the 3 ATR stop. Q02 uses `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

## Rules

The seasonal months, symmetric breakout direction, completed-bar channel,
compression ceiling, ATR stop, maximum hold, spread cap, symbol, timeframe,
and fixed-risk mode are the complete locked baseline. Any change requires a
new card and full requalification.

## Risk

Natural gas has gap, roll/basis, financing, weather-shock, and squeeze risk.
The continuous CFD is not the EIA physical market or a matched futures
contract. The frozen stop limits modeled entry risk but cannot guarantee fill
through a gap.

## Parameters To Test

All baseline parameters are locked: channel 20, ATR 20, compression 0.8,
stop 3 ATR, maximum hold 15 days, spread ceiling 2,500 points.

## Kill Criteria

Retire below five trades/year, on zero trades, invalid risk mode, wrong-side
execution, missing stop/exit, nondeterminism, or any governed PF/DD failure.

## Framework Alignment

- no_trade: exact symbol/timeframe/slot and parameter validity.
- trade_entry: completed-bar seasonal compression breakout.
- trade_management: season-end and 15-day exits.
- trade_close: framework kill switch, Friday close, hard stop.

## Safety Boundary

Build and paced Q02 only. No live set, deployment, AutoTrading, T_Live,
portfolio gate, T_Live manifest, correlation waiver, or certification claim.
