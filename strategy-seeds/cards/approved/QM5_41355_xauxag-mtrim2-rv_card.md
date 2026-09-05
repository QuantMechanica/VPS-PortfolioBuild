---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-XAUXAG-MTRIM2-RV-20260905_S01
variant_id: AI-CODEX-XAUXAG-MTRIM2-RV-20260905_S01
source_id: AI-CODEX-XAUXAG-MTRIM2-RV-20260905
ea_id: QM5_41355
slug: xauxag-mtrim2-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41355_xauxag-mtrim2-rv_card.md
execution_contract_status: APPROVED
created: 2026-09-05
created_by: Research+Development
last_updated: 2026-09-05
g0_status: APPROVED
g0_decision: decisions/2026-09-05_qm5_41355_xauxag_monthly_trim2_reversion_g0.md
source_approval: decisions/2026-09-05_xauxag_monthly_trim2_reversion_source_approval.md
source_author: OpenAI Codex
source_authors: OpenAI Codex; Karsten Schweikert; CME Group; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen
source_citation: "Schweikert (2018), Journal of Banking & Finance 88, DOI 10.1016/j.jbankfin.2017.11.010; CME Group, Gold & Silver Ratio Spread; Moskowitz, Ooi, and Pedersen (2012), Journal of Financial Economics 104(2), DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: governed_composite_source
    citation: "OpenAI Codex (2026). XAU/XAG monthly fixed-trim ratio-return reversion."
    location: strategy-seeds/sources/AI-CODEX-XAUXAG-MTRIM2-RV-20260905/source.md
    quality_tier: governed_source
    role: exact_conjunction_arithmetic_risk_and_lifecycle
  - type: peer_reviewed_relationship_source
    citation: "Schweikert, K. (2018). Are gold and silver cointegrated? Journal of Banking & Finance 88, 44-51."
    location: strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md
    quality_tier: A
    role: state_dependent_gold_silver_relationship
  - type: exchange_education
    citation: "CME Group. Gold & Silver Ratio Spread."
    location: strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md
    quality_tier: B
    role: ratio_definition_and_opposed_leg_spread
  - type: governed_method_source
    citation: "Moskowitz, Ooi, and Pedersen (2012); governed fixed-trim arithmetic packet."
    location: strategy-seeds/sources/MOP-WTI-TRIMMEAN-2026/source.md
    quality_tier: A_method
    role: fixed_sort_and_trim_arithmetic_only
strategy_mechanic: monthly-xauxag-thirteen-synchronized-completed-month-log-ratio-endpoints-twelve-adjacent-returns-fixed-two-per-tail-trimmed-middle-eight-mean-sign-contrarian-equal-notional-basket
sources:
  - "[[sources/AI-CODEX-XAUXAG-MTRIM2-RV-20260905]]"
concepts:
  - "[[concepts/gold-silver-ratio]]"
  - "[[concepts/robust-return-location]]"
  - "[[concepts/market-neutral-relative-value]]"
indicators:
  - "[[indicators/completed-month-log-ratio-return]]"
  - "[[indicators/fixed-trimmed-mean]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, precious-metals, market-neutral-style, relative-value, structural-reversion, fixed-trimmed-mean, monthly-renewal, equal-notional-basket, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41355_XAU_XAG_MTRIM2_RV_D1
