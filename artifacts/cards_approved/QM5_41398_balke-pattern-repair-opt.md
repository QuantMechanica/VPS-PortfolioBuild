---
ea_id: QM5_41398
slug: balke-pattern-repair-opt
type: strategy
source_id: 6e967762-b26d-59a3-b076-35c17f2e7c36
parent_ea_id: QM5_13213
parent_slug: balke-gmt3-range-breakout
implementation_parent_ea_id: QM5_41097
implementation_parent_source: framework/EAs/QM5_41097_balke-gmt3-range-breakout-opt/QM5_41097_balke-gmt3-range-breakout-opt.mq5
g0_status: APPROVED
g0_authority: "OWNER direct chat: dann nächster schritt; decisions/2026-09-09_balke_pattern_recovery.md"
execution_contract_status: NOT_APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
period: H1
target_symbols: [USDJPY.DWX]
expected_trades_per_year_per_symbol: 140
last_updated: 2026-09-09
---

# QM5_41398 — Balke pattern repair measurement instrument

OWNER-authorized fresh DL-089 measurement sibling of QM5_13213. This is a repair
lineage of frozen instrument QM5_41097, not a new independent strategy or an
approved live EA. R1-R4 are inherited from that existing approved source lineage;
140 trades/year is the inherited expectation, not a new measured result.

## Mechanical contract

Use the existing A1-fixed, side-effect-free straddle plan from QM5_41097. The
03:00–06:00 GMT+3 range, ATR(14) range band 0.4–2.5, 36-bar range scan, trailing
trigger +1R, and 18:00 GMT+3 exit are unchanged. Preserve existing news and
Friday-close mechanics, sizing, order types and pending-order behavior. Trade
the chart symbol (_Symbol); no broker-symbol literal is added to the source.

The only source-level functional integration change is
`#define QM_PATTERN_PERMISSION_EA_MANAGED` before QM_Common. It prevents duplicate
framework pattern ownership while the existing plan → permission → decision →
placement flow applies the six `opt_pp_buy1..3` / `opt_pp_sell1..3` veto slots.
The repaired canonical include implements predicates 33/34 using three closed
candles. Pattern reference is compile-time D1, shift 1; neither becomes an input.

## Parameters and controls

All six slots default to zero. Nonzero IDs must be implemented or initialization
fails closed. The pattern census varies one predicate on one side at a time.
The existing numeric parameters remain at their parent defaults; no numeric
sweep is authorized by this repair. Explicitly pin every EA-declared input in
the baseline set, including news, Friday-close, stress=0 and seed=42.

Backtest only: RISK_FIXED=1000, RISK_PERCENT=0, PORTFOLIO_WEIGHT=1, magic slot 0.
News temporal PRE30_POST30, compliance DXZ, max age 336h, impact high, legacy OFF;
Friday close enabled at broker hour 21. No tuning of these framework settings.

The following table is consumed by the canonical setfile generator. The five
identity/risk assignments are generated from the registry and backtest contract.
Enum values below are the actual MT5 numeric values, not symbolic .set tokens.

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

## Measurement and refutation

Require native COMPILE_OK, deterministic code review, a fresh neutral Q02 and
the repaired 535-fixture native harness proof before economic matrix admission.
Use a new program and hashes; adopt no old economic cells without explicit
include-closure equivalence evidence. Default recovery budget: 1,085 annual
cells (155 arms × 2019–2025) plus four sealed WF combinations, not simultaneous
unbounded dispatch. Preserve the original DL-089 R2DD, quorum, activity floor,
multiple-testing ledger and no-filter control. B2/B5 remain retired.

Refutation: incomplete provenance or native setup fails stops admission; a filter
that fails the unchanged selection/activity/WF contract is not a winner. No
performance conclusion follows from compile or fixture PASS. Historical trials
remain disclosed; 2019–2025 is not relabeled untouched out-of-sample data.

## Framework alignment and review focus

- No-trade: inherited Strategy_NoTradeFilter and framework kill/news/Friday rules.
- Entry: Strategy_BuildStraddlePlan → Census_Permission → QM_PPS_Decide; both legs
  are placed only after the common decision. Preserve day-completion behavior.
- Management: inherited Strategy_ManageOpenPosition; no threshold changes.
- Close: inherited Strategy_ExitSignal and pending-order cleanup; no changes.
- Compile closure: exact canonical includes, repaired PatternPermission hash
  `101cc2230e32d88970a89aadea167a8cece2a64074f450a3946f7302dcd2039e` (LF bytes).
- Review must flag inherited unrelated defects separately, never silently alter
  mechanics to improve the comparison. This sibling adds no diversification.

No live, demo-account, execution-contract or portfolio approval is granted.
