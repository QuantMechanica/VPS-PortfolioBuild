---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-XAUXAG-MBISQUARE-RV-20260905_S01
variant_id: AI-CODEX-XAUXAG-MBISQUARE-RV-20260905_S01
source_id: AI-CODEX-XAUXAG-MBISQUARE-RV-20260905
ea_id: QM5_41341
slug: xauxag-mbisquare-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41341_xauxag-mbisquare-rv_card.md
execution_contract_status: APPROVED
created: 2026-09-05
created_by: Research+Development
last_updated: 2026-09-05
g0_status: APPROVED
g0_decision: decisions/2026-09-05_qm5_41341_xauxag_monthly_bisquare_reversion_g0.md
source_approval: decisions/2026-09-05_xauxag_monthly_bisquare_reversion_source_approval.md
source_author: OpenAI Codex
source_authors: OpenAI Codex; Karsten Schweikert; John W. Tukey; CME Group
source_citation: "Schweikert (2018), Journal of Banking & Finance 88, DOI 10.1016/j.jbankfin.2017.11.010; CME Group, Gold & Silver Ratio Spread; governed Tukey-bisquare method record MOP-WTI-BISQUARE-2026."
source_citations:
  - type: governed_composite_source
    citation: "OpenAI Codex (2026). XAU/XAG monthly redescending-bisquare ratio-return reversion."
    location: strategy-seeds/sources/AI-CODEX-XAUXAG-MBISQUARE-RV-20260905/source.md
    quality_tier: governed_source
    role: exact_conjunction_arithmetic_risk_and_lifecycle
  - type: peer_reviewed_relationship_source
    citation: "Schweikert, K. (2018). Are gold and silver cointegrated? Journal of Banking & Finance 88, 44-51."
    location: strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md
    quality_tier: A
    role: state_dependent_gold_silver_long_run_relationship
  - type: exchange_education
    citation: "CME Group. Gold & Silver Ratio Spread."
    location: strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md
    quality_tier: B
    role: ratio_definition_and_opposed_leg_spread
  - type: governed_method_source
    citation: "QuantMechanica governed fixed-step redescending Tukey-bisquare robust-location record."
    location: strategy-seeds/sources/MOP-WTI-BISQUARE-2026/source.md
    quality_tier: A_method
    role: exact_robust_location_arithmetic
strategy_mechanic: monthly-xauxag-thirteen-synchronized-completed-month-log-ratio-endpoints-twelve-adjacent-returns-fixed-step-redescending-bisquare-location-sign-contrarian-equal-notional-basket
sources:
  - "[[sources/AI-CODEX-XAUXAG-MBISQUARE-RV-20260905]]"
concepts:
  - "[[concepts/gold-silver-ratio]]"
  - "[[concepts/robust-return-location]]"
  - "[[concepts/market-neutral-relative-value]]"
indicators:
  - "[[indicators/completed-month-log-ratio-return]]"
  - "[[indicators/redescending-bisquare-location]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, precious-metals, market-neutral-style, relative-value, structural-reversion, redescending-bisquare, monthly-renewal, equal-notional-basket, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41341_XAU_XAG_BISQ_RV_D1
