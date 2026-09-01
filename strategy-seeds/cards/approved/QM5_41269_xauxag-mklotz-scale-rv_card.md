---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-XAUXAG-MKLOTZ-SCALE-RV-20260901_S01
variant_id: AI-CODEX-XAUXAG-MKLOTZ-SCALE-RV-20260901_S01
source_id: AI-CODEX-XAUXAG-MKLOTZ-SCALE-RV-20260901
ea_id: QM5_41269
slug: xauxag-mklotz-scale-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41269_xauxag-mklotz-scale-rv_card.md
execution_contract_status: APPROVED
created: 2026-09-01
created_by: Research+Development
last_updated: 2026-09-01
g0_status: APPROVED
g0_decision: decisions/2026-09-01_qm5_41269_xauxag_monthly_klotz_scale_reversion_g0.md
source_approval: decisions/2026-09-01_xauxag_monthly_klotz_scale_reversion_source_approval.md
source_author: "OpenAI Codex"
source_authors: "OpenAI Codex; Jerome Klotz; Karsten Schweikert; CME Group; NIST/SEMATECH"
source_citation: "OpenAI Codex (2026), XAU/XAG monthly centered Klotz scale-state reversion; supporting records Klotz (1962), The Annals of Mathematical Statistics 33(2), DOI 10.1214/aoms/1177704576; Schweikert (2018), Journal of Banking & Finance 88, DOI 10.1016/j.jbankfin.2017.11.010; CME Group, Gold & Silver Ratio Spread; NIST/SEMATECH Klotz Score and Klotz Test."
source_citations:
  - type: ai_originated_governed_source
    citation: "OpenAI Codex (2026). XAU/XAG monthly centered Klotz scale-state reversion."
    location: "strategy-seeds/sources/AI-CODEX-XAUXAG-MKLOTZ-SCALE-RV-20260901/source.md"
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
    citation: "Klotz, J. (1962). Nonparametric Tests for Scale. The Annals of Mathematical Statistics 33(2), 498-512."
    location: "DOI 10.1214/aoms/1177704576; authoritative Crossref metadata with explicit publisher-body access boundary"
    quality_tier: A_metadata_boundary
    role: named_nonparametric_squared_normal_score_scale_method_identity_only
  - type: official_statistical_reference
    citation: "NIST/SEMATECH Dataplot. Klotz Score; Klotz Test."
    location: "complete official pages and hashes in retrieval_route_nist_klotz_20260901.json"
    quality_tier: A_official
    role: separate_mean_centering_score_formula_test_statistic_and_approximation_boundary
strategy_mechanic: monthly-xauxag-thirteen-synchronized-completed-month-log-ratio-endpoints-twelve-adjacent-changes-fixed-six-old-six-recent-within-block-mean-centered-residuals-strict-pooled-ranks-fixed-squared-normal-klotz-scores-exact-924-inclusive-upper-half-recent-mean-shift-contrarian-equal-notional-basket
sources:
  - "[[sources/AI-CODEX-XAUXAG-MKLOTZ-SCALE-RV-20260901]]"
concepts:
  - "[[concepts/gold-silver-relative-value]]"
  - "[[concepts/robust-scale-shift]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/synchronized-completed-month-log-ratio-change]]"
  - "[[indicators/centered-klotz-squared-normal-score-state]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, precious-metals, market-neutral-style, relative-value, structural-reversion, klotz, squared-normal-score, monthly-rebalance, equal-notional-basket, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals_relative_value]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41269_XAU_XAG_KLOTZ_SCALE_RV_D1
