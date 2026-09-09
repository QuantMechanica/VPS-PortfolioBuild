---
ea_id: QM5_41405
slug: balke-clock-audit-opt
type: strategy
source_id: 6e967762-b26d-59a3-b076-35c17f2e7c36
parent_ea_id: QM5_41398
implementation_parent_source: framework/EAs/QM5_41398_balke-pattern-repair-opt/QM5_41398_balke-pattern-repair-opt.mq5
status: DRAFT
g0_status: APPROVED
g0_authority: "Build-only authority: OWNER-requested deterministic router task d444a7a8-f998-4ab2-820a-6f7bc017d475, S4 explicit new sibling and three inputs; this card records that authority, not an agent-issued promotion."
execution_contract_status: NOT_APPROVED
pipeline_phase: G0
period: H1
target_symbols: [USDJPY.DWX]
expected_trades_per_year_per_symbol: 140
last_updated: 2026-09-09
---

# QM5_41405 — Balke clock comparison measurement instrument

Draft implementation specification for REVIEW. Numeric identity 41405 was reserved
through canonical farmctl reserve-ea-ids for task d444a7a8. Build is blocked until
the deterministic magic precondition task installs and verifies the required tuple.
No live authority. Preserve QM5_41398 source and binary.

## Mechanics and frozen control

Copy the parent mechanism exactly, including existing permission profile, news,
Friday close, risk sizing, range ATR band, trailing and day-consumption behavior.
Do not repair the known permission-intent/day-completion defect in the control.
Default clock = fixed UTC+3; range closed H1 bars 03:00 through 05:59; stops placed
in hour 06; cancel/flat at hour 18. Use _Symbol and the declared input timeframe;
no broker-symbol literals in EA code. A single open position, no martingale/grid,
no HFT, no ML. This instrument is for non-live measurement only.

## Three additional inputs (declared parameter count +3)

1. strategy_clock_mode: GMT3_FIXED=0, BROKER_DST=1, CET_LOCAL=2. GMT3_FIXED is
   QM_BrokerToUTC(t)+3h; BROKER_DST is raw broker time; CET_LOCAL converts broker
   to UTC then Europe/Berlin (UTC+1 winter, UTC+2 from last Sunday March 01:00 UTC
   until last Sunday October 01:00 UTC). Apply the same helper to range bars,
   day keys, order placement and evening exit. Never approximate EU DST by US DST.
2. strategy_outside_range_rule: AS_IS=0, SKIP_DAY=1,
   MARKET_ENTRY_IN_BREAKOUT_DIRECTION=2, OPPOSITE_STOP_ONLY=3. Evaluate outside
   against the buffered trigger levels using executable Ask > buy trigger or
   Bid < sell trigger. AS_IS preserves both parent stop attempts. SKIP_DAY consumes
   the day without placing either leg. MARKET_ENTRY sends only the breakout-side
   market order after normal permission/news/risk checks. OPPOSITE_STOP_ONLY sends
   only the still-valid opposite stop and consumes the day on the same permission
   convention as the parent. For crossed/bad quotes or both sides outside, non-AS_IS
   modes skip the day. Equality and minimum-stop-distance violations remain governed
   by the existing framework; quote evidence must distinguish them from strict outside.
3. strategy_entry_buffer_pct: 0, 5, 10. Buffer = range_height * pct / 100;
   buy trigger = high + buffer, sell trigger = low - buffer. Initial SL stays at
   the original opposite range boundary. No SL buffer. Parent trailing/recross
   mechanics stay unchanged to isolate these three declared levers.

All three inputs must have range validation and mechanical use sites. Defaults
0/0/0 must reproduce the parent economic deal list (identity/magic necessarily
differs). Keep six parent pattern slots zero in every clock-comparison cell.

## Risk and news

RISK_FIXED=1000, RISK_PERCENT=0, PORTFOLIO_WEIGHT=1, seed=42, stress=0.
News PRE30_POST30, DXZ compliance, high impact, max staleness 336h. Mandatory
blackout remains active; no stale-calendar weakening. Live code must never read
the backtest news archive. Any later deployable child must satisfy FTMO + DXZ,
at most 5% daily DD and 10% total DD; this comparison cannot authorize deployment.

## Measurement and falsification

H-CLOCK: broker/EU clock may recover winter edge lost by fixed +3. Refute if PF
and expectancy per winter month do not improve at least 10% relative across
2018–2025. Report handling of zero/negative denominators before measuring.
H-OUTSIDE: fade-only days lose money; refute if their aggregate P&L is nonnegative.
Baseline 2018-2022 has seven confirmed fade-only order days, one actual trade,
net -869.92; this does not prove a generalizable benefit from skipping.
H-BUFFER: buffer reduces false breakouts; refute if neither 5 nor 10 beats zero
on both PF and net in both halves (2018-2021 / 2022-2025).
Report every cell's yearly frequency (floor 5/year, inherited expectation ~140/year),
gross and DXZ $5/lot RT net, PF, equity maxDD, per-year PF, winter/summer PF.
Only eight calendar years with partial 2018; annotate exposure days.

First fidelity cell uses EXACT original baseline window 2018-07-02 to 2022-12-31
exclusive, Model=4, exact sealed parent inputs and include identity. An additional
full-window 0/0/0 control is one of the 36 full-window cells. Never compare full
2018-2025 deals for identity against the shorter 2018-2022 baseline.

Measure fidelity cell runtime first; report projection before scheduling the 36
remaining cells. Historical parent runtime is 449.167 seconds for 4.5 years;
linear 7.5-year projection is ~12.5min per cell / ~7.5 aggregate worker-hours
for 36 cells, plus fidelity. This is GELB cost information, not a measured sibling
runtime. Only factory-managed COMPILE_EA and backtest claims may execute.

The captions-only note VIDEO_Pay-JP34YSI_BALKE_USDJPY_CLOCK_2026-09-09.md reports
00:00-07:30 as Balke's actual USDJPY window, with different trailing/filter rules.
Clock offset remains unresolved; retain all three clock hypotheses. That source
replication requires a separate minute-granularity mechanism and is not silently
added to this three-input comparison. Do not claim comparison to Balke's live PF.

## Parameters and controls

| param | default |
| --- | --- |
| qm_rng_seed | 42 |
| qm_news_temporal | 3 |
| qm_news_compliance | 1 |
| qm_news_stale_max_hours | 336 |
| qm_news_min_impact | high |
| qm_news_mode_legacy | 0 |
| qm_friday_close_enabled | true |
| qm_friday_close_hour_broker | 21 |
| qm_stress_reject_probability | 0.0 |
| strategy_range_start_hour | 3 |
| strategy_range_end_hour | 6 |
| strategy_exit_hour | 18 |
| strategy_atr_period | 14 |
| strategy_min_range_atr_mult | 0.4 |
| strategy_max_range_atr_mult | 2.5 |
| strategy_trail_trigger_r | 1.0 |
| strategy_range_scan_bars | 36 |
| opt_pp_buy1 | 0 |
| opt_pp_buy2 | 0 |
| opt_pp_buy3 | 0 |
| opt_pp_sell1 | 0 |
| opt_pp_sell2 | 0 |
| opt_pp_sell3 | 0 |
| strategy_clock_mode | 0 |
| strategy_outside_range_rule | 0 |
| strategy_entry_buffer_pct | 0.0 |
