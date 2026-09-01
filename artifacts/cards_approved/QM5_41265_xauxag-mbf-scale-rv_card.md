---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-XAUXAG-MBF-SCALE-RV-20260901_S01
variant_id: AI-CODEX-XAUXAG-MBF-SCALE-RV-20260901_S01
source_id: AI-CODEX-XAUXAG-MBF-SCALE-RV-20260901
ea_id: QM5_41265
slug: xauxag-mbf-scale-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41265_xauxag-mbf-scale-rv_card.md
execution_contract_status: APPROVED
created: 2026-09-01
created_by: Research+Development
last_updated: 2026-09-01
g0_status: APPROVED
g0_decision: decisions/2026-09-01_qm5_41265_xauxag_monthly_brown_forsythe_scale_reversion_g0.md
source_approval: decisions/2026-09-01_xauxag_monthly_brown_forsythe_scale_reversion_source_approval.md
source_author: "OpenAI Codex"
source_authors: "OpenAI Codex; Morton B. Brown; Alan B. Forsythe; Karsten Schweikert; CME Group; NIST/SEMATECH; SciPy community"
source_citation: "OpenAI Codex (2026), XAU/XAG monthly Brown-Forsythe scale-expansion reversion; supporting records Brown and Forsythe (1974), JASA 69(346), DOI 10.1080/01621459.1974.10482955; Schweikert (2018), Journal of Banking & Finance 88, DOI 10.1016/j.jbankfin.2017.11.010; CME Group, Gold & Silver Ratio Spread; NIST/SEMATECH Levene formula; SciPy 1.18.0 signed-tag-pinned source."
source_citations:
  - type: ai_originated_governed_source
    citation: "OpenAI Codex (2026). XAU/XAG monthly Brown-Forsythe scale-expansion reversion."
    location: "strategy-seeds/sources/AI-CODEX-XAUXAG-MBF-SCALE-RV-20260901/source.md"
    quality_tier: governed_source
    role: exact_trading_hypothesis_formula_activity_boundary_execution_risk_atomicity_and_lifecycle
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
    citation: "Brown, M. B. and Forsythe, A. B. (1974). Robust Tests for the Equality of Variances. Journal of the American Statistical Association 69(346), 364-367."
    location: "DOI 10.1080/01621459.1974.10482955; publisher metadata/abstract only, with explicit body-access boundary"
    quality_tier: A_metadata_boundary
    role: named_median_centered_robust_scale_method_identity_only
  - type: official_statistical_reference
    citation: "NIST/SEMATECH. Levene Test for Equality of Variances."
    location: "complete official formula; retrieval_route_brown_forsythe_20260901.json"
    quality_tier: A_official
    role: median_absolute_deviation_anova_statistic_and_robustness_guidance
  - type: primary_statistical_software
    citation: "SciPy community (2026). scipy.stats.levene, SciPy 1.18.0 documentation and signed-tag-pinned source."
    location: "commit 54ef5423f2e4376230ec3bfda6912a07a50958e3; retrieval_route_scipy_levene_20260901.json"
    quality_tier: A_official
    role: independent_exact_arithmetic_cross_check_only
strategy_mechanic: monthly-xauxag-thirteen-synchronized-completed-log-ratio-endpoints-twelve-adjacent-changes-fixed-six-old-six-recent-brown-forsythe-median-centered-absolute-deviation-recent-scale-expansion-median-shift-contrarian-equal-notional-basket
sources:
  - "[[sources/AI-CODEX-XAUXAG-MBF-SCALE-RV-20260901]]"
concepts:
  - "[[concepts/gold-silver-relative-value]]"
  - "[[concepts/robust-scale-shift]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/synchronized-completed-month-log-ratio-change]]"
  - "[[indicators/brown-forsythe-median-scale-state]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, precious-metals, market-neutral-style, relative-value, structural-reversion, brown-forsythe, robust-scale-expansion, monthly-rebalance, equal-notional-basket, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals_relative_value]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41265_XAU_XAG_MBF_SCALE_RV_D1