symbol: XAUUSD.DWX
host_symbol: XAUUSD.DWX
symbol_slot: 0
symbol_slots: [0, 1]
magic: 412690000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: paired_long_short
expected_trade_frequency: "Approximately 5-6 completed XAU/XAG packages per full post-warm-up year after thirteen synchronized completed month ends; one consumed attempt per broker month. The frozen no-tie six-rank label support admits 494/924 inclusive upper-half Klotz states, or about 6.416 states/year before centered-rank feasibility, neutral raw mean, data, and execution gates."
expected_trades_per_year_per_symbol: 5
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_AI_SYNTHESIS_AND_PRIMARY_METHOD_EVIDENCE
r1_reasoning: "One durable AI-originated source; complete governed peer-reviewed gold/silver evidence and adverse findings; official exchange carrier research; named peer-reviewed Klotz metadata with explicit body-access boundary; complete official NIST formula pages and hashes; explicit no-performance boundary."
r2_mechanical: PASS
r2_reasoning: "Month clock, synchronization, endpoints, adjacent changes, fixed blocks, arithmetic means, centered residuals, strict tie tolerance, rank orientation, frozen score table, diagnostic, all 924 labels, inclusive boundary, raw-mean side, attempt, aggregate risk, atomicity, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_reasoning: "Registered native XAUUSD.DWX and XAGUSD.DWX D1 histories and MT5 state supply every runtime input; synchronization, continuous-CFD basis, financing, and legging risks remain explicit."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, sorting, fixed score constants, bounded integer enumeration, arithmetic, comparisons, ATR risk controls, quotes, positions, deals, and persistent state; no trained output, prohibited signal indicator, random runtime sampling, or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: 13 synchronized endpoints; 12 adjacent log-ratio changes; fixed old/recent blocks of 6; separate arithmetic-mean centering; pooled centered-residual rank ascending; strict relative tie epsilon 1e-12; frozen N=12 Klotz Phi^-1(rank/13)^2 scores; K_expected 3.9642160041063397; K denominator 1.2716448806860048; all 924 six-rank assignments; inclusive match-or-exceed tolerance 1e-12; upper-tail cap 494; raw block-mean contrarian side; 900 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 stops; equal target notionals; 20% notional mismatch ceiling; 40-day stale exit; 1500/500-point spread ceilings."
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
review_focus: "Falsify a monthly centered-normal-score gold/silver relative-change fade outside the directional XAU/SP500/NDX/XNG book. Verify synchronization, change orientation, fixed membership, separate means, centered residuals, tie rejection, pooled rank direction, all frozen scores, expected sum and denominator, exact 924 enumeration, inclusive upper tail, raw-mean contrarian side, consumed month, aggregate fixed risk, equal-notional tolerance, atomicity, and next-month lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbols_period, first_tradable_month_bar, thirteen_consecutive_completed_months, synchronized_month_end_pairs, latest_pair_per_month, chronological_log_ratio_change_orientation, fixed_six_old_six_recent_membership, separate_arithmetic_mean_centering, centered_residual_tie_rejection, ascending_pooled_residual_ranks, frozen_n12_klotz_scores, exact_expected_sum_and_denominator, exact_924_label_enumeration, inclusive_upper_tail_494, raw_mean_shift_contrarian_pair_sides, no_normal_critical_or_pvalue_claim, monthly_attempt_state, equal_notional_pair, aggregate_fixed_risk, atomic_pair_lifecycle, hard_stops_present, friday_close_disabled, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-09-01 and decisions/2026-09-01_qm5_41269_xauxag_monthly_klotz_scale_reversion_g0.md: R1 passes through one durable AI source, complete peer-reviewed carrier evidence, official exchange evidence, a named peer-reviewed method record with body-access boundary, complete official NIST formula pages, hashes, adverse findings, and explicit synthesis boundaries; R2 locks synchronization, changes, blocks, means, residuals, ranks, scores, enumeration, boundary, side, attempt, aggregate risk, atomicity, and lifecycle; R3 uses registered native XAU/XAG D1 with synchronization/CFD risk; R4 uses deterministic native arithmetic only. Corrected-root dedup found no exact identity across 4,768 registry rows, 1,405 cards, and 45 Wiki nodes; fixed fixtures prove qualification and side disagreement with the closest Brown-Forsythe and Kuiper neighbors."
---

# QM5_41269 XAU/XAG Centered Klotz Scale-State Reversion

## Hypothesis

Gold and silver share precious-metal and USD drivers but differ in monetary,
safe-haven, industrial, and business-cycle exposure. When separately centered
residuals from the latest six completed monthly gold-minus-silver log-ratio
changes carry at least the inclusive upper-half Klotz squared-normal tail
mass, fade the recent raw relative-return mean shift for one broker month.

Opposite equal-target-notional legs are intended to reduce outright XAU
direction and form a market-neutral-style stream different from the
directional XAU/SP500/NDX/XNG book. They do not prove dollar, beta, volatility,
factor, market, or portfolio neutrality. Q02 owns activity and economics;
later gates own robustness; unchanged Q09 alone owns overlap.

## Source Traceability And Claim Boundary

The single governed source is
`strategy-seeds/sources/AI-CODEX-XAUXAG-MKLOTZ-SCALE-RV-20260901/source.md`,
approved and committed as `8d5199c31ba3` before card extraction. Schweikert
and CME support only the state-dependent relation and intermarket carrier.
Klotz metadata and complete official NIST pages support only the named scale
method, separate-mean centering, squared-normal rank-score formula, and
standardized arithmetic. The fixed sample, strict ties, frozen constants,
inclusive activity boundary, raw-mean fade, CFD translation, risk, atomicity,
and lifecycle are pre-result QM choices.

The peer-reviewed Klotz paper body was not accessible. This card claims only
authoritative metadata for that paper and relies on the complete official
NIST pages for implementation arithmetic. It does not import a critical
value, p-value, exact test, or trading result as an efficacy claim.