symbol: QM5_41355_XAU_XAG_MTRIM2_RV_D1
host_symbol: XAUUSD.DWX
symbol_slot: 0
symbol_slots: [0, 1]
magic: 413550000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: symmetric_opposed_leg
expected_trade_frequency: "Approximately 11-12 completed logical packages per full post-warm-up year; only invalid or near-zero trimmed states remain flat. Q02 must prove at least five completed packages in every full scored year or retire."
expected_trades_per_year_per_symbol: 11
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_SYNTHESIS_RISK
r1_reasoning: "Peer-reviewed state-dependent gold/silver relationship, exchange-defined spread, and governed fixed-trim arithmetic; no source efficacy transfers to this conjunction or CFDs."
r2_mechanical: PASS
r2_reasoning: "Clock, thirteen synchronized endpoints, twelve returns, exact sort, deleted indexes, retained indexes, divisor, epsilon, contrarian side, equal-notional package, aggregate fixed risk, stops, attempt, and lifecycle are deterministic."
r3_data_available: PASS
r3_qualification: CONTINUOUS_CFD_BASIS_RISK
r3_reasoning: "Registered native XAUUSD.DWX and XAGUSD.DWX D1 histories plus MT5 state supply every runtime input."
r4_ml_forbidden: PASS
r4_reasoning: "Timestamps, prices, logarithms, sorting, arithmetic, ATR risk, quotes, positions, deals, and persistent state only."
parameters_to_test: "Locked Q02 baseline only: 13 synchronized completed month-end ratio endpoints; 12 adjacent chronological log-ratio returns; ascending sort; delete indexes 0,1,10,11; average indexes 2..9 with divisor 8; 1e-12 sign epsilon; contrarian ratio side; 1200 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; per-leg ATR(20)*3.5 frozen stops; equal target notionals; 20% notional mismatch ceiling; 40-day stale exit; 1500/500-point spread ceilings."
risk_fixed_backtest: 1000
risk_percent_backtest: 0
portfolio_weight_backtest: 1
news_temporal_mode: QM_NEWS_TEMPORAL_OFF
news_compliance_profile: QM_NEWS_COMPLIANCE_NONE
friday_close_enabled: false
pipeline_phase: Q01
q01_status: NOT_BUILT
q02_status: NOT_ENQUEUED_Q01_PENDING
force_build: true
review_focus: "Falsify a monthly XAU/XAG contrarian return stream whose signal is the exact middle-eight fixed-trim location of synchronized ratio returns. Verify opposed legs, aggregate fixed risk, atomic lifecycle, and no absolute-metal fallback. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbols_period, first_tradable_month_bar, thirteen_consecutive_completed_months, synchronized_month_end_pairs, chronological_log_ratio_returns, ascending_sort, delete_two_each_tail, retain_middle_eight, divisor_eight, contrarian_direction, monthly_attempt_state, equal_notional_pair, aggregate_fixed_risk, atomic_pair_lifecycle, hard_stops_present, friday_close_disabled, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-09-05 and decisions/2026-09-05_qm5_41355_xauxag_monthly_trim2_reversion_g0.md: R1-R4 pass within disclosed synthesis and continuous-CFD risks. Corrected-root dedup found no exact identity across 4,835 registry rows, 1,448 cards, and 45 Wiki nodes; eight fuzzy family matches were manually resolved. A fixed twelve-return fixture makes the trimmed mean sell while nearest Hampel and bisquare siblings buy. This identity decision is not a correlation claim."
---

# QM5_41355 XAU/XAG Monthly Fixed-Trim Reversion

## Hypothesis

Gold and silver share precious-metals drivers but differ in monetary,
safe-haven, and industrial demand. A paired relative-value package can remove
much of their common directional metal exposure. The testable hypothesis is
that the middle-eight trimmed location of twelve synchronized monthly
gold/silver ratio returns overextends and partially reverses next month.

This is not a decorrelation claim. Equal target notional is market-neutral-
style, not guaranteed factor neutrality; Q09 alone owns realized book overlap.

## Source Traceability And Claim Boundary

The approved source is
`strategy-seeds/sources/AI-CODEX-XAUXAG-MTRIM2-RV-20260905/source.md`.
Schweikert supplies relationship evidence, CME supplies spread construction,
and the governed fixed-trim packet supplies arithmetic. No source tests this
conjunction, direction, constants, CFDs, costs, or portfolio correlation.

## Non-Duplicate Decision

The corrected-root receipt found no exact identity. The exact fixed trim is not
a z-score, regression residual, distribution-shift test, median/MAD tail, or
iterative robust M-estimator. The declared fixture makes this estimator
positive and both nearest redescending estimators negative, causing opposed
pair sides. This is a distinct mechanic, not a parameter rename.

## Markets, Timeframe, And Cadence

- Logical symbol: `QM5_41355_XAU_XAG_MTRIM2_RV_D1`.
- Host clock: `XAUUSD.DWX`, D1, slot 0; second leg `XAGUSD.DWX`, slot 1.
- Decide once within 180 minutes of the first synchronized D1 bar after a
  genuine broker-month transition.
- Formation uses thirteen completed synchronized month ends; hold to the next
  month, with a forty-day stale repair.

## Exact Formula

For synchronized positive closes `G[0..12]`, `S[0..12]`, oldest first:

```text
q[i] = ln(G[i]/S[i])
r[i] = q[i+1]-q[i], i=0..11
s = ascending sort of r
t = (s[2]+s[3]+s[4]+s[5]+s[6]+s[7]+s[8]+s[9]) / 8
```

If `t > +1e-12`, sell XAU and buy XAG. If `t < -1e-12`, buy XAU and
sell XAG. Otherwise stay flat. Magnitude never scales risk.

## Rules

- One synchronized broker-month decision and at most one logical pair per
  month; consume the attempt before fallible gates and never retry.
- The symbols, endpoints, return order, ascending sort, exact trim, divisor,
  direction, equal-notional relation, risk, stops, and clocks are immutable.
- The package is valid only while both opposed legs exist with registered
  magics, expected sides, hard stops, and bounded notional mismatch.
- Invalid, stale, asynchronous, nonfinite, or ambiguous state fails closed or
  flattens owned exposure. No single-leg fallback exists.