symbol: XAUUSD.DWX
host_symbol: XAUUSD.DWX
symbol_slot: 0
symbol_slots: [0, 1]
magic: 412650000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: paired_long_short
expected_trade_frequency: "Approximately 5-6 completed XAU/XAG packages per full post-warm-up year after thirteen synchronized completed month ends; one consumed attempt per broker month. Equal-block label-swap symmetry places recent scale expansion on one side of each non-tied block pair, about six states/year before market and execution gates."
expected_trades_per_year_per_symbol: 5
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_AI_SYNTHESIS_AND_PRIMARY_METHOD_EVIDENCE
r1_reasoning: "One durable AI-originated source; complete governed peer-reviewed gold/silver evidence and adverse findings; official exchange carrier research; named peer-reviewed Brown-Forsythe method metadata with explicit access boundary; complete official NIST formula; signed-tag-pinned official SciPy documentation/source; explicit no-performance boundary."
r2_mechanical: PASS
r2_reasoning: "Month clock, synchronization, endpoints, adjacent changes, fixed blocks, even medians, absolute deviations, group and grand means, between/within sums, statistic, tolerances, scale gate, side, attempt, aggregate risk, atomicity, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_reasoning: "Registered native XAUUSD.DWX and XAGUSD.DWX D1 histories and MT5 state supply every runtime input; synchronization, continuous-CFD basis, financing, and legging risks remain explicit."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, sorting, absolute values, fixed finite arithmetic, comparisons, ATR risk controls, quotes, positions, deals, and persistent state; no trained output, prohibited signal indicator, random runtime sampling, or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: 13 synchronized endpoints; 12 adjacent log-ratio changes; fixed old/recent blocks of 6; even median as sorted indices 2/3 average; 12 median-centered absolute deviations; exact Brown-Forsythe between/within arithmetic with multiplier 10; minimum within sum 1e-18; relative comparison epsilon 1e-12; recent scale expansion only; median-shift contrarian side; 900 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 stops; equal target notionals; 20% notional mismatch ceiling; 40-day stale exit; 1500/500-point spread ceilings."
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
review_focus: "Falsify a monthly robust-scale gold/silver relative-change fade outside the directional XAU/SP500/NDX/XNG book. Verify synchronization, change orientation, fixed membership, even medians, deviations, means, between/within sums, multiplier ten, nondegenerate denominator, relative tolerances, recent-only scale expansion, median-shift side, consumed month, aggregate fixed risk, equal-notional tolerance, atomicity, and next-month lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbols_period, first_tradable_month_bar, thirteen_consecutive_completed_months, synchronized_month_end_pairs, latest_pair_per_month, chronological_log_ratio_change_orientation, fixed_six_old_six_recent_membership, even_sample_medians, median_centered_absolute_deviations, exact_group_and_grand_means, exact_between_within_sums, brown_forsythe_multiplier_ten, nondegenerate_within_sum, relative_scale_tolerance, recent_scale_expansion_only, relative_location_tolerance, contrarian_pair_sides, no_f_critical_or_pvalue_claim, monthly_attempt_state, equal_notional_pair, aggregate_fixed_risk, atomic_pair_lifecycle, hard_stops_present, friday_close_disabled, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-09-01 and decisions/2026-09-01_qm5_41265_xauxag_monthly_brown_forsythe_scale_reversion_g0.md: R1 passes through one durable AI source, complete peer-reviewed carrier evidence, official exchange evidence, a named peer-reviewed method record with body-access boundary, complete official NIST formula, signed-tag-pinned SciPy source, hashes, adverse findings, and explicit synthesis boundaries; R2 locks synchronization, changes, blocks, medians, deviations, statistic, tolerances, side, attempt, aggregate risk, atomicity, and lifecycle; R3 uses registered native XAU/XAG D1 with synchronization/CFD risk; R4 uses deterministic native arithmetic only. Corrected-root dedup found no exact identity across 4,764 registry rows, 1,401 cards, and 45 Wiki nodes; fixed fixtures prove qualification and side disagreement with the closest Anderson-Darling and Kuiper neighbors."
---

# QM5_41265 XAU/XAG Brown-Forsythe Scale-Expansion Reversion

## Hypothesis

Gold and silver share precious-metal and USD drivers but differ in monetary,
safe-haven, industrial, and business-cycle exposure. When the dispersion of
the latest six completed monthly gold-minus-silver log-ratio changes expands
relative to the prior six and their robust centers differ, fade that relative
center shift for one broker month.

Opposite equal-target-notional legs are intended to reduce outright XAU
direction and form a market-neutral-style stream different from the
directional XAU/SP500/NDX/XNG book. They do not prove dollar, beta, volatility,
factor, market, or portfolio neutrality. Q02 owns activity and economics;
later gates own robustness; unchanged Q09 alone owns overlap.

## Source Traceability And Claim Boundary

The single governed source is
`strategy-seeds/sources/AI-CODEX-XAUXAG-MBF-SCALE-RV-20260901/source.md`,
approved and committed as `7b13861f51` before card extraction. Schweikert and
CME support only the state-dependent relation and intermarket carrier. Brown
and Forsythe, NIST, and signed-tag-pinned SciPy evidence support only the
median-centered absolute-deviation scale arithmetic. The fixed sample,
recent-expansion direction, median-shift fade, CFD translation, risk,
atomicity, and lifecycle are pre-result QM choices.

