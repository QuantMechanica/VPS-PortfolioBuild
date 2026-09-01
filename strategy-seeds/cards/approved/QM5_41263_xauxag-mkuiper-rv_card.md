---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-XAUXAG-MKUIPER-RV-20260901_S01
variant_id: AI-CODEX-XAUXAG-MKUIPER-RV-20260901_S01
source_id: AI-CODEX-XAUXAG-MKUIPER-RV-20260901
ea_id: QM5_41263
slug: xauxag-mkuiper-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41263_xauxag-mkuiper-rv_card.md
execution_contract_status: APPROVED
created: 2026-09-01
created_by: Research+Development
last_updated: 2026-09-01
g0_status: APPROVED
g0_decision: decisions/2026-09-01_qm5_41263_xauxag_monthly_kuiper_reversion_g0.md
source_approval: decisions/2026-09-01_xauxag_monthly_kuiper_reversion_source_approval.md
source_author: "OpenAI Codex"
source_authors: "OpenAI Codex; Nicolaas H. Kuiper; Karsten Schweikert; CME Group; twosamples authors"
source_citation: "OpenAI Codex (2026), XAU/XAG monthly exact-permutation Kuiper distribution-shift reversion; supporting records Kuiper (1960), Indagationes Mathematicae 63, DOI 10.1016/S1385-7258(60)50006-0; Schweikert (2018), Journal of Banking & Finance 88, DOI 10.1016/j.jbankfin.2017.11.010; CME Group, Gold & Silver Ratio Spread; CRAN twosamples 2.0.1 pinned at commit 4923388cdb14be4875a7041cddd69629a6bfc735."
source_citations:
  - type: ai_originated_governed_source
    citation: "OpenAI Codex (2026). XAU/XAG monthly exact-permutation Kuiper distribution-shift reversion."
    location: "strategy-seeds/sources/AI-CODEX-XAUXAG-MKUIPER-RV-20260901/source.md"
    quality_tier: governed_source
    role: exact_trading_hypothesis_formula_activity_boundary_risk_atomicity_and_lifecycle
  - type: peer_reviewed_relationship_paper
    citation: "Schweikert, K. (2018). Are gold and silver cointegrated? New evidence from quantile cointegrating regressions. Journal of Banking & Finance 88, 44-51."
    location: "DOI 10.1016/j.jbankfin.2017.11.010; complete governed packet strategy-seeds/sources/SCHWEIKERT-QC-2018/source.md"
    quality_tier: A
    role: state_dependent_gold_silver_relation_and_adverse_evidence_only
  - type: official_exchange_carrier_research
    citation: "CME Group. Gold & Silver Ratio Spread."
    location: "complete governed packet strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md"
    quality_tier: A_official
    role: gold_silver_ratio_carrier_and_distinct_demand_drivers_only
  - type: primary_statistical_method
    citation: "Kuiper, N. H. (1960). Tests Concerning Random Points on a Circle. Indagationes Mathematicae (Proceedings) 63, 38-47."
    location: "DOI 10.1016/S1385-7258(60)50006-0; complete-read receipt strategy-seeds/sources/AI-CODEX-XAUXAG-MKUIPER-RV-20260901/retrieval_route_kuiper_1960_20260901.json"
    quality_tier: A
    role: two_sample_ecdf_dplus_plus_dminus_statistic_only
  - type: official_statistical_software
    citation: "CRAN twosamples 2.0.1 and pinned schuhmacherlab/twosamples source."
    location: "commit 4923388cdb14be4875a7041cddd69629a6bfc735; retrieval receipt strategy-seeds/sources/AI-CODEX-XAUXAG-MKUIPER-RV-20260901/retrieval_route_cran_twosamples_20260901.json"
    quality_tier: A_official
    role: independent_formula_and_pooled_label_permutation_route_only
strategy_mechanic: monthly-xauxag-thirteen-synchronized-completed-log-ratio-endpoints-twelve-adjacent-changes-fixed-six-old-six-recent-strict-no-tie-two-sample-kuiper-dplus-plus-dminus-exact-924-label-permutation-v-half-tail-798-recent-rank-sum-contrarian-equal-notional-basket
sources:
  - "[[sources/AI-CODEX-XAUXAG-MKUIPER-RV-20260901]]"
concepts:
  - "[[concepts/gold-silver-relative-value]]"
  - "[[concepts/nonparametric-distribution-shift]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/synchronized-completed-month-log-ratio-change]]"
  - "[[indicators/kuiper-two-sample-ecdf-distance]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, precious-metals, market-neutral-style, relative-value, structural-reversion, kuiper-two-sample, exact-label-permutation, monthly-rebalance, equal-notional-basket, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals_relative_value]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41263_XAU_XAG_MKUIPER_RV_D1