## Entry Rules

1. Require exact identity, host/timeframe, both magic rows, fixed-risk mode,
   and locked strategy inputs.
2. Process malformed-pair and time exits before entry gates.
3. Synchronize current bars and persist the consumed month before history,
   signal, spread, quote, ATR, sizing, margin, or order submission.
4. Intersect D1 histories and select the latest common close from each of
   exactly thirteen immediately prior consecutive broker months.
5. Compute the exact formula and contrarian side.
6. Require spreads, quotes, ATR(20), metadata, sizing, and margin. Target equal
   absolute USD notionals within 20% mismatch.
7. Open opposed legs with combined frozen-stop risk capped at
   `RISK_FIXED=1000` and `3.5*ATR(20,D1)` stops. Flatten the first immediately
   if the second fails.

## Exit Rules

Close both legs on framework kill switch, first processed tick in a later
broker month, forty elapsed days, or any missing/duplicate/wrong-symbol/
wrong-magic/wrong-side/invalid-stop package state. No signal flip, target,
trail, break-even, partial close, Friday flatten, retry, scale-in, grid,
martingale, or pyramid.

## Filters And Trade Management

Fail closed outside the exact contract. Preserve original hard stops and the
one-package state. Runtime may not read external files, APIs, futures curves,
volume, open interest, forecasts, optimizer output, portfolio state, or
trained artifacts.

## Parameters To Test

Q02 has one baseline: thirteen synchronized ratio endpoints, twelve returns,
ascending sort, delete indexes `0,1,10,11`, average `2..9` over eight,
`1e-12` epsilon, contrarian side, 1,200 D1 bars, 180-minute grace, ten-day
endpoint staleness, `3.5*ATR(20,D1)` stops, equal notionals, 20% mismatch,
forty-day stale hold, and 1,500/500-point spread ceilings.

## Risk

- Q02-Q10 use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1` for the aggregate package.
- Each leg has a frozen hard stop; combined modeled stop loss is capped at the
  single fixed-risk budget. Gap/slippage may exceed modeled loss.
- CFDs add roll, basis, financing, session, spread, and contract risks.
- Pair breaks and one-leg execution failures remain material.
- No live risk mode or live artifact is authorized.

## Data Requirements

Native XAUUSD.DWX/XAGUSD.DWX D1 timestamps, closes, ATR, broker time/month,
quotes, symbol metadata, margin, positions, deals, and persistent state.

## Framework Alignment

| card rule | module |
|---|---|
| identity, month attempt, synchronized endpoint reconstruction | `Strategy_NoTradeFilter` and bounded helpers |
| fixed-trim statistic, contrarian side, pair sizing, stops, atomic open | `Strategy_EntrySignal` |
| package integrity, month and stale closure | `Strategy_ManageOpenPosition` |
| framework reason mapping | `Strategy_ExitSignal` and close helper |
| news disabled on both axes | `Strategy_NewsFilterHook` |

## Validation Plan

1. Match independent fixtures for positive/negative centers, exact retained
   indexes, reflection, nearest-neighbor side disagreement, tie, and ratio
   return identity.
2. Verify synchronization, aggregate fixed risk, equal notionals, atomic
   repair, and lifecycle.
3. Run card lint and strict Q01 compile/build checks.
4. Enqueue one fixed-risk logical-basket Q02 only below the CPU ceiling; do
   not launch a tester manually.

## Failure Conditions And Safety Boundary

Retire on zero packages, fewer than five completed packages in a full scored
year, formula mismatch, leakage, nonpositive economics, invalid risk, missing
stop, atomic defect, nondeterminism, or downstream hard failure. No tuning.

Authorized: deterministic magic allocation, branch-only non-live build,
reference tests, strict Q01, and one paced Q02 enqueue below the CPU ceiling.

Forbidden: optimization, manual tester launch, live/demo/shadow/stress sets,
portfolio-gate edits, correlation waivers, portfolio admission, deploy/live
manifests, `T_Live`, AutoTrading, terminal control, or live use.

## Revision History

| version | date | reason | gate | verdict |
|---|---|---|---|---|
| v1 | 2026-09-05 | initial fixed-trim XAU/XAG reversion card | G0 | APPROVED; build pending |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Source Approval | 2026-09-05 | APPROVED_SOURCE | `decisions/2026-09-05_xauxag_monthly_trim2_reversion_source_approval.md` |
| G0 Research Intake | 2026-09-05 | APPROVED | `decisions/2026-09-05_qm5_41355_xauxag_monthly_trim2_reversion_g0.md` |
| Q01 Build & Spec | TBD | PENDING | TBD |
| Q02 Baseline | TBD | NOT_ENQUEUED | TBD |
