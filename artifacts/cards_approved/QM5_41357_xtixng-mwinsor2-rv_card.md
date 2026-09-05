---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-XTIXNG-MWINSOR2-RV-20260906_S01
variant_id: AI-CODEX-XTIXNG-MWINSOR2-RV-20260906_S01
source_id: AI-CODEX-XTIXNG-MWINSOR2-RV-20260906
ea_id: QM5_41357
slug: xtixng-mwinsor2-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41357_xtixng-mwinsor2-rv_card.md
execution_contract_status: APPROVED
created: 2026-09-06
created_by: Research+Development
last_updated: 2026-09-06
g0_status: APPROVED
g0_decision: decisions/2026-09-06_qm5_41357_xtixng_monthly_winsor2_reversion_g0.md
source_approval: decisions/2026-09-06_xtixng_monthly_winsor2_reversion_source_approval.md
source_author: OpenAI Codex
source_authors: OpenAI Codex; Jose A. Villar; Frederick L. Joutz; David J. Ramberg; John E. Parsons; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen
source_citation: "Villar and Joutz (2006), The Relationship Between Crude Oil and Natural Gas Prices, U.S. EIA; Ramberg and Parsons (2012), The Energy Journal 33(2), DOI 10.5547/01956574.33.2.2; Moskowitz, Ooi, and Pedersen (2012), Journal of Financial Economics 104(2), DOI 10.1016/j.jfineco.2011.11.003; governed fixed-tail Winsor arithmetic packet."
source_citations:
  - type: governed_composite_source
    citation: "OpenAI Codex (2026). XTI/XNG monthly fixed-tail Winsor ratio-return reversion."
    location: strategy-seeds/sources/AI-CODEX-XTIXNG-MWINSOR2-RV-20260906/source.md
    quality_tier: governed_source
    role: exact_conjunction_arithmetic_risk_and_lifecycle
  - type: government_and_peer_reviewed_relationship_source
    citation: "Villar, J. A., and Joutz, F. L. (2006), U.S. EIA; Ramberg, D. J., and Parsons, J. E. (2012), The Weak Tie Between Natural Gas and Oil Prices, The Energy Journal 33(2), 13-35."
    location: "strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md; DOI 10.5547/01956574.33.2.2"
    quality_tier: A_government_and_peer_reviewed
    role: physical_economic_linkage_and_binding_instability
  - type: governed_method_source
    citation: "Moskowitz, Ooi, and Pedersen (2012); governed fixed-tail Winsor arithmetic packet."
    location: strategy-seeds/sources/MOP-WTI-WINSOR-2026/source.md
    quality_tier: A_method
    role: fixed_sort_and_winsor_arithmetic_only
strategy_mechanic: monthly-xtixng-thirteen-synchronized-completed-month-log-ratio-endpoints-twelve-adjacent-returns-fixed-two-per-tail-winsorized-mean-sign-contrarian-equal-notional-basket
sources:
  - "[[sources/AI-CODEX-XTIXNG-MWINSOR2-RV-20260906]]"
concepts:
  - "[[concepts/oil-gas-ratio]]"
  - "[[concepts/robust-return-location]]"
  - "[[concepts/market-neutral-relative-value]]"
indicators:
  - "[[indicators/completed-month-log-ratio-return]]"
  - "[[indicators/fixed-tail-winsorized-mean]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, natural-gas, market-neutral-style, relative-value, structural-reversion, fixed-tail-winsorized-mean, monthly-renewal, equal-notional-basket, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, crude_oil, natural_gas]