symbol: QM5_41341_XAU_XAG_BISQ_RV_D1
host_symbol: XAUUSD.DWX
symbol_slot: 0
symbol_slots: [0, 1]
magic: 413410000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: symmetric_opposed_leg
expected_trade_frequency: "Approximately 11-12 completed logical XAU/XAG packages per full post-warm-up year; only invalid/MAD-zero/near-zero robust states stay flat. Q02 must prove at least five completed packages in every full scored year or retire."
expected_trades_per_year_per_symbol: 11
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_SYNTHESIS_RISK
r1_reasoning: "Peer-reviewed state-dependent gold/silver relationship, exchange-defined spread, and exact governed robust-estimator evidence; no source efficacy transfers to the QM conjunction or CFDs."
r2_mechanical: PASS
r2_reasoning: "Clock, thirteen synchronized endpoints, twelve returns, median/MAD, frozen cutoff, strict support, 32 updates, contrarian side, equal-notional package, aggregate fixed risk, stops, attempt, and lifecycle are deterministic."
r3_data_available: PASS
r3_qualification: CONTINUOUS_CFD_BASIS_RISK
r3_reasoning: "Registered native XAUUSD.DWX and XAGUSD.DWX D1 histories plus MT5 state supply every runtime input."
r4_ml_forbidden: PASS
r4_reasoning: "Timestamps, prices, logarithms, sorting, absolute deviations, bounded arithmetic, ATR risk, quotes, positions, deals, and persistent state only."
parameters_to_test: "Locked Q02 baseline only: 13 synchronized consecutive completed month-end ratio endpoints; 12 adjacent chronological log-ratio returns; even median indexes 5/6; raw MAD indexes 5/6; 1.4826 normalization; 4.685 frozen cutoff; strict abs(u)<1 squared weights; exactly 32 updates; 1e-12 sign epsilon; contrarian ratio side; 1200 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; per-leg ATR(20)*3.5 frozen stops; equal target notionals; 20% notional mismatch ceiling; 40-day stale exit; 1500/500-point spread ceilings."
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
review_focus: "Falsify a paired monthly XAU/XAG contrarian return stream whose signal is the exact 32-step redescending robust location of synchronized ratio returns. Verify equal-notional opposed legs, aggregate fixed risk, atomic lifecycle, and no absolute-metal directional fallback. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbols_period, first_tradable_month_bar, thirteen_consecutive_completed_months, synchronized_month_end_pairs, chronological_log_ratio_returns, even_sample_median, even_sample_mad, mad_normalization, frozen_bisquare_cutoff, strict_support_boundary, exactly_32_updates, contrarian_direction, monthly_attempt_state, equal_notional_pair, aggregate_fixed_risk, atomic_pair_lifecycle, hard_stops_present, friday_close_disabled, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-09-05 and decisions/2026-09-05_qm5_41341_xauxag_monthly_bisquare_reversion_g0.md: R1-R4 pass within disclosed synthesis and continuous-CFD risks. Corrected-root dedup found no exact or fuzzy identity across 4,821 registry rows, 1,440 cards, and 45 Wiki nodes; manual formula review separates all ratio z-score, regression, tail, rank, scale, and shift neighbors. This identity decision is not a correlation claim."
---

# QM5_41341 XAU/XAG Monthly Redescending-Bisquare Reversion

## Hypothesis

Gold and silver share precious-metals drivers but differ materially in
monetary/safe-haven versus industrial demand. A paired relative-value package
can isolate changes in that relationship from much of their common metal beta.
The hypothesis is that the robust central direction of twelve synchronized
monthly ratio returns overextends and partially reverses over the next broker
month.

This is not a decorrelation claim. The relationship can shift structurally,
and equal target notional is only market-neutral-style, not guaranteed beta,
delta, volatility, or factor neutrality. Q09 alone owns realized overlap with
the certified XAU/SP500/NDX/XNG book.

## Source Traceability And Claim Boundary

The approved composite source is
`strategy-seeds/sources/AI-CODEX-XAUXAG-MBISQUARE-RV-20260905/source.md`.
Schweikert supplies peer-reviewed state-dependent gold/silver relationship
evidence; CME supplies the ratio and opposed-leg spread definition; the
governed bisquare packet fixes exact arithmetic. No source tests this
conjunction, direction, constants, Darwinex CFDs, costs, activity, or
portfolio correlation.

## Non-Duplicate Decision

