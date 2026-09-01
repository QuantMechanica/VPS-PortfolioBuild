---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-XAUXAG-MAD2-RV-20260901_S01
variant_id: AI-CODEX-XAUXAG-MAD2-RV-20260901_S01
source_id: AI-CODEX-XAUXAG-MAD2-RV-20260901
ea_id: QM5_41260
slug: xauxag-mad2-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41260_xauxag-mad2-rv_card.md
execution_contract_status: APPROVED
created: 2026-09-01
created_by: Research+Development
last_updated: 2026-09-01
g0_status: APPROVED
g0_decision: decisions/2026-09-01_qm5_41260_xauxag_monthly_anderson_darling_reversion_g0.md
source_approval: decisions/2026-09-01_xauxag_monthly_anderson_darling_reversion_source_approval.md
source_author: "OpenAI Codex"
source_authors: "OpenAI Codex; F. W. Scholz; M. A. Stephens; Karsten Schweikert; CME Group; SciPy community"
source_citation: "OpenAI Codex (2026), XAU/XAG monthly exact-permutation Anderson-Darling distribution-shift reversion; supporting records Scholz and Stephens (1987), JASA 82(399), DOI 10.1080/01621459.1987.10478517; Schweikert (2018), Journal of Banking & Finance 88, DOI 10.1016/j.jbankfin.2017.11.010; CME Group, Gold & Silver Ratio Spread; SciPy 1.13.1 pinned at commit 44e4ebaac992fde33f04638b99629d23973cb9b2."
source_citations:
  - type: ai_originated_governed_source
    citation: "OpenAI Codex (2026). XAU/XAG monthly exact-permutation Anderson-Darling distribution-shift reversion."
    location: "strategy-seeds/sources/AI-CODEX-XAUXAG-MAD2-RV-20260901/source.md"
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
  - type: peer_reviewed_statistical_method
    citation: "Scholz, F. W. and Stephens, M. A. (1987). K-Sample Anderson-Darling Tests. Journal of the American Statistical Association 82(399), 918-924."
    location: "DOI 10.1080/01621459.1987.10478517; complete-paper receipt strategy-seeds/sources/AI-CODEX-XAUXAG-MAD2-RV-20260901/retrieval_route_scholz_stephens_adk_20260901.json"
    quality_tier: A
    role: continuous_no_tie_tail_weighted_rank_path_and_permutation_rationale_only
  - type: primary_statistical_software
    citation: "SciPy community (2024). scipy.stats.anderson_ksamp, SciPy 1.13.1 documentation and source."
    location: "scipy/scipy commit 44e4ebaac992fde33f04638b99629d23973cb9b2; retrieval receipt strategy-seeds/sources/AI-CODEX-XAUXAG-MAD2-RV-20260901/retrieval_route_scipy_anderson_ksamp_20260901.json"
    quality_tier: A
    role: pinned_continuous_formula_and_greater_tail_permutation_route_only
strategy_mechanic: monthly-xauxag-twelve-synchronized-completed-log-ratio-changes-fixed-six-old-six-recent-continuous-two-sample-anderson-darling-tail-weighted-rank-path-exact-924-label-permutation-half-tail-recent-rank-sum-contrarian-equal-notional-basket
sources:
  - "[[sources/AI-CODEX-XAUXAG-MAD2-RV-20260901]]"
concepts:
  - "[[concepts/gold-silver-relative-value]]"
  - "[[concepts/nonparametric-distribution-shift]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/synchronized-completed-month-log-ratio-change]]"
  - "[[indicators/anderson-darling-two-sample-rank-path]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, precious-metals, market-neutral-style, relative-value, structural-reversion, anderson-darling-two-sample, exact-label-permutation, monthly-rebalance, equal-notional-basket, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals_relative_value]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41260_XAU_XAG_MAD2_RV_D1
