---
card_schema_version: 2
type: strategy
strategy_id: SCHWEIKERT-CME-MOP-XAUXAG-BLOCKMED-RV-20260909_S01
variant_id: SCHWEIKERT-CME-MOP-XAUXAG-BLOCKMED-RV-20260909_S01
source_id: SCHWEIKERT-CME-MOP-XAUXAG-BLOCKMED-RV-20260909
ea_id: QM5_41389
slug: xauxag-blockmed-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41389_xauxag-blockmed-rv_card.md
execution_contract_status: APPROVED
created: 2026-09-09
created_by: Research+Development
last_updated: 2026-09-09
g0_status: APPROVED
g0_decision: decisions/2026-09-09_qm5_41389_xauxag_monthly_block_median_reversion_g0.md
source_approval: decisions/2026-09-09_xauxag_monthly_block_median_reversion_source_approval.md
source_author: OpenAI Codex
source_authors: OpenAI Codex; Karsten Schweikert; CME Group; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen
source_citation: "Schweikert (2018), Journal of Banking & Finance 88, DOI 10.1016/j.jbankfin.2017.11.010; CME Group, Gold & Silver Ratio Spread; Moskowitz, Ooi, and Pedersen (2012), Journal of Financial Economics 104(2), DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: governed_composite_source
    citation: "OpenAI Codex (2026). XAU/XAG monthly chronological block-median ratio reversion."
    location: strategy-seeds/sources/SCHWEIKERT-CME-MOP-XAUXAG-BLOCKMED-RV-20260909/source.md
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
  - type: peer_reviewed_method_lineage
    citation: "Moskowitz, Ooi, and Pedersen (2012); governed block-median arithmetic extraction."
    location: strategy-seeds/sources/MOP-WTI-BLOCKMED-2026/source.md
    quality_tier: A_method
    role: monthly_horizon_and_transparent_block_arithmetic_only
strategy_mechanic: monthly-xauxag-thirteen-synchronized-completed-month-log-ratio-endpoints-twelve-adjacent-changes-four-chronological-three-change-block-means-even-block-median-sign-contrarian-equal-notional-basket
sources:
  - "[[sources/SCHWEIKERT-CME-MOP-XAUXAG-BLOCKMED-RV-20260909]]"
concepts:
  - "[[concepts/gold-silver-ratio]]"
  - "[[concepts/median-of-block-means]]"
  - "[[concepts/market-neutral-relative-value]]"
indicators:
  - "[[indicators/completed-month-log-ratio-change]]"
  - "[[indicators/chronological-block-mean]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, precious-metals, market-neutral-style, relative-value, structural-reversion, chronological-block-median, monthly-renewal, equal-notional-basket, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41389_XAU_XAG_BLOCKMED_RV_D1
symbol: QM5_41389_XAU_XAG_BLOCKMED_RV_D1
host_symbol: XAUUSD.DWX
symbol_slot: 0
symbol_slots: [0, 1]
magic: 413890000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: symmetric_opposed_leg
expected_trade_frequency: "Approximately 11-12 completed logical packages per full post-warm-up year; only invalid or near-zero block-median states remain flat. Q02 must prove at least five completed packages in every full scored year or retire."
expected_trades_per_year_per_symbol: 11
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_SYNTHESIS_RISK
r1_reasoning: "Peer-reviewed state-dependent gold/silver relationship, exchange-defined spread, and governed monthly block arithmetic; no efficacy transfers."
r2_mechanical: PASS
r2_reasoning: "Clock, endpoints, changes, four fixed blocks, sort, even median, side, package, aggregate risk, stops, attempt, and lifecycle are deterministic."
r3_data_available: PASS
r3_qualification: CONTINUOUS_CFD_BASIS_RISK
r3_reasoning: "Registered native XAUUSD.DWX and XAGUSD.DWX D1 histories plus MT5 state supply every runtime input."
r4_ml_forbidden: PASS
r4_reasoning: "Timestamps, prices, logarithms, sorting, arithmetic, ATR, quotes, positions, deals, and persistent state only."
parameters_to_test: "Locked Q02 baseline only: 13 synchronized completed month-end ratio endpoints; 12 adjacent chronological log-ratio changes; 4 fixed chronological blocks; 3 changes per block; ascending sort of block means only; even median of indexes 1 and 2; 1e-12 sign epsilon; contrarian ratio side; 1200 D1 history bars; 180-minute entry grace; 10-day endpoint staleness; per-leg ATR(20)*3.5 frozen stops; equal target notionals; 20% notional mismatch ceiling; 40-day stale exit; 1500/500-point spread ceilings."
risk_fixed_backtest: 1000
risk_percent_backtest: 0
portfolio_weight_backtest: 1
news_temporal_mode: QM_NEWS_TEMPORAL_OFF
news_compliance_profile: QM_NEWS_COMPLIANCE_NONE
friday_close_enabled: false
pipeline_phase: COMPILE_PENDING_CPU_STOP
q01_status: COMPILE_PENDING
q02_status: NOT_ENQUEUED_CPU_CEILING
force_build: true
review_focus: "Falsify a monthly XAU/XAG contrarian stream whose signal is the even median of four exact chronological three-change ratio blocks. Verify opposed legs, aggregate fixed risk, atomic lifecycle, and no outright-metal fallback. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbols_period, first_tradable_month_bar, thirteen_consecutive_completed_months, synchronized_month_end_pairs, chronological_log_ratio_changes, four_nonoverlapping_blocks, three_changes_per_block, sort_block_means_only, even_median_indexes_one_two, contrarian_direction, monthly_attempt_state, equal_notional_pair, aggregate_fixed_risk, atomic_pair_lifecycle, hard_stops_present, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-09-09 and durable source/G0 decisions: R1-R4 pass within disclosed synthesis and continuous-CFD risks. Exact searches across 4,869 registry rows and 847 approved cards found no prior XAU/XAG block-median identity; manual review separates the outright-WTI estimator sibling and all nearby XAU/XAG families."
---