timeframes: [D1]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41357_XTI_XNG_MWINSOR2_RV_D1
symbol: QM5_41357_XTI_XNG_MWINSOR2_RV_D1
host_symbol: XTIUSD.DWX
symbol_slot: 0
symbol_slots: [0, 1]
magic: 413570000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: symmetric_opposed_leg
expected_trade_frequency: "Approximately 11-12 completed logical packages per full post-warm-up year; only invalid or near-zero Winsor states remain flat. Q02 must prove at least five completed packages in every full scored year or retire."
expected_trades_per_year_per_symbol: 11
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: TIER_C
r1_reasoning: "existing card attribution is canonical source lineage; R1 is informational and non-gating (2026-07-23)."
r2_mechanical: PASS
r2_reasoning: "Clock, thirteen synchronized endpoints, twelve returns, exact sort, replaced indexes, boundary weights, divisor, epsilon, contrarian side, equal-notional package, aggregate fixed risk, stops, attempt, and lifecycle are deterministic."
r3_data_available: PASS
r3_qualification: CONTINUOUS_CFD_BASIS_RISK
r3_reasoning: "Registered native XTIUSD.DWX and XNGUSD.DWX D1 histories plus MT5 state supply every runtime input."
r4_ml_forbidden: PASS
r4_reasoning: "Timestamps, prices, logarithms, sorting, arithmetic, ATR risk, quotes, positions, deals, and persistent state only."
parameters_to_test: "Locked Q02 baseline only: 13 synchronized completed month-end ratio endpoints; 12 adjacent chronological log-ratio returns; ascending sort; replace indexes 0,1 by index 2 and indexes 10,11 by index 9; average all 12 capped observations with divisor 12; 1e-12 sign epsilon; contrarian ratio side; 1200 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; per-leg ATR(20)*3.5 frozen stops; equal target notionals; 20% notional mismatch ceiling; 40-day stale exit; 1500/3000-point spread ceilings."
risk_fixed_backtest: 1000
risk_percent_backtest: 0
portfolio_weight_backtest: 1
news_temporal_mode: QM_NEWS_TEMPORAL_OFF
news_compliance_profile: QM_NEWS_COMPLIANCE_NONE
friday_close_enabled: false
pipeline_phase: Q02
q01_status: COMPILE_OK
q02_status: ENQUEUED_PENDING
force_build: true
review_focus: "Falsify a monthly XTI/XNG contrarian return stream whose signal is the exact fixed two-per-tail Winsorized location of synchronized ratio returns. Verify opposed legs, aggregate fixed risk, atomic lifecycle, and no single-leg or outright-energy fallback. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbols_period, first_tradable_month_bar, thirteen_consecutive_completed_months, synchronized_month_end_pairs, chronological_log_ratio_returns, ascending_sort, replace_two_each_tail, retain_all_twelve_after_capping, divisor_twelve, contrarian_direction, monthly_attempt_state, equal_notional_pair, aggregate_fixed_risk, atomic_pair_lifecycle, hard_stops_present, friday_close_disabled, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-09-06 and decisions/2026-09-06_qm5_41357_xtixng_monthly_winsor2_reversion_g0.md: R1-R4 pass within disclosed synthesis and continuous-CFD risks. Corrected-root dedup found no exact identity across 4,837 registry rows, 1,450 cards, and 45 Wiki nodes; nine fuzzy family signals were manually resolved. The same-carrier daily H-L and single-WTI divergence systems have different state, topology, and direction; the same-estimator precious-metals system has a different economic carrier. This identity decision is not a correlation claim."
---

# QM5_41357 XTI/XNG Monthly Fixed-Tail Winsorized Reversion

## Hypothesis

Crude oil and natural gas share production, substitution, drilling, finance,
transport, and LNG links, while gas retains strong regional, storage, weather,
and infrastructure drivers. A paired relative-value package can reduce their
common directional energy exposure. The testable hypothesis is that the two-
per-tail Winsorized location of twelve synchronized monthly oil/gas ratio
returns overextends and partially reverses next month.

This is not a decorrelation claim. Equal target notional is market-neutral-
style, not guaranteed factor neutrality; Q09 alone owns realized book overlap.

## Source Traceability And Claim Boundary

The approved source is
`strategy-seeds/sources/AI-CODEX-XTIXNG-MWINSOR2-RV-20260906/source.md`.
Villar/Joutz and Ramberg/Parsons supply oil/gas linkage evidence and binding
adverse evidence that the relationship is weak and time varying. The governed
fixed-tail Winsor packet supplies arithmetic only. No source tests this
conjunction, direction, constants, CFDs, costs, equal-notional construction,
or portfolio correlation.

## Non-Duplicate Decision

The corrected-root receipt found no exact identity. `QM5_41192` summarizes
17-23 daily oil/gas returns from one month with an inclusive pairwise
pseudomedian; this rule summarizes twelve disjoint monthly returns over a year
with fixed order-statistic capping. `QM5_41340` is single-leg WTI trend with a
read-only XNG annual-sign veto; this rule trades both legs and fades the
relative state. `QM5_41356` shares the estimator but owns a precious-metals
carrier. Exact fixed-tail Winsorization is also distinct from tail deletion
and iterative residual reweighting. The declared fixture makes its center
negative while the nearest trimmed center is positive. The combined carrier,
horizon, estimator, side, and two-leg lifecycle define a new economic identity.