The peer-reviewed method paper body was not fully accessible. The card claims
only publisher metadata/abstract for that paper and relies on the complete
official NIST formula and pinned SciPy source for exact arithmetic. No
statistical or trading result is imported as an efficacy claim.

## Non-Duplicate Decision

The canonical receipt
`artifacts/qm5_xauxag_mbf_scale_rv_preallocation_dedup_20260901.json`, SHA-256
`9715671276140E339ACBD27B1F855EC12353FF52010448CEE116821FB36CA95F`,
found no exact identity. The only fuzzy hit was the expected shared-carrier
Kuiper neighbor.

- `QM5_41263` and `QM5_41260` pool and rank all changes, qualify through full
  empirical-distribution path statistics and exact label tails, and use rank
  sum for side. This card preserves numeric within-block distance, centers
  each block on its own median, compares mean absolute deviations, uses no
  permutation tail, and takes side from the two block medians.
- `QM5_20263_xauxag-mad-rv` is a daily 63-bar ratio-level rolling median/MAD
  fresh cross with convergence exit. This card uses fixed monthly adjacent
  changes and a next-month exit.
- `QM5_41247_xauxag-mcusum-rv` searches a centered chronological cumulative-
  deviation split. This card has a fixed six/six split and no change-point
  search.

Fixed no-tie fixtures in the source prove: this card can trade while both
rank-path rules are neutral; it can remain flat while both trade; and it can
take the opposite side while both qualify.

Verdict:
`DISTINCT_XAUXAG_MONTHLY_ADJACENT_RATIO_CHANGE_FIXED_SIX_BY_SIX_BROWN_FORSYTHE_MEDIAN_CENTERED_RECENT_SCALE_EXPANSION_MEDIAN_SHIFT_CONTRARIAN_BASKET`.

## Markets, Timeframe, And Cadence

- Host/traded slot 0: exact `XAUUSD.DWX`; companion/traded slot 1: exact
  `XAGUSD.DWX`.
- Logical tester symbol: `QM5_41265_XAU_XAG_MBF_SCALE_RV_D1` on the XAU host.
- Timeframe D1; intended magics `412650000` and `412650001`.
- Decide only on the first synchronized executable tick after a genuine
  broker-month transition and within 180 elapsed minutes of the raw host D1
  bar open.
- Formation is thirteen consecutive synchronized completed month ends;
  current-month prices are excluded.
- Hold to the next broker-month boundary; forty elapsed calendar days is
  stale repair.
- Equal-block label-swap symmetry implies about six qualifying recent-scale-
  expansion states per twelve attempts before market and execution gates.
  Retire below five completed packages in any full post-warm-up year.

## Formula

For chronological synchronized completed-month close pairs `i=0..12`:

```text
q[i] = ln(XAU_close[i]) - ln(XAG_close[i])
r[i] = q[i+1] - q[i], i=0..11

old = r[0..5]; recent = r[6..11]
m_old = (sort(old)[2] + sort(old)[3]) / 2
m_recent = (sort(recent)[2] + sort(recent)[3]) / 2

z_old[i] = abs(old[i]-m_old)
z_recent[i] = abs(recent[i]-m_recent)
zb_old = sum(z_old)/6
zb_recent = sum(z_recent)/6
zb_all = (zb_old+zb_recent)/2

ss_between = 6*(zb_old-zb_all)^2 + 6*(zb_recent-zb_all)^2
ss_within = sum((z_old[i]-zb_old)^2) + sum((z_recent[i]-zb_recent)^2)
require ss_within > 1e-18
W = 10*ss_between/ss_within
require finite W

require zb_recent > zb_old + 1e-12*max(1,abs(zb_old),abs(zb_recent))
delta = m_recent-m_old

SELL XAU / BUY XAG iff delta >  1e-12*max(1,abs(m_old),abs(m_recent))
BUY XAU / SELL XAG iff delta < -1e-12*max(1,abs(m_old),abs(m_recent))
FLAT otherwise
```

All closes, log ratios, changes, sorted values, medians, deviations, sums,
squares, and statistics must be finite. Invalid arithmetic, non-expanding
recent scale, or neutral location consumes the month flat. `W` is not compared
with an F critical value, called a p-value, or used to change risk.

## Rules

- Consume the normalized broker month before every fallible entry gate.
- Select the latest exactly timestamp-matched XAU/XAG D1 pair in each of the
  thirteen immediately prior consecutive broker months.
- Reject current-month input, missing/duplicate months, unmatched timestamps,
  nonchronological data, nonpositive closes, nonfinite arithmetic, or a newest
  endpoint more than ten calendar days stale.
- Preserve the first six and last six changes as fixed blocks. Sort copies
  only for the two medians; never mutate chronological membership.