# QM5_41389 XAU/XAG Monthly Chronological Block-Median Reversion

## Hypothesis

Gold and silver share precious-metals drivers but differ in monetary,
safe-haven, and industrial demand. A paired relative-value package can remove
much of their common directional exposure. This card tests whether the robust
central direction of four consecutive three-month blocks of gold/silver ratio
changes overextends and partially reverses during the next month.

Equal target notional is market-neutral-style, not guaranteed factor
neutrality. Q09 alone owns realized book overlap.

## Source Traceability And Claim Boundary

The approved source packet is
`strategy-seeds/sources/SCHWEIKERT-CME-MOP-XAUXAG-BLOCKMED-RV-20260909/source.md`.
Schweikert supplies relationship evidence, CME supplies spread construction,
and MOP lineage supplies only monthly/block arithmetic. No source tests the
conjunction, direction, constants, CFDs, costs, or portfolio correlation.

## Non-Duplicate Decision

No existing XAU/XAG system forms four chronological three-change block means,
sorts only those means, and fades their even median. `QM5_20287` follows the
statistic on outright WTI; this basket changes the state object, carrier,
direction, execution, and risk topology. Raw/robust center, sign-vote, rank,
tail-treatment, and distribution-test neighbors use different functionals.

## Markets, Timeframe, And Cadence

- Logical symbol: `QM5_41389_XAU_XAG_BLOCKMED_RV_D1`.
- Host: `XAUUSD.DWX`, D1, slot 0; second leg `XAGUSD.DWX`, slot 1.
- Decide once within 180 minutes of the first synchronized D1 bar after each
  genuine broker-month transition.
- Use thirteen completed synchronized month ends; hold to the next month,
  with a forty-day stale repair.

## Exact Formula

For synchronized positive closes `G[0..12]`, `S[0..12]`, oldest first:

```text
q[i] = ln(G[i]/S[i])
r[i] = q[i+1]-q[i], i=0..11
b[j] = (r[3j]+r[3j+1]+r[3j+2])/3, j=0..3
s = ascending sort of b
m = (s[1]+s[2])/2
```

If `m > +1e-12`, sell XAU and buy XAG. If `m < -1e-12`, buy XAU and
sell XAG. Otherwise remain flat. Magnitude never scales risk.

## Rules

The formula, carrier, opposed-leg direction, attempt clock, aggregate risk,
hard stops, and lifecycle below are the complete authorized baseline. There is
no fallback estimator, outright-metal trade, or optimization surface.

## 4. Entry Rules

1. Require exact identity, host/timeframe, magic rows, fixed-risk mode, and
   locked strategy inputs. News and Friday inputs remain framework-governed.
2. Process malformed-pair and time exits before entry gates.
3. Synchronize current bars and persist the consumed month before history,
   signal, spread, quote, ATR, sizing, margin, or submission.
4. Select the latest common close from each of exactly thirteen immediately
   prior consecutive broker months.
5. Compute twelve chronological changes, four fixed blocks, and the exact
   even median; trade the contrarian package only outside the epsilon.
6. Require spread, quote, ATR(20), metadata, sizing, and margin. Target equal
   absolute USD notionals within 20% mismatch.