symbol: XAUUSD.DWX
host_symbol: XAUUSD.DWX
symbol_slot: 0
symbol_slots: [0, 1]
magic: 412630000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: paired_long_short
expected_trade_frequency: "Approximately 9-10 qualifying XAU/XAG packages per twelve combinatorial monthly attempts after thirteen synchronized completed month ends. The locked strict-rank reference leaves 760 directional assignments among 924, or 9.870 states/year before market and execution gates."
expected_trades_per_year_per_symbol: 9
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_AI_SYNTHESIS_AND_PRIMARY_METHOD_EVIDENCE
r1_reasoning: "Durable AI source, complete governed peer-reviewed relationship evidence with adverse findings, official exchange carrier evidence, complete primary Kuiper paper, pinned official CRAN/source implementation record, and explicit no-performance boundaries."
r2_mechanical: PASS
r2_reasoning: "Month clock, synchronization, endpoints, changes, fixed blocks, strict ties, both ECDF extremes, exact 924-label enumeration, inclusive boundary, side, attempt, aggregate risk, atomicity, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_reasoning: "Registered native XAUUSD.DWX and XAGUSD.DWX D1 histories and MT5 state supply every runtime input; synchronization, continuous-CFD basis, financing, and legging risks remain explicit."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, sorting, fixed finite integer loops, arithmetic, comparisons, ATR risk controls, quotes, positions, deals, and persistent state; no trained output, prohibited signal indicator, random runtime sampling, or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: 13 synchronized endpoints; 12 adjacent log-ratio changes; fixed old/recent blocks of 6; strict no-tie two-sample Kuiper D-plus plus D-minus; all 924 six-label assignments; relative epsilon 1e-12; observed V at least 0.5; inclusive exact tail at most 798; neutral recent rank sum 39; 900 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 stops; equal target notionals; 20% notional mismatch ceiling; 40-day stale exit; 1500/500-point spread ceilings."
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
review_focus: "Falsify a monthly gold/silver relative-change distribution-shift fade outside the directional XAU/SP500/NDX/XNG book. Verify synchronization, change orientation, fixed membership, strict ties, both Kuiper ECDF extrema, all 924 assignments, V/tail equivalence, rank-sum side, consumed month, aggregate fixed risk, equal-notional tolerance, atomicity, and next-month lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbols_period, first_tradable_month_bar, thirteen_consecutive_completed_months, synchronized_month_end_pairs, latest_pair_per_month, chronological_log_ratio_change_orientation, fixed_six_old_six_recent_membership, strict_no_tie_changes, dplus_plus_dminus_kuiper, exact_924_label_assignments, relative_inclusive_tail_tolerance, kuiper_half_distance, tail_count_798, neutral_recent_rank_sum_39, contrarian_pair_sides, monthly_attempt_state, equal_notional_pair, aggregate_fixed_risk, atomic_pair_lifecycle, hard_stops_present, friday_close_disabled, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-09-01 and decisions/2026-09-01_qm5_41263_xauxag_monthly_kuiper_reversion_g0.md: source and R1-R4 pass for one bounded build. Corrected-root dedup found no exact identity across 4,762 registry rows, 1,399 cards, and 45 Wiki nodes; two fixed strict-label paths prove qualifier disagreement against the closest KS and Anderson-Darling rules."
---

# QM5_41263 XAU/XAG Exact-Permutation Kuiper Reversion

## Hypothesis

Gold and silver share precious-metal and USD drivers but differ in monetary,
safe-haven, industrial, and business-cycle exposure. When the latest six
completed monthly gold-minus-silver log-ratio changes become distributionally
separated from the prior six in both opposing ECDF directions, fade the recent
relative shift for one broker month.

Opposite equal-target-notional legs are intended to reduce outright XAU
direction and form a market-neutral-style stream different from the
directional XAU/SP500/NDX/XNG book. They do not prove neutrality or low
correlation. Q02 owns activity/economics; unchanged Q09 alone owns overlap.

## Source Traceability And Claim Boundary

The single governed source is
`strategy-seeds/sources/AI-CODEX-XAUXAG-MKUIPER-RV-20260901/source.md`, source-
approved in commit `8c2ab49371` before card extraction. Schweikert and CME
support only the state-dependent relation and ratio carrier. Kuiper and pinned
CRAN evidence support only the two-sample `D_plus+D_minus` distance and label-
permutation route. Every trading choice is pre-result QM synthesis.

No statistical or trading result is imported as an efficacy claim.

## Non-Duplicate Decision

The canonical dedup receipt, SHA-256
`CBEA9419A218F75324605F679CEC778FEC42D513A0E6A2E5BB516BAE46A4D5F7`, found
no exact identity and one same-carrier fuzzy match. `QM5_41187` keeps one
maximum signed KS gap on ratio levels; `QM5_41260` sums squared, tail-weighted
discrepancies across all ranks; this card adds the largest opposing ECDF gaps
on adjacent ratio changes. `RROROROOROOR` qualifies only this rule among the
Kuiper/KS/Anderson-Darling comparison; `RROROROROORO` qualifies Anderson-
Darling but not this rule. Complements reverse direction.