symbol: XAUUSD.DWX
host_symbol: XAUUSD.DWX
symbol_slot: 0
symbol_slots: [0, 1]
magic: 412600000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: paired_long_short
expected_trade_frequency: "Approximately 5-6 completed XAU/XAG packages per full post-warm-up year after thirteen synchronized completed month ends; one consumed attempt per broker month. The locked strict-rank reference leaves 448 directional assignments among 924, about 5.818 states/year before market and execution gates."
expected_trades_per_year_per_symbol: 5
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_AI_SYNTHESIS_AND_PRIMARY_METHOD_EVIDENCE
r1_reasoning: "One durable AI-originated source with complete governed peer-reviewed gold/silver evidence and adverse findings, official exchange carrier research, a complete peer-reviewed Anderson-Darling paper, pinned official SciPy documentation/source, hashes, and explicit no-performance boundaries."
r2_mechanical: PASS
r2_reasoning: "Month clock, synchronization, endpoints, adjacent changes, fixed blocks, strict ties, all eleven pooled-rank cuts, continuous formula, all 924 assignments, inclusive half-tail, side, attempt, aggregate risk, atomicity, and lifecycle are deterministic and locked."
r3_data_available: PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK
r3_reasoning: "Registered native XAUUSD.DWX and XAGUSD.DWX D1 histories and MT5 state supply every runtime input; synchronization, continuous-CFD basis, financing, and legging risks remain explicit."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, sorting, fixed finite integer loops, arithmetic, comparisons, ATR risk controls, quotes, positions, deals, and persistent state; no trained output, prohibited signal indicator, random runtime sampling, or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: 13 synchronized endpoints; 12 adjacent log-ratio changes; fixed old/recent blocks of 6; continuous no-tie Anderson-Darling statistic across 11 pooled-rank cuts; all 924 six-label assignments; relative comparison epsilon 1e-12; inclusive exact tail at most 452 and at most one half; neutral recent rank sum 39; 900 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 stops; equal target notionals; 20% notional mismatch ceiling; 40-day stale exit; 1500/500-point spread ceilings."
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
review_focus: "Falsify a monthly tail-weighted gold/silver relative-change distribution-shift fade outside the directional XAU/SP500/NDX/XNG book. Verify synchronization, change orientation, fixed membership, strict ties, every pooled-rank cut, Anderson-Darling arithmetic, all 924 assignments, inclusive tail cap 452, rank-sum side, consumed month, aggregate fixed risk, equal-notional tolerance, atomicity, and next-month lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbols_period, first_tradable_month_bar, thirteen_consecutive_completed_months, synchronized_month_end_pairs, latest_pair_per_month, chronological_log_ratio_change_orientation, fixed_six_old_six_recent_membership, strict_no_tie_changes, all_eleven_pooled_rank_cuts, continuous_anderson_darling_formula, exact_924_label_assignments, relative_inclusive_tail_tolerance, half_tail_count_452, neutral_recent_rank_sum_39, contrarian_pair_sides, monthly_attempt_state, equal_notional_pair, aggregate_fixed_risk, atomic_pair_lifecycle, hard_stops_present, friday_close_disabled, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-09-01 and decisions/2026-09-01_qm5_41260_xauxag_monthly_anderson_darling_reversion_g0.md: R1 passes through one durable AI source, complete peer-reviewed relationship and method evidence, official exchange and pinned software records, hashes, adverse findings, and explicit boundaries; R2 locks synchronization, adjacent changes, full statistic, enumeration, boundary, side, attempt, aggregate risk, atomicity, and lifecycle; R3 uses registered native XAU/XAG D1 with synchronization/CFD risk; R4 uses deterministic native arithmetic only. Corrected-root dedup found no exact identity across 4,759 registry rows, 1,396 cards, and 45 Wiki nodes; fixed label paths prove both decision-disagreement directions versus the closest KS neighbor."
---

# QM5_41260 XAU/XAG Exact-Permutation Anderson-Darling Reversion

## Hypothesis

Gold and silver share precious-metal and USD drivers but differ in monetary,
safe-haven, industrial, and business-cycle exposure. When the latest six
completed monthly gold-minus-silver log-ratio changes become tail-weightedly
different from the prior six, fade the direction of that relative
distribution shift for one broker month.

Opposite equal-target-notional legs are intended to reduce outright XAU
direction and form a market-neutral-style stream different from the
directional XAU/SP500/NDX/XNG book. They do not prove dollar, beta,
volatility, factor, market, or portfolio neutrality. Q02 owns activity and
economics; later gates own robustness; unchanged Q09 alone owns overlap.

## Source Traceability And Claim Boundary

The single governed source is
`strategy-seeds/sources/AI-CODEX-XAUXAG-MAD2-RV-20260901/source.md`, approved
and committed as `7bc1b90109` before card extraction. Schweikert and CME
support only the state-dependent relation and intermarket carrier. Scholz and
Stephens plus pinned SciPy evidence support only the continuous no-tie
tail-weighted rank statistic and permutation route. The fixed sample, exact
half-tail, rank-sum side, CFD translation, risk, atomicity, and lifecycle are
pre-result QM choices.

No statistical or trading result is imported as an efficacy claim.

## Non-Duplicate Decision

