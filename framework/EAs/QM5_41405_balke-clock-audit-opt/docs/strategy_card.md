---
ea_id: QM5_41405
slug: balke-clock-audit-opt
type: strategy
source_id: 6e967762-b26d-59a3-b076-35c17f2e7c36
parent_ea_id: QM5_41398
implementation_parent_source: framework/EAs/QM5_41398_balke-pattern-repair-opt/QM5_41398_balke-pattern-repair-opt.mq5
status: APPROVED
g0_status: APPROVED
g0_authority: "Build-and-measure authority for a NON-LIVE measurement sibling: OWNER 2026-09-09 (Balke USDJPY window/clock/buffer audit, 'beauftrage Astra'), OWNER 2026-09-10 ~21:45Z ('beste Range per Backtests selbst herausfinden ... Umsetzung') and 2026-09-10 ~20:45Z ('Umsetzen'), executed through router tasks d444a7a8 (APPROVED partial 2026-09-10) and dee2fc76 (stage 2). Stage-A result docs/research/BALKE_WINDOW_SWEEP_RESULT_2026-09-11.md fixes the window. Card amended 2026-09-11 by the Orchestrator; no live, deployment or gate authority."
execution_contract_status: NOT_APPROVED
pipeline_phase: G0
period: H1
target_symbols: [USDJPY.DWX]
expected_trades_per_year_per_symbol: 75
last_updated: 2026-09-11
g0_approval_reasoning: "R1-R4 inherited from the approved parent lineage QM5_13213/41097/41398 (same source, same pool); stage-2 measurement sibling on the tool-adjudicated stage-A winner s0_l8 (OWNER 2026-09-09/10 directives), six declared inputs, pre-registered 350-cell matrix with refutation criteria; non-live measureme"
expected_pf: 1.2
expected_dd_pct: 15.0
r1_track_record: TIER_C
r1_reasoning: "existing card attribution is canonical source lineage; R1 is informational and non-gating (2026-07-23)."
r2_mechanical: PASS
r2_reasoning: "all six new inputs (clock mode, outside-range rule, entry buffer, range band, range bar period, range end minute) are enumerated deterministic switches with explicit use sites and default values reproducing the parent; no discretionary judgment anywhere in the spec."
r3_data_available: PASS
r3_reasoning: "target symbol USDJPY.DWX on H1 is a standard DWX MT5 instrument/timeframe already used by the approved parent lineage QM5_13213/41097/41398."
r4_ml_forbidden: PASS
r4_reasoning: "card explicitly states single open position, no martingale/grid, no HFT, no ML; all logic is rule-based clock/window/buffer arithmetic with no learning or adaptive-PnL components."
---
# QM5_41405 — Balke stage-2 measurement instrument (clock, outside-range rule, buffer, range band, minute-granular range)

Measurement sibling of QM5_41398 on the stage-A winning window. Numeric identity 41405 and
magic 414050000 (USDJPY.DWX slot 0) are allocated (task 2e7d5619 APPROVED). Preserve QM5_41398
source, binary, sets and verdicts. Non-live measurement only; no deployment authority.

Source and evidence chain (2026): stage-A plan docs/research/BALKE_WINDOW_SWEEP_PLAN_2026-09-09.md,
stage-A result docs/research/BALKE_WINDOW_SWEEP_RESULT_2026-09-11.md (winner s0_l8: DEV 1.96,
plateau 1.56, OOS pooled costed PF 1.21), clock audit docs/ops/evidence/BALKE_CLOCK_AUDIT_2026-09-09.md,
captions evidence docs/research/VIDEO_Pay-JP34YSI_BALKE_USDJPY_CLOCK_2026-09-09.md of René Balke,
"My Settings for the Range Breakout EA in USDJPY and GBPUSD", https://www.youtube.com/watch?v=Pay-JP34YSI
(published 2024, captions [00:08:44]-[00:09:17]: range 00:00-07:30 broker server time, delete and close
18:00, no range filter, no trailing/break-even, max one buy and one sell, SL opposite side, no TP).

## Mechanics and frozen control

Copy the parent mechanism exactly (permission profile, news, Friday close, risk sizing, range ATR
band, trailing, day consumption). Do not repair the known permission-intent/day-completion defect.
Parent defaults changed ONLY for the window: strategy_range_start_hour=0, strategy_range_end_hour=8,
strategy_exit_hour=18 (stage-A winner s0_l8 on the fixed UTC+3 clock: closed H1 range bars 00:00
through 07:59, stops placed in hour 08, cancel/flat at hour 18). Use _Symbol and the declared input
timeframe (H1 chart; range bars from the range-bar-period input); no broker-symbol literals. A single
open position, no martingale/grid, no HFT, no ML. Six parent pattern slots stay zero in every cell.

## Six additional inputs (declared parameter count +6); all defaults reproduce the parent s0_l8 cells