The corrected-root receipt
`artifacts/qm5_xauxag_mbisquare_rv_preallocation_dedup_20260905.json` returned
`CLEAN`. This EA neither z-scores an absolute ratio (`QM5_12577`), regresses a
residual (`QM5_20161`/`QM5_21526`), applies a one-shot MAD tail (`QM5_20263`),
compares old/recent rank dispersion (`QM5_41286`/`QM5_41318`), nor follows
outright WTI robust momentum (`QM5_20286`). The exact synchronized ratio-return
object, redescending update path, and contrarian opposed-leg output are jointly
load-bearing.

## Markets, Timeframe, And Cadence

- Logical symbol: `QM5_41341_XAU_XAG_BISQ_RV_D1`.
- Host/order clock: `XAUUSD.DWX`, D1, slot 0; second leg `XAGUSD.DWX`, slot 1.
- Decide once on the first synchronized executable D1 bar after a genuine
  broker-month transition, within 180 minutes.
- Formation: thirteen consecutive synchronized completed month ends.
- Hold through Friday until the next broker month; forty days is stale repair.
- Planning prior: eleven to twelve completed packages/year. Q02 retires below
  five in any full post-warm-up scored year.

## Exact Formula

For synchronized closes `G[0..12]` and `S[0..12]`, oldest to newest:

```text
q[i] = ln(G[i]/S[i])
r[i] = q[i+1]-q[i]
m = even_median(r)
MAD = even_median(abs(r-m))
cutoff = 4.685*1.4826*MAD
mu[0] = m
mu[j+1] = sum(w[i]*r[i])/sum(w[i]), j=0..31
w[i] = (1-u[i]^2)^2 if abs(u[i])<1 else 0
u[i] = (r[i]-mu[j])/cutoff
```

If `mu[32] > +1e-12`, sell XAU and buy XAG. If `mu[32] < -1e-12`,
buy XAU and sell XAG. Otherwise stay flat. Invalid arithmetic, nonpositive MAD,
or nonpositive total weight fails closed. Magnitude never scales risk.

## Rules

- One synchronized broker-month decision and at most one logical pair per
  month; every attempt is consumed before fallible gates and never retried.
- The two symbols, endpoint count/order, estimator, constants, update count,
  direction, target-notional relation, risk budget, stops, and exit clocks are
  immutable in Q02.
- The package is valid only while both opposed legs exist with the registered
  magics, expected sides, hard stops, and bounded notional mismatch.
- Every invalid, missing, stale, asynchronous, nonfinite, or ambiguous state
  fails closed or flattens existing owned exposure.
- No single-leg directional fallback is permitted.

## Entry Rules

1. Require exact identity, host/timeframe, both magic rows, fixed-risk mode,
   news/Friday/stress settings, and every locked strategy input.
2. Process malformed-pair and later-month/stale exits before entry gates.
3. Require synchronized current host bars and consume/persist the month before
   history, signal, spread, quote, ATR, sizing, margin, or submission.
4. Intersect bounded completed D1 histories and select the latest common close
   in each of exactly thirteen immediately prior consecutive broker months.
5. Reject missing, duplicate, nonconsecutive, current-month, stale,
   nonchronological, nonpositive, or nonfinite endpoints.
6. Compute the exact formula and strict epsilon decision above.
7. Require both spreads, quotes, ATR(20), metadata, fixed-risk sizing, and
   margin. Target equal absolute USD notionals within 20% mismatch.
8. Open one opposed pair with aggregate frozen-stop risk capped at
   `RISK_FIXED=1000`, a frozen `3.5*ATR(20,D1)` stop per leg, and no targets.
9. If the second leg fails after the first opens, immediately flatten the first.

## Exit Rules

1. Framework kill switch and both broker hard stops are authoritative.
2. Close both legs atomically on the first processed tick in a later broker
   month or after forty elapsed calendar days.
3. Close the whole package on a missing leg, duplicate leg, wrong symbol,
   magic, side, volume/notional, time, or stop state.
4. No intramonth signal flip, ratio target, trail, break-even, partial close,
   Friday flatten, retry, scale-in, grid, martingale, or pyramid.

## Filters And Trade Management