The canonical receipt
`artifacts/qm5_xauxag_mad2_rv_preallocation_dedup_20260901.json`, SHA-256
`89EC3B0A9926D4F94F0593892EC04E741DF7605AF59805BD3E7E9A6B08D67CF1`,
found no exact identity. Shared-carrier fuzzy matches are resolved by
load-bearing differences:

- `QM5_41187_xauxag-mks-rv` uses twelve ratio levels and one maximum signed
  ECDF gap. This card uses twelve adjacent ratio changes and the squared,
  tail-weighted path over every pooled-rank cut.
- `QM5_41177_xauxag-mwilcoxon-shift-rv` thresholds one cross-block rank sum
  on ratio levels. Here rank sum gives direction only after a full
  Anderson-Darling exact-tail gate on ratio changes.
- `QM5_41247_xauxag-mcusum-rv` mean-centers adjacent changes and maximizes a
  chronological cumulative deviation. This card preserves a fixed six/six
  split, searches no time cut, and enumerates pooled-rank label assignments.
- `QM5_20263_xauxag-mad-rv` is a rolling 63-D1 median/MAD fresh-cross system.
  `mad2` here identifies monthly Anderson-Darling two-sample logic; no median,
  MAD scale, daily cross, or convergence exit exists.

On a common strict pooled-rank path `RROROROROORO`, this rule qualifies at
tail 428 while KS is flat at count maxima `(0,2)`. Path `RORRROOORORO`
reverses the decision: this rule is flat at tail 484 while KS qualifies at
`(0,3)`.

Verdict:
`DISTINCT_XAUXAG_MONTHLY_ADJACENT_RATIO_CHANGE_FIXED_SIX_BY_SIX_CONTINUOUS_ANDERSON_DARLING_FULL_TAIL_WEIGHTED_RANK_PATH_EXACT_924_LABEL_HALF_TAIL_CONTRARIAN_BASKET`.

## Markets, Timeframe, And Cadence

- Host/traded slot 0: exact `XAUUSD.DWX`; companion/traded slot 1: exact
  `XAGUSD.DWX`.
- Logical tester symbol: `QM5_41260_XAU_XAG_MAD2_RV_D1` on the XAU host.
- Timeframe D1; intended magics `412600000` and `412600001`.
- Decide only on the first synchronized executable tick after a genuine
  broker-month transition and within 180 elapsed minutes of the raw host D1
  bar open.
- Formation is thirteen consecutive synchronized completed month ends;
  current-month prices are excluded.
- Hold to the next broker-month boundary; forty elapsed calendar days is
  stale repair.
- The market-free strict-rank prior is 448 directional states among 924, about
  5.818 per twelve attempts. Retire below five completed packages in any full
  post-warm-up year.

## Formula

For chronological synchronized completed-month close pairs `i=0..12`:

```text
q[i] = ln(XAU_close[i]) - ln(XAG_close[i])
r[i] = q[i+1] - q[i], i=0..11

old = r[0..5]; recent = r[6..11]
require every r[i] pairwise distinct
pool and sort all r ascending while preserving old/recent labels

for j=1..11:
    O[j] = count of old labels in pooled ranks 1..j
    R[j] = j - O[j]

A2_observed = (1/12) * sum(j=1..11):
  (((12*O[j]-6*j)^2/6) + ((12*R[j]-6*j)^2/6)) / (j*(12-j))

tail_count = 0; assignment_count = 0
for each 12-bit mask having exactly six recent labels:
    compute A2_perm from the same eleven pooled-rank cuts
    if A2_perm + 1e-12*max(1,abs(A2_observed)) >= A2_observed:
        tail_count++
    assignment_count++

require assignment_count == 924
require tail_count <= 452
require 2*tail_count <= assignment_count

W_recent = sum of pooled ranks carrying recent labels
SELL XAU / BUY XAG iff W_recent > 39
BUY XAU / SELL XAG iff W_recent < 39
FLAT otherwise
```

All closes, log ratios, changes, terms, sums, and statistics must be finite.
Invalid enumeration, excessive tail, or neutral direction consumes the month
flat. Statistic magnitude never changes risk.

## Rules

- Consume the normalized broker month before every fallible entry gate.
- Select the latest exactly timestamp-matched XAU/XAG D1 pair in each of the
  thirteen immediately prior consecutive broker months.
- Reject current-month input, missing/duplicate months, unmatched timestamps,
  nonchronological data, nonpositive closes, nonfinite arithmetic, a newest
  endpoint more than ten calendar days stale, or any exact change tie.
- Use only the fixed first six and last six changes, every pooled cut, all 924
  assignments, inclusive tail cap 452, and neutral rank sum 39.
- Both news axes, legacy news mode, and Friday close are OFF.

## 4. Entry Rules