## Non-Duplicate Decision

The canonical receipt
`artifacts/qm5_xauxag_mklotz_scale_rv_preallocation_dedup_20260901.json`,
SHA-256
`2C5ECB7A982F2C7994F0F1B4EE362A34FB9CC789B53272CF41BB9C3ACC5D565D`,
found no exact identity and surfaced only expected Brown-Forsythe and Kuiper
fuzzy neighbors.

- `QM5_41265` retains numeric absolute deviations around separate medians and
  takes side from a median shift. This card separately mean-centers, discards
  residual spacing after ranking, sums nonlinear squared-normal scores, and
  takes side from the raw mean shift.
- `QM5_41263` ranks uncentered changes, keeps opposing ECDF extrema, and uses
  raw rank sum for side. This card ranks centered residuals, aggregates a
  six-score Klotz state, and obtains side independently from raw means.
- Anderson-Darling, Ansari-Bradley, Mood, CUSUM, OLS, CADF, z-score, calendar,
  and breakout cards use different state objects, score geometry, direction,
  or lifecycle.

Fixed fixtures in the source prove a Klotz-only trade, a Brown-Forsythe-only
trade, and a case where both qualify but take opposite sides.

Verdict:
`DISTINCT_XAUXAG_MONTHLY_SEPARATE_MEAN_CENTERED_RESIDUAL_STRICT_RANK_FROZEN_KLOTZ_SQUARED_NORMAL_SCORE_EXACT_924_INCLUSIVE_UPPER_HALF_RAW_MEAN_SHIFT_CONTRARIAN_BASKET`.

## Markets, Timeframe, And Cadence

- Host/traded slot 0: exact `XAUUSD.DWX`; companion/traded slot 1: exact
  `XAGUSD.DWX`.
- Logical tester symbol: `QM5_41269_XAU_XAG_KLOTZ_SCALE_RV_D1` on the XAU
  host.
- Timeframe D1; intended magics `412690000` and `412690001`.
- Decide only on the first synchronized executable tick after a genuine
  broker-month transition and within 180 elapsed minutes of the raw host D1
  bar open.
- Formation is thirteen consecutive synchronized completed month ends;
  current-month prices are excluded.
- Hold to the next broker-month boundary; forty elapsed calendar days is
  stale repair.
- The frozen inclusive upper-half label support admits 494/924 states, about
  6.416 per twelve unconstrained monthly attempts before realized gates.
  Retire below five completed packages in any full post-warm-up year.

## Formula

For chronological synchronized completed-month close pairs `i=0..12`:

```text
q[i] = ln(XAU_close[i]) - ln(XAG_close[i])
r[i] = q[i+1] - q[i], i=0..11

old = r[0..5]; recent = r[6..11]
mu_old = sum(old)/6; mu_recent = sum(recent)/6
e_old[i] = old[i]-mu_old; e_recent[i] = recent[i]-mu_recent
require all twelve residuals pairwise distinct under relative epsilon 1e-12

pool residuals ascending, preserving labels
score(rank) = frozen Phi^-1(rank/13)^2 table from the source
K_recent = sum(scores carrying recent labels)
K_expected = 3.9642160041063397
K_den = 1.2716448806860048
T1 = (K_recent-K_expected)/K_den
require finite K_recent and T1

enumerate every C(12,6)=924 six-rank assignment
tail_count = count(K_perm + 1e-12*max(1,abs(K_recent)) >= K_recent)
require assignment_count == 924
require K_recent + 1e-12*max(1,abs(K_expected)) >= K_expected
require tail_count <= 494

delta = mu_recent-mu_old
SELL XAU / BUY XAG iff delta >  1e-12*max(1,abs(mu_old),abs(mu_recent))
BUY XAU / SELL XAG iff delta < -1e-12*max(1,abs(mu_old),abs(mu_recent))
FLAT otherwise
```

All closes, log ratios, changes, means, residuals, scores, sums, and
diagnostics must be finite. A tie, invalid arithmetic, lower-half score, or
neutral raw mean consumes the month flat. `T1` and `tail_count` are integrity
diagnostics and activity gates; neither is called a p-value or used to change
risk.

## Rules

- Consume the normalized broker month before every fallible entry gate.
- Select the latest exactly timestamp-matched XAU/XAG D1 pair in each of the
  thirteen immediately prior consecutive broker months.
- Reject current-month input, missing/duplicate months, unmatched timestamps,
  nonchronological data, nonpositive closes, nonfinite arithmetic, or a newest
  endpoint more than ten calendar days stale.
- Preserve fixed old/recent membership. Center each block on its own raw mean;
  sort only pooled residual copies and never mutate chronological membership.
- Reject residual ties rather than averaging tied ranks, preserving the
  frozen no-tie score and enumeration contract.