## Markets, Timeframe, And Cadence

- Host/slot 0: exact `XAUUSD.DWX`; companion/slot 1: exact `XAGUSD.DWX`.
- Logical tester symbol: `QM5_41263_XAU_XAG_MKUIPER_RV_D1` on the XAU host.
- D1, intended magics `412630000` and `412630001`.
- Decide once at a genuine broker-month transition within 180 minutes of the
  raw host D1 bar open; consume the attempt before fallible gates.
- Formation: thirteen synchronized completed month ends; current month barred.
- Hold to next broker month; forty calendar days is stale repair.
- Design prior: 760 directional strict-label states among 924, about 9.870 per
  twelve attempts. Retire below five completed packages in any full post-
  warm-up year.

## Formula

For chronological synchronized completed-month close pairs `i=0..12`:

```text
q[i] = ln(XAU_close[i]) - ln(XAG_close[i])
r[i] = q[i+1] - q[i], i=0..11
old = r[0..5]; recent = r[6..11]
require every r pairwise distinct

pool and sort all r while preserving old/recent labels
D_plus = max over pooled cuts of (F_recent - F_old)
D_minus = max over pooled cuts of (F_old - F_recent)
V_observed = D_plus + D_minus

tail_count = 0; assignment_count = 0
for each 12-bit mask having exactly six recent labels:
    compute V_perm from that label path
    if V_perm + 1e-12*max(1,abs(V_observed)) >= V_observed:
        tail_count++
    assignment_count++

require assignment_count == 924
require V_observed + 1e-12 >= 0.5
require tail_count <= 798

W_recent = sum of pooled ranks carrying recent labels
SELL XAU / BUY XAG iff W_recent > 39
BUY XAU / SELL XAG iff W_recent < 39
FLAT otherwise
```

All arithmetic must be finite. Statistic magnitude never scales risk.

## Rules

- Persist normalized broker `yyyymm` before history, signal, news, spread,
  quote, ATR, sizing, margin, or order gates; never retry that month.
- Select the latest exactly timestamp-matched XAU/XAG D1 pair in each of the
  thirteen immediately prior consecutive broker months.
- Reject current-month input, missing/duplicate months, unmatched timestamps,
  nonchronological/nonpositive/nonfinite data, an endpoint more than ten days
  stale, exact change ties, invalid enumeration, or neutral side.
- Use only the fixed split, complete ECDF path, all 924 labels, inclusive
  tolerance, `V>=0.5`, tail cap 798, and neutral rank sum 39.
- Both news axes, legacy news mode, and Friday close are OFF.

## 4. Entry Rules

1. Require exact identity, host, companion, D1, slots, registered magics,
   fixed-risk mode, framework inputs, and every locked strategy input.
2. Run package repair and prior-month/stale exits before entry-only gates.
3. Require a genuine new month inside the 180-minute window, then consume it.
4. Reject owned exposure or same-magic entry deals in the current month.
5. Reconstruct the synchronized endpoints and exact Kuiper decision.
6. Require spreads in bounds, executable quotes, completed-bar ATR(20), valid
   metadata, fixed-risk sizing, and target-notional mismatch at most 20%.
7. Split aggregate stop risk equally, reduce only for notional equality,
   attach frozen `3.5*ATR(20,D1)` hard stops, and use no targets.
8. Submit XAU first and XAG second. Keep only one correct, registered, stopped
   position per slot; otherwise flatten every owned leg immediately.

## 5. Exit Rules

1. Framework kill switch and broker hard stops remain authoritative.
2. Close both legs on the first processed tick in a later broker month.
3. Close after forty elapsed calendar days as stale repair.
4. Flatten orphaned, duplicated, same-side, wrong-symbol, wrong-magic, wrong-
   direction, stopless, stale, or excessive-mismatch packages immediately.
5. No intramonth flip, target, trail, break-even, partial close, Friday close,
   news exit, scale-in, grid, martingale, or pyramid.

## 6. Filters (No-Trade Module)

Fail closed outside the exact contract or on consumed attempt, owned exposure,
same-month deal, malformed synchronization/data/ties, invalid Kuiper/tail,
neutral side, excessive spread, invalid quote, unavailable ATR, invalid stop/
volume, or notional mismatch. Terminal-persistent attempt state plus deal
history prevents restart retries. Runtime reads no external source.

## 7. Trade Management Rules

Maintain either zero exposure or one valid opposite-side package. Preserve
hard stops; close before monthly renewal or after forty days. Repair runs on
every tick before entry-only gates and flattens every owned leg on failure.

## 8. Parameters To Test