1. Require exact EA ID, host, companion, D1 period, slots, registered magics,
   risk mode, framework inputs, and every locked strategy input.
2. Process package repair and prior-month/stale exits before entry-only gates.
3. Require a genuine new broker month within the 180-minute entry window.
4. Persist current `yyyymm` before history, signal, news, spread, quote, ATR,
   sizing, margin, or order checks. No outcome retries that month.
5. Reject owned exposure or same-magic entry deals already recorded in the
   current broker month.
6. Reconstruct thirteen consecutive synchronized completed endpoints and
   compute twelve adjacent log-ratio changes with strict invariants.
7. Compute observed A2, enumerate exactly 924 assignments, apply the inclusive
   half-tail, and map non-neutral recent rank sum to the contrarian package.
8. Require both spreads in bounds, executable quotes, completed-bar
   `ATR(20,D1)`, valid metadata, fixed-risk sizing, and target absolute-
   notional mismatch no greater than 20 percent.
9. Split aggregate stop risk equally, reduce only to equalize target
   notionals, attach frozen `3.5*ATR(20,D1)` hard stops, and no targets.
10. Submit XAU first and XAG second. Keep only one correctly directed,
    correctly registered, stop-protected position per slot; otherwise flatten
    every owned leg immediately.

## 5. Exit Rules

1. Framework kill switch and broker hard stops remain authoritative.
2. Close both legs on the first processed tick in a later normalized broker
   month before considering replacement risk.
3. Close after forty elapsed calendar days as stale repair.
4. Close every owned leg immediately if the package is orphaned, duplicated,
   same-side, wrong-symbol, wrong-magic, wrong-direction, stopless, stale, or
   outside the 20 percent notional-mismatch tolerance.
5. No intramonth flip, target, trail, break-even, partial close, Friday close,
   news exit, scale-in, grid, martingale, or pyramid is authorized.

## 6. Filters (No-Trade Module)

- Fail closed outside exact symbols, period, EA ID, slots, fixed-risk,
  news/Friday, stress, or locked-input contract.
- Reject consumed attempt, owned exposure, same-month deal, malformed
  synchronization, invalid endpoints/changes/ties, invalid A2 arithmetic or
  enumeration, excessive tail, neutral side, excessive spread, invalid quote,
  unavailable ATR, invalid stop/volume, or notional mismatch.
- Terminal-persistent state plus deal history prevents restart retries. Tester
  initialization clears only future or prior-run markers so historical runs
  stay deterministic.
- Runtime may not read futures chains, inventory, volume, open interest,
  files, APIs, forecasts, trained outputs, optimizer results, or portfolio
  state.

## 7. Trade Management Rules

- Maintain either zero exposure or one valid opposite-side two-leg package
  and one consumed attempt per broker month.
- Preserve original hard stops; close both legs before monthly renewal or
  after forty elapsed calendar days.
- Run malformed-package repair before entry-only gates on every tick and
  flatten every owned leg when package validity fails.
- Restart recovery combines the terminal-persistent month marker with owned
  positions and same-month deal history; no restart creates a second attempt.
- No randomness, adaptation, partial close, scale-in, grid, martingale, or
  pyramiding is allowed.

## 8. Parameters To Test

Q02 has one locked baseline and no optimization surface:

| input | value | contract |
|---|---:|---|
| `strategy_xag_symbol` | XAGUSD.DWX | locked |
| `strategy_endpoint_count` | 13 | locked |
| `strategy_return_count` | 12 | locked |
| `strategy_block_size` | 6 | locked |
| `strategy_assignment_count` | 924 | locked |
| `strategy_tail_numerator` | 1 | locked |
| `strategy_tail_denominator` | 2 | locked |
| `strategy_tail_count_max` | 452 | locked |
| `strategy_stat_epsilon` | 1e-12 | locked |
| `strategy_neutral_rank_sum` | 39 | locked |
| `strategy_history_bars_d1` | 900 | locked |
| `strategy_entry_window_minutes` | 180 | locked |
| `strategy_max_endpoint_gap_days` | 10 | locked |
| `strategy_atr_period_d1` | 20 | locked |
| `strategy_atr_sl_mult` | 3.5 | locked |
| `strategy_notional_ratio` | 1.0 | locked |
| `strategy_max_notional_mismatch_fraction` | 0.20 | locked |
| `strategy_max_hold_days` | 40 | locked |
| `strategy_xau_max_spread_points` | 1500 | locked |
| `strategy_xag_max_spread_points` | 500 | locked |
| `strategy_deviation_points` | 20 | locked |