- Trade only an inclusive upper-half recent Klotz state with a non-neutral raw
  mean shift, using the exact contrarian pair sides in the formula.
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
7. Compute both means, centered residuals, strict ranks, frozen Klotz scores,
   `T1`, all 924 assignment sums, inclusive tail, and raw-mean side.
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
  synchronization, invalid endpoints/changes, invalid means/residuals/ranks/
  score/enumeration arithmetic, lower-half state, neutral raw mean, excessive
  spread, invalid quote, unavailable ATR, invalid stop/volume, or notional
  mismatch.
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
| `strategy_relative_epsilon` | 1e-12 | locked tie/score/location tolerance |
| `strategy_klotz_expected` | 3.9642160041063397 | locked equal-label sum |
| `strategy_klotz_denominator` | 1.2716448806860048 | locked NIST diagnostic denominator |
| `strategy_assignment_count` | 924 | locked complete six-rank enumeration |
| `strategy_tail_count_max` | 494 | locked inclusive upper-half boundary |
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

The twelve rank scores are compile-time constants, not user inputs. Changing
the sample, change definition, split, centering, tie rule, scores, enumeration,
boundary, side, risk, stop, notional target, or hold after Q02 is forbidden
result-driven repair.

## Source-Defined Rules

- Gold/silver is a state-dependent intermarket relation with distinct
  monetary and industrial drivers; no constant equilibrium is guaranteed.
- NIST's Klotz construction separately subtracts sample means, pools the
  centered observations, and assigns squared standard-normal quantile scores
  by rank.
- NIST's published critical route is approximate. No source defines the
  inclusive 494 activity boundary, raw-mean trading side, sample, CFD
  equivalence, package risk, density, or neutrality.

## QM Interpretations

- Thirteen synchronized endpoints, adjacent-change state, fixed six/six
  blocks, strict tie rejection, frozen binary64 scores, complete label audit,
  inclusive upper-half state, raw-mean fade, one-month hold, equal target
  notionals, ATR stops, spread caps, and consumed attempt are transparent
  pre-result choices.
- `T1` and the exact inclusive label count are arithmetic integrity values,
  not significance or p-value claims.
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
or runtime inverse-normal function exists.

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
formula/enumeration fixtures, accepted ties, malformed package behavior,
nonpositive governed economics, or any downstream gate failure. No threshold,
side, sample, centering, score, or hold rescue is authorized.

## Expected Behavior

The EA checks once per genuine broker month, often consumes flat, and opens at
most one two-leg package. It should never emit a component-leg standalone
stream, retry within a consumed month, hold beyond the next month except for
stale repair latency, or scale exposure with score or mean-shift magnitude.

## Logging

Log normalized month key, endpoint keys/timestamps, twelve changes, both raw
means, twelve centered residuals and ranks, recent Klotz sum, expectation,
`T1`, enumeration and tail counts, chosen sides, both ATR/stop distances, raw
and rounded volumes, target notionals, mismatch fraction, both magics, order
outcomes, repair action, and exit reason. Never log credentials or external
account data.

## Framework Alignment

| card rule | module / implementation target |
|---|---|
| framework, risk, news, Friday, stress, locked-input contract | `Strategy_NoTradeFilter` plus `OnInit` framework validation |
| synchronized endpoints, changes, means, centered ranks, Klotz scores, enumeration, side, quotes, ATR, sizing, atomic orders | `Strategy_EntrySignal` and bounded helpers |
| orphan/duplicate/side/magic/stop/notional/staleness repair | `Strategy_ManageOpenPosition` |
| new-month and forty-day lifecycle | `Strategy_ExitSignal` plus package close helper |
| both news axes OFF | `Strategy_NewsFilterHook` and framework initialization |

## Falsification And Requalification

Any change to the symbols, timeframe, endpoint count, change orientation,
block split, centering, residual tie rule, rank order, score literals,
expectation, denominator, enumeration, tolerances, side mapping, attempt
timing, risk, stop, spread cap, or exit requires a new binary and full pipeline
requalification. Ambiguous history, arithmetic, or state fails closed. Q02 may
kill the card but may not tune it; Q09 alone may establish decorrelation.

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
|---|---|---|---|---|
| v1 | 2026-09-01 | initial monthly centered Klotz XAU/XAG scale-state card | G0 | APPROVED; build pending |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-09-01 | APPROVED; R1-R4 PASS | source approval, corrected-root dedup receipt, G0 decision, and this card |
| Q01 Build Validation | - | NOT_BUILT | pending magic allocation and exact implementation |
| Q02 Baseline Screening | - | NOT_ENQUEUED_Q01_PENDING | one paced logical-basket enqueue only after strict Q01 and CPU admission |