- Trade only a finite, nondegenerate recent scale expansion with a non-neutral
  median shift, using the exact contrarian sides in the formula.
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
7. Compute both medians, all deviations, exact Brown-Forsythe arithmetic,
   relative scale expansion, and non-neutral median-shift side.
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
  synchronization, invalid endpoints/changes, invalid median/deviation/
  statistic arithmetic, non-expanding recent scale, neutral median shift,
  excessive spread, invalid quote, unavailable ATR, invalid stop/volume, or
  notional mismatch.
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
| `strategy_bf_multiplier` | 10.0 | locked `(N-k)/(k-1)` |
| `strategy_min_within_ss` | 1e-18 | locked denominator floor |
| `strategy_relative_epsilon` | 1e-12 | locked scale/location tolerance |
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

Changing the sample, change definition, split, center, deviation transform,
statistic arithmetic, tolerances, scale direction, side, risk, stop, notional
target, or hold after Q02 is forbidden result-driven repair.

## Source-Defined Rules

- Gold/silver is a state-dependent intermarket relation with distinct
  monetary and industrial drivers; no constant equilibrium is guaranteed.
- Brown-Forsythe's median form transforms each group into absolute deviations
  from its own median and applies between/within one-way-ANOVA arithmetic.
- No source defines the recent-only scale condition, median-shift trading
  side, sample, CFD equivalence, package risk, density, or neutrality.

## QM Interpretations

- Thirteen synchronized endpoints, adjacent change state, fixed six/six
  blocks, recent dispersion direction, median-shift fade, one-month hold,
  equal target notionals, ATR stops, spread caps, and consumed attempt are
  transparent pre-result choices.
- `W` is an arithmetic integrity diagnostic, not a significance or p-value
  claim; no critical-value lookup enters the EA.
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

Retire on zero packages, fewer than five in any full post-warm-up year, failed
formula fixtures, malformed package behavior, nonpositive governed economics,
or any downstream gate failure. No threshold, side, sample, center, or hold
rescue is authorized.

## Expected Behavior

The EA checks once per genuine broker month, often consumes flat, and opens at
most one two-leg package. It should never emit a component-leg standalone
stream, retry within a consumed month, hold beyond the next month except for
stale repair latency, or scale exposure with statistic magnitude.

## Logging

Log normalized month key, endpoint keys/timestamps, twelve changes, old/recent
medians, old/recent absolute-deviation means, between/within sums, `W`, chosen
sides, both ATR/stop distances, raw and rounded volumes, target notionals,
mismatch fraction, both magics, order outcomes, repair action, and exit reason.
Never log credentials or external account data.

## Framework Alignment

| card rule | module / implementation target |
|---|---|
| framework, risk, news, Friday, stress, locked-input contract | `Strategy_NoTradeFilter` plus `OnInit` framework validation |
| synchronized endpoints, changes, medians, deviations, Brown-Forsythe arithmetic, scale and side, quotes, ATR, sizing, atomic orders | `Strategy_EntrySignal` and bounded helpers |
| orphan/duplicate/side/magic/stop/notional/staleness repair | `Strategy_ManageOpenPosition` |
| new-month and forty-day lifecycle | `Strategy_ExitSignal` plus package close helper |
| both news axes OFF | `Strategy_NewsFilterHook` and framework initialization |

## Falsification And Requalification

Any change to the symbols, timeframe, endpoint count, change orientation,
block split, median, deviation transform, means, sums, denominator, statistic,
tolerances, side mapping, attempt timing, risk, stop, spread cap, or exit
requires a new binary and full pipeline requalification. Ambiguous history,
arithmetic, or state fails closed. Q02 may kill the card but may not tune it;
Q09 alone may establish decorrelation.

## Safety Boundary

This card authorizes only one branch build, deterministic reference tests,
strict Q01, one logical plus two component D1 `RISK_FIXED` backtest setfiles,
and one paced non-live logical-basket Q02 handoff if the governed CPU ceiling
permits. It does not authorize a manual tester run; optimization; live/demo/
shadow/stress setfile; AutoTrading; `T_Live`; deploy or live manifest;
portfolio-gate mutation; portfolio admission; component Q02 row; or
correlation waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-09-01 | initial monthly Brown-Forsythe XAU/XAG scale-expansion card | G0 | APPROVED; build pending |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-09-01 | APPROVED; R1-R4 PASS | source approval, corrected-root dedup receipt, G0 decision, and this card |
| Q01 Build Validation | - | NOT_BUILT | pending magic allocation and exact implementation |
| Q02 Baseline Screening | - | NOT_ENQUEUED_Q01_PENDING | one paced enqueue only after strict Q01 and CPU admission |