Changing the sample, change definition, split, statistic, tolerance, tail,
side, risk, stop, notional target, or hold after Q02 is forbidden result-
driven repair.

## Source-Defined Rules

- Gold/silver is a state-dependent intermarket relation with distinct
  monetary and industrial drivers; no constant equilibrium is guaranteed.
- The continuous Anderson-Darling statistic aggregates weighted squared
  empirical-distribution discrepancies over the pooled-rank path and places
  more weight in pooled tails.
- Exact finite rank permutations can evaluate the observed statistic without
  importing an asymptotic critical table.
- No source-defined performance, threshold, direction, CFD equivalence,
  hedge ratio, package risk, density, or neutrality is imported.

## QM Interpretations

- Thirteen synchronized endpoints, adjacent change state, fixed six/six
  blocks, strict no-tie rule, exact half-tail, contrarian rank-sum side,
  one-month hold, equal target notionals, ATR stops, spread caps, and consumed
  attempt are transparent pre-result choices.
- Exact tail 452 is the largest support no greater than half; it is not called
  a p-value or significance level.
- Equal target notionals reduce common outright-metal direction by design;
  they are not proof of market or portfolio neutrality.

## Framework Execution Overrides

- Friday close is disabled to preserve the approved full-month hold.
- News temporal mode is OFF.
- News compliance profile is NONE.
- Legacy news mode passed to framework initialization is OFF.
- Backtest risk is fixed 1,000 account-currency units; percentage risk is zero.
- Stress rejection probability is zero in the canonical set.

## Exit Precedence

1. Framework kill switch and hard-stop enforcement.
2. Lifecycle and package-integrity repair.
3. New-broker-month close.
4. Forty-day stale close.
5. Entry-only history, signal, news, spread, quote, ATR, sizing, and margin
   gates.
6. New atomic package entry.

## Runtime Data Dependencies

Exact `XAUUSD.DWX` and `XAGUSD.DWX` native D1 timestamps and closes, broker
time, symbol metadata, quotes, completed-bar ATR, framework position/deal
state, and one terminal-persistent attempt marker. No external runtime dataset
exists.

## Risk

- Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1` as one aggregate package budget.
- Each leg receives half the stop-risk budget before notional equalization.
- Both legs receive a frozen `3.5*ATR(20,D1)` broker hard stop and no target.
- Execution rejects a package whose rounded absolute target notionals differ
  by more than 20 percent.
- Failed second-leg submission or any malformed package flattens all owned
  exposure immediately; no naked-leg strategy exists.

## Execution Assumptions

The Q02 logical basket runs on the XAU host with exact XAU/XAG dependency
history, USD tester currency, canonical 100,000 deposit, registered slot
magics, native quotes, and real-tick execution. Continuous CFD financing,
basis, spread, gaps, synchronization, and legging can invalidate the edge.

## Failure Conditions

Retire on zero packages, fewer than five completed packages in any full
post-warm-up year, failed formula or permutation fixture, nondeterministic
enumeration, malformed package behavior, nonpositive governed economics, or
any downstream gate failure. No threshold, side, sample, or hold rescue is
authorized.

## Expected Behavior

The EA checks once per genuine broker month, often consumes flat, and opens at
most one two-leg package. It should never emit a component-leg standalone
stream, retry within a consumed month, hold beyond the next month except for
stale repair latency, or scale exposure with statistic magnitude.

## Logging

Log normalized month key, endpoint keys/timestamps, twelve changes, pooled
label path, observed A2, assignment count, tail count, recent rank sum, chosen
sides, both ATR/stop distances, raw and rounded volumes, target notionals,
mismatch fraction, both magics, order outcomes, repair action, and exit reason.
Never log credentials or external account data.

## Framework Alignment

| card rule | module / implementation target |
|---|---|
| framework, risk, news, Friday, stress, locked-input contract | `Strategy_NoTradeFilter` plus `OnInit` framework validation |
| synchronized endpoints, changes, A2, exact tail, rank-sum side, quotes, ATR, sizing, atomic orders | `Strategy_EntrySignal` and bounded helpers |
| orphan/duplicate/side/magic/stop/notional/staleness repair | `Strategy_ManageOpenPosition` |
| new-month and forty-day lifecycle | `Strategy_ExitSignal` plus package close helper |
| both news axes OFF | `Strategy_NewsFilterHook` and framework initialization |

## Status

`APPROVED_FOR_BRANCH_BUILD_AND_NON_LIVE_Q01_Q02_ONLY`. This card does not
authorize optimization, portfolio admission, threshold changes, live/demo/
shadow/stress presets, deploy/live manifests, T_Live, or AutoTrading.