7. Open opposed legs with combined frozen-stop risk no greater than the one
   positive `RISK_FIXED` budget and `3.5*ATR(20,D1)` stops. Flatten the first
   immediately if the second fails.

## 5. Exit Rules

Close both legs on framework kill switch, first processed tick in a later
broker month, forty elapsed days, or any missing/duplicate/wrong-symbol/
wrong-magic/wrong-side/invalid-stop package state. Preserve valid hard stops
and one-package state. No signal flip, target, trail, break-even, partial
close, Friday flatten, retry, scale-in, grid, martingale, or pyramid.

## 6. Filters (No-Trade Module)

Fail closed outside the exact ID, slot, symbol, timeframe, fixed-risk mode, or
locked strategy parameters. Reject asynchronous or stale history, malformed
endpoints, current-month leakage, nonfinite arithmetic, an epsilon state,
excess spread, invalid quote/ATR/metadata, consumed attempt, owned package, or
same-month entry deal. Framework news and Friday inputs are never pinned by
the strategy guard.

## 7. Trade Management Rules

Maintain either zero exposure or exactly one valid opposed-leg package. Close
both legs on a broken package, next-month boundary, forty-day stale guard, or
framework kill switch. Never repair by leaving one leg open, retrying the
month, changing side, or relaxing stops or notional tolerance.

## Parameters To Test

One locked Q02 baseline: 13 endpoints, 12 changes, 4 blocks, width/divisor 3,
sort block means only, median indexes 1 and 2, `1e-12` epsilon, contrarian
side, 1,200 D1 bars, 180-minute grace, ten-day staleness, `3.5*ATR(20)` stops,
equal notionals, 20% mismatch, forty-day stale hold, and 1,500/500-point
spread ceilings. Any change requires a new identity and upstream review.

## Risk And Data

Q02-Q10 use `RISK_FIXED>0`, `RISK_PERCENT=0`, and the setfile value of
`PORTFOLIO_WEIGHT`. Each leg has a frozen hard stop; combined modeled loss is
capped at one fixed-risk budget. Gaps and slippage can exceed it. CFDs add
roll, basis, financing, session, spread, synchronization, and contract risk.

Runtime uses only native XAU/XAG D1 timestamps and closes, ATR, broker time,
quotes, symbol metadata, margin, positions, deals, and persistent state. It
does not read files, APIs, curves, volume, open interest, forecasts, optimizer
output, portfolio state, or trained artifacts.

## Framework Alignment

| Card rule | Module |
|---|---|
| identity, month attempt, synchronized endpoint reconstruction | `Strategy_NoTradeFilter` and bounded helpers |
| block statistic, contrarian side, pair sizing, stops, atomic open | `Strategy_EntrySignal` |
| package integrity, month and stale closure | `Strategy_ManageOpenPosition` |
| framework reason mapping | `Strategy_ExitSignal` and close helper |
| framework-governed news inputs | `Strategy_NewsFilterHook` |

## Validation And Kill Conditions

Q01 must verify fixtures for positive, negative, epsilon, reflection,
raw-mean disagreement, block membership, and sort target; synchronization;
aggregate fixed risk; equal notionals; atomic repair; card lint; resolver;
PACER audit; and strict compile/build checks.

Retire on zero packages, fewer than five completed packages in a full scored
year, formula mismatch, leakage, nonpositive economics, invalid risk, missing
stop, atomic defect, nondeterminism, or downstream hard failure. No tuning.

Authorized: deterministic allocation, branch-only non-live build, Q01, and
one paced Q02 enqueue below the CPU ceiling. Forbidden: manual backtests,
optimization, portfolio-gate edits, correlation waivers, admission, deploy or
live manifests, `T_Live`, AutoTrading, terminal control, or live use.

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Source Approval | 2026-09-09 | APPROVED_SOURCE | `decisions/2026-09-09_xauxag_monthly_block_median_reversion_source_approval.md` |
| G0 Research Intake | 2026-09-09 | APPROVED | `decisions/2026-09-09_qm5_41389_xauxag_monthly_block_median_reversion_g0.md` |
| Q01 Build Validation | 2026-09-09 | COMPILE_PENDING | PACER audit and fixtures passed; governed compile work item `48408a93-4f2d-4615-9b54-fb8738721ab8` remains pending without EX5/verdict. |
| Q02 Baseline Screening | 2026-09-09 | NOT_ENQUEUED_CPU_CEILING | Five samples averaged 99.5%, max 100.0%, above the strict 97% ceiling. |