## Markets, Timeframe, And Cadence

- Logical symbol: `QM5_41357_XTI_XNG_MWINSOR2_RV_D1`.
- Host clock: `XTIUSD.DWX`, D1, slot 0; second leg `XNGUSD.DWX`, slot 1.
- Decide once within 180 minutes of the first synchronized D1 bar after a
  genuine broker-month transition.
- Formation uses thirteen completed synchronized month ends; hold to the next
  month, with a forty-day stale repair.

## Exact Formula

For synchronized positive oil closes `O[0..12]` and gas closes `G[0..12]`,
oldest first:

```text
q[i] = ln(O[i]/G[i])
r[i] = q[i+1]-q[i], i=0..11
s = ascending sort of r
w = (3*s[2]+s[3]+s[4]+s[5]+s[6]+s[7]+s[8]+3*s[9]) / 12
```

If `w > +1e-12`, sell XTI and buy XNG. If `w < -1e-12`, buy XTI and
sell XNG. Otherwise stay flat. Magnitude never scales risk.

## Rules

- One synchronized broker-month decision and at most one logical pair per
  month; consume the attempt before fallible gates and never retry.
- The symbols, endpoints, return order, ascending sort, exact tail replacement, divisor,
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
ascending sort, replace `0,1` by `2` and `10,11` by `9`, then average all twelve,
`1e-12` epsilon, contrarian side, 1,200 D1 bars, 180-minute grace, ten-day
endpoint staleness, `3.5*ATR(20,D1)` stops, equal notionals, 20% mismatch,
forty-day stale hold, and 1,500/3,000-point spread ceilings.

## Risk

- Q02-Q10 use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1` for the aggregate package.
- Each leg has a frozen hard stop; combined modeled stop loss is capped at the
  single fixed-risk budget. Gap/slippage may exceed modeled loss.
- CFDs add roll, basis, financing, session, spread, and contract risks.
- Pair breaks and one-leg execution failures remain material.
- No live risk mode or live artifact is authorized.

## Data Requirements

Native XTIUSD.DWX/XNGUSD.DWX D1 timestamps, closes, ATR, broker time/month,
quotes, symbol metadata, margin, positions, deals, and persistent state.

## Framework Alignment

| card rule | module |
|---|---|
| identity, month attempt, synchronized endpoint reconstruction | `Strategy_NoTradeFilter` and bounded helpers |
| fixed-tail Winsor statistic, contrarian side, pair sizing, stops, atomic open | `Strategy_EntrySignal` |
| package integrity, month and stale closure | `Strategy_ManageOpenPosition` |
| framework reason mapping | `Strategy_ExitSignal` and close helper |
| news disabled on both axes | `Strategy_NewsFilterHook` |

## Validation Plan

1. Match independent fixtures for positive/negative centers, exact replaced
   indexes and boundary weights, reflection, nearest-neighbor side
   disagreement, tie, and ratio
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
| v1 | 2026-09-06 | initial fixed-tail Winsor XTI/XNG reversion card and governed build | Q02 | COMPILE_OK; ENQUEUED_PENDING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Source Approval | 2026-09-06 | APPROVED_SOURCE | `decisions/2026-09-06_xtixng_monthly_winsor2_reversion_source_approval.md` |
| G0 Research Intake | 2026-09-06 | APPROVED | `decisions/2026-09-06_qm5_41357_xtixng_monthly_winsor2_reversion_g0.md` |
| Q01 Build & Spec | 2026-09-06 | COMPILE_OK; BUILD_CHECK_PASS | `D:/QM/reports/work_items/c67931b2-7fd1-42d0-80b0-4c857739b31f/QM5_41357/COMPILE_EA/compile_evidence.json` |
| Q02 Baseline | 2026-09-06 | ENQUEUED_PENDING | work item `328cdef5-6458-4079-b898-b4220efbd6bb`; CPU admission `artifacts/qm5_41357_q02_cpu_admission_20260906.json` |