1. strategy_clock_mode: GMT3_FIXED=0 (default; QM_BrokerToUTC(t)+3h), BROKER_DST=1 (raw broker
   time, NY-close GMT+2/+3), CET_LOCAL=2 (broker -> UTC -> Europe/Berlin: UTC+1 winter, UTC+2 from
   last Sunday March 01:00 UTC to last Sunday October 01:00 UTC). Same helper for range bars, day
   keys, placement and evening exit. Never approximate EU DST by US DST.
2. strategy_outside_range_rule: AS_IS=0 (default; both parent stop attempts), SKIP_DAY=1,
   MARKET_ENTRY_IN_BREAKOUT_DIRECTION=2, OPPOSITE_STOP_ONLY=3. Outside = executable Ask > buy trigger
   or Bid < sell trigger at placement. Crossed/bad quotes or both sides outside: non-AS_IS modes skip
   the day. Minimum-stop-distance violations stay governed by the framework and are logged apart.
3. strategy_entry_buffer_points: 0 (default) or 20. Buffer in MetaTrader points (Balke's "order
   buffer points"); buy trigger = high + buffer, sell trigger = low - buffer. Initial SL stays at the
   original opposite range boundary; no SL buffer.
4. strategy_range_band_enabled: true (default; parent ATR(14) band 0.4-2.5) or false (no range-size
   filter, Balke's published setting).
5. strategy_range_bar_period: H1=0 (default), M30=1, M5=2. Range high/low from closed bars of this
   period inside the window; the day key and hour logic stay on the chosen clock.
6. strategy_range_end_minute: 0 (default) or 30. With M30/M5 range bars the range ends at
   end_hour:end_minute and stops are placed on the first tick after it (Balke 07:30).
Every input needs range validation and mechanical use sites. Defaults must reproduce the parent's
s0_l8 stage-A deal lists per year (identity/magic necessarily differs) - cell 0 identity proof.

## Pre-registered matrix (own program BALKE2_QM5_41405_USDJPY_DWX_2019_2025, per-year cells 2019-2025)

48 configs on s0_l8/exit 18: 3 clock modes x 4 outside rules x buffer {0, 20} x band {on, off},
plus 2 Balke configs (range 00:00-07:30 via M30 bars + end_minute 30, exit 18, band off, buffer 0 and
20, max one buy + one sell as in the parent) = 50 configs x 7 years = 350 cells (~17 h at 2 lanes,
GELB cost). Scoring, DEV 2019-2022 / OOS 2023-2025, admissibility (>= 10 entry days every year,
>= 5 trades every year, mean >= 40) and plateau logic exactly as the stage-A plan sections 4-5;
plateau neighbourhood here = adjacent buffer and band values within the same clock/outside cell.
Refutation criteria (fixed before any cell runs): H-CLOCK: BROKER_DST or CET plateau not >= 1.10 x
GMT3_FIXED -> keep the fixed clock. H-OUTSIDE: no rule beats AS_IS by >= 1.10 -> keep AS_IS.
H-BUFFER: 20 points not >= 1.10 x 0 -> keep 0. H-BAND: band off not >= 1.10 x on -> keep on.
H-BALKE: the Balke configuration not >= 1.10 x the best fixed-clock configuration -> keep ours.
Report per cell: trades, entry days, gross and DXZ 5 USD/lot RT costed net, PF, maxDD, score,
winter/summer split; report fade-only-day economics under every outside rule.
Cell 0 (all defaults) must reproduce the stage-A s0_l8 cells 2019-2025 exactly before the matrix is
enqueued; runtime of cell 0 is measured and the full projection reported first.

## Risk and news

RISK_FIXED=1000, RISK_PERCENT=0, PORTFOLIO_WEIGHT=1, seed=42, stress=0. News PRE30_POST30, DXZ
compliance, high impact, max staleness 336h; mandatory blackout active. Live code must never read
the backtest news archive. This instrument cannot authorize deployment; any deployable child needs
its own Q02-Q13 chain and must satisfy FTMO + DXZ limits (5% daily, 10% total DD).

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
| strategy_range_start_hour | 0 |
| strategy_range_end_hour | 8 |
| strategy_exit_hour | 18 |
| strategy_atr_period | 14 |
| strategy_min_range_atr_mult | 0.4 |
| strategy_max_range_atr_mult | 2.5 |
| strategy_trail_trigger_r | 1.0 |
| strategy_range_scan_bars | 36 |
| strategy_clock_mode | 0 |
| strategy_outside_range_rule | 0 |
| strategy_entry_buffer_points | 0 |
| strategy_range_band_enabled | true |
| strategy_range_bar_period | 0 |
| strategy_range_end_minute | 0 |
| opt_pp_buy1..3 / opt_pp_sell1..3 | 0 |