Fail closed outside the exact host, identity, fixed contract, pair
synchronization, endpoint, formula, spread, quote, ATR, sizing, margin, and
one-attempt rules. Preserve both original hard stops and one-package state.
Runtime may not read futures curves, volume, open interest, files, APIs,
forecasts, optimizer output, portfolio state, or trained artifacts.

## Parameters To Test

Q02 has exactly one baseline: thirteen synchronized ratio endpoints; twelve
returns; even median/MAD; `1.4826`; frozen `4.685` cutoff; strict compact
support; squared weights; 32 updates; `1e-12` decision epsilon; contrarian
side; 1,200 D1 bars; 180-minute grace; ten-day endpoint staleness;
`3.5*ATR(20,D1)` stops; equal target notionals; 20% mismatch; forty-day stale
hold; and 1,500/500-point spread ceilings. Any change creates a new identity.

## Risk

- Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1` for the aggregate package.
- Each leg receives a frozen hard stop; sizing caps their combined modeled
  stop loss at the single fixed-risk budget.
- Gap/slippage can exceed modeled risk. CFDs add roll, basis, financing,
  asynchronous-session, spread, and contract-specification risk.
- Pair breaks and one-leg execution failures remain material.
- No live risk mode or live artifact is authorized.

## Data Requirements

Native XAUUSD.DWX/XAGUSD.DWX D1 timestamps, closes, ATR, broker time/month,
quotes, symbol metadata, margin, positions, deals, and terminal-global state.

## Framework Alignment

| card rule | module |
|---|---|
| identity, fixed contract, month attempt, synchronized endpoint reconstruction | `Strategy_NoTradeFilter` and bounded helpers |
| robust statistic, contrarian side, pair sizing, stops, atomic open | `Strategy_EntrySignal` |
| integrity repair, next-month and forty-day closure | `Strategy_ManageOpenPosition` |
| framework reason mapping | `Strategy_ExitSignal` and close helper |
| news disabled on both axes | `Strategy_NewsFilterHook` |

## Validation Plan

1. Match independent fixtures for positive/negative robust centers,
   redescending outlier rejection, reflection, degeneracy, and synchronized
   log-ratio return identity.
2. Verify exact endpoint order, median/MAD indices, frozen cutoff, 32 updates,
   strict support/epsilon, contrarian sides, aggregate fixed risk, equal target
   notionals, atomic recovery, and lifecycle.
3. Run card lint and strict Q01 compile/build checks.
4. Enqueue exactly one fixed-risk logical-basket Q02 item only below the host
   CPU ceiling; do not launch a tester manually.

## Failure Conditions And Safety Boundary

Retire on zero packages, fewer than five completed packages in any full
post-warm-up year, formula/fixture mismatch, synchronization leakage,
nonpositive governed economics, invalid risk, missing stop, atomic lifecycle
defect, nondeterminism, or downstream hard failure. Preserve failures without
tuning.

Authorized: deterministic identity/magic allocation, branch-only non-live
build, reference tests, strict Q01, and one paced Q02 enqueue below CPU ceiling.

Forbidden: optimization, manual backtest/tester launch, live/demo/shadow/
stress sets, portfolio-gate edits, correlation waivers, portfolio admission,
deploy/live manifests, `T_Live`, AutoTrading, terminal control, or live use.

## Revision History

| version | date | reason | gate | verdict |
|---|---|---|---|---|
| v1 | 2026-09-05 | initial XAU/XAG bisquare reversion card | G0 | APPROVED; build pending |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Source Approval | 2026-09-05 | APPROVED_SOURCE | `decisions/2026-09-05_xauxag_monthly_bisquare_reversion_source_approval.md` |
| G0 Research Intake | 2026-09-05 | APPROVED | `decisions/2026-09-05_qm5_41341_xauxag_monthly_bisquare_reversion_g0.md` |
| Q01 Build & Spec | TBD | PENDING | TBD |
| Q02 Baseline | TBD | NOT_ENQUEUED | TBD |