Q02 has one locked baseline and no optimization surface:

| input | value |
|---|---:|
| `strategy_xag_symbol` | XAGUSD.DWX |
| `strategy_endpoint_count` | 13 |
| `strategy_return_count` | 12 |
| `strategy_block_size` | 6 |
| `strategy_assignment_count` | 924 |
| `strategy_min_kuiper_v` | 0.5 |
| `strategy_tail_count_max` | 798 |
| `strategy_stat_epsilon` | 1e-12 |
| `strategy_neutral_rank_sum` | 39 |
| `strategy_history_bars_d1` | 900 |
| `strategy_entry_window_minutes` | 180 |
| `strategy_max_endpoint_gap_days` | 10 |
| `strategy_atr_period_d1` | 20 |
| `strategy_atr_sl_mult` | 3.5 |
| `strategy_notional_ratio` | 1.0 |
| `strategy_max_notional_mismatch_fraction` | 0.20 |
| `strategy_max_hold_days` | 40 |
| `strategy_xau_max_spread_points` | 1500 |
| `strategy_xag_max_spread_points` | 500 |
| `strategy_deviation_points` | 20 |

Changing the state, split, statistic, boundary, side, risk, stop, target
notional, or hold after Q02 is forbidden result-driven repair.

## Source-Defined Rules

- Gold/silver is state-dependent with distinct monetary and industrial drivers;
  no constant equilibrium is guaranteed.
- Two-sample Kuiper distance adds the largest positive and negative ECDF gaps.
- Pooled-label permutations provide a finite distribution-free route.
- No performance, threshold, direction, CFD equivalence, hedge ratio, package
  risk, density, or neutrality transfers from a source.

## QM Interpretations

Thirteen endpoints, adjacent changes, six/six split, strict ties, exact 924-
label tail, half-distance boundary, contrarian rank-sum side, monthly hold,
equal target notionals, ATR stops, spread caps, and consumed attempt are
transparent pre-result choices. Tail 798 is not called a p-value or level.

## Framework Execution Overrides

Friday close is disabled. Both news controls are OFF. Backtest risk is fixed
at 1,000 account-currency units with percentage risk zero and portfolio weight
one. Canonical stress rejection probability is zero.

## Exit Precedence

1. Framework kill switch and hard-stop enforcement.
2. Lifecycle and package-integrity repair.
3. New-broker-month close.
4. Forty-day stale close.
5. Entry-only signal/execution gates.
6. Atomic package entry.

## Runtime Data Dependencies

Exact XAU/XAG native D1 timestamps/closes, broker time, symbol metadata,
quotes, completed-bar ATR, framework position/deal state, and one terminal-
persistent attempt marker. No external runtime dataset exists.

## Risk

- Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1` as one aggregate package budget.
- Each leg receives half stop risk before notional equalization.
- Each leg receives a frozen `3.5*ATR(20,D1)` hard stop and no target.
- Reject rounded target-notional mismatch above 20 percent.
- A failed second leg or malformed package flattens all owned exposure.

## Execution Assumptions

The logical basket runs on the XAU host with exact XAU/XAG dependency history,
USD tester currency, canonical 100,000 deposit, registered slot magics, native
quotes, and real ticks. CFD financing, basis, spreads, gaps, synchronization,
and legging can invalidate the edge.

## Failure Conditions

Retire on zero packages, fewer than five completed packages in any full post-
warm-up year, failed formula/enumeration fixture, malformed package behavior,
nonpositive governed economics, or downstream gate failure. No threshold,
side, sample, or hold rescue is authorized.

## Expected Behavior

Check once per month, sometimes consume flat, and open at most one two-leg
package. Never emit a standalone component stream, retry a consumed month,
hold past the next month except repair latency, or scale with statistic size.

## Logging

Log month key, endpoint keys/timestamps, twelve changes, label path, D-plus,
D-minus, observed V, assignment/tail counts, rank sum, sides, ATR/stops,
volumes, target notionals, mismatch, magics, order outcomes, repairs, and exit.

## Framework Alignment

| card rule | implementation target |
|---|---|
| framework/risk/news/Friday/stress/input contract | `Strategy_NoTradeFilter` and `OnInit` |
| endpoints, changes, Kuiper, exact tail, side, sizing, atomic orders | `Strategy_EntrySignal` and bounded helpers |
| package integrity and stale repair | `Strategy_ManageOpenPosition` |
| month lifecycle | `Strategy_ExitSignal` and package close helper |
| news axes OFF | `Strategy_NewsFilterHook` and framework initialization |

## Status

`APPROVED_FOR_BRANCH_BUILD_AND_NON_LIVE_Q01_Q02_ONLY`. This card does not
authorize optimization, portfolio admission, threshold changes, live/demo/
shadow/stress presets, deploy/live manifests, T_Live, or AutoTrading.
