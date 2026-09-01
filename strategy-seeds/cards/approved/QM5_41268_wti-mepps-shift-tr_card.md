---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-WTI-MEPPS-SHIFT-20260901_S01
variant_id: AI-CODEX-WTI-MEPPS-SHIFT-20260901_S01
source_id: AI-CODEX-WTI-MEPPS-SHIFT-20260901
ea_id: QM5_41268
slug: wti-mepps-shift-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41268_wti-mepps-shift-tr_card.md
execution_contract_status: APPROVED
created: 2026-09-01
created_by: Research+Development
last_updated: 2026-09-01
g0_status: APPROVED
g0_decision: decisions/2026-09-01_qm5_41268_wti_monthly_epps_singleton_shift_trend_g0.md
source_approval: decisions/2026-09-01_wti_monthly_epps_singleton_shift_trend_source_approval.md
source_author: "OpenAI Codex"
source_authors: "OpenAI Codex; T. W. Epps; Kenneth J. Singleton; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; SciPy community"
source_citation: "OpenAI Codex (2026), WTI monthly Epps-Singleton distribution-shift continuation; supporting records Epps and Singleton (1986), Journal of Statistical Computation and Simulation 26(3-4), DOI 10.1080/00949658608810963; Moskowitz, Ooi, and Pedersen (2012), JFE 104(2), DOI 10.1016/j.jfineco.2011.11.003; SciPy 1.18.0 signed-tag-pinned source."
source_citations:
  - type: ai_originated_governed_source
    citation: "OpenAI Codex (2026). WTI monthly Epps-Singleton distribution-shift continuation."
    location: "strategy-seeds/sources/AI-CODEX-WTI-MEPPS-SHIFT-20260901/source.md"
    quality_tier: governed_source
    role: exact_trading_hypothesis_formula_activity_boundary_execution_risk_and_lifecycle
  - type: peer_reviewed_wti_carrier_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete governed packet strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: own_return_continuation_family_and_explicit_wti_membership_only
  - type: peer_reviewed_statistical_method
    citation: "Epps, T. W., and Singleton, K. J. (1986). An Omnibus Test for the Two-Sample Problem Using the Empirical Characteristic Function. Journal of Statistical Computation and Simulation 26(3-4), 177-203."
    location: "DOI 10.1080/00949658608810963; publisher metadata/abstract and Stanford author bibliography with explicit full-body access boundary"
    quality_tier: A_metadata_boundary
    role: named_empirical_characteristic_function_two_sample_method_identity_only
  - type: primary_statistical_software
    citation: "SciPy community (2026). scipy.stats.epps_singleton_2samp, SciPy 1.18.0 documentation and signed-tag-pinned source."
    location: "commit 54ef5423f2e4376230ec3bfda6912a07a50958e3; strategy-seeds/sources/AI-CODEX-WTI-MEPPS-SHIFT-20260901/retrieval_route_20260901.json"
    quality_tier: A_official
    role: exact_sample_boundary_semi_iqr_features_covariance_quadratic_form_rank_and_chi_square_reference_arithmetic
strategy_mechanic: monthly-wti-fifty-completed-d1-log-returns-fixed-twenty-five-old-twenty-five-recent-epps-singleton-empirical-characteristic-function-distribution-shift-chi-square-median-gated-recent-cumulative-return-continuation
sources:
  - "[[sources/AI-CODEX-WTI-MEPPS-SHIFT-20260901]]"
concepts:
  - "[[concepts/wti-time-series-momentum]]"
  - "[[concepts/distribution-shift-regime]]"
indicators:
  - "[[indicators/completed-d1-log-return]]"
  - "[[indicators/epps-singleton-ecf-statistic]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, distribution-shift, epps-singleton, empirical-characteristic-function, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
symbol_slots: [0]
magic: 412680000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately 6 completed WTI positions per full post-warm-up year after fifty-one completed D1 closes; one consumed attempt per broker month. The chi-square-four median gate has a one-half asymptotic state prior before dependence, neutral recent return, data, rank, and execution gates."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_AI_SYNTHESIS_AND_PRIMARY_METHOD_EVIDENCE
r1_reasoning: "One durable AI-originated source; complete-read peer-reviewed WTI carrier evidence; named peer-reviewed Epps-Singleton method record with explicit body-access boundary; complete signed-tag-pinned official SciPy documentation/source; explicit no-performance boundary."
r2_mechanical: PASS
r2_reasoning: "Month clock, completed closes and returns, fixed blocks, percentile convention, Fourier points/features, biased covariance, full-rank inverse guards, statistic, median threshold, side, attempt, risk, stop, spread, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_reasoning: "Registered native XTIUSD.DWX D1 history and MT5 state supply every runtime input; continuous-CFD roll, basis, financing, gap, and broker-month risks remain explicit."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, sorting, trigonometric functions, fixed matrix arithmetic, comparisons, ATR risk controls, quotes, positions, deals, and persistent state; no trained output, prohibited signal indicator, random runtime sampling, or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: 51 completed D1 closes; 50 adjacent log returns; fixed old/recent blocks of 25; default Epps-Singleton points 0.4 and 0.8; pooled default-linear semi-IQR; feature order cos(t1),cos(t2),sin(t1),sin(t2); biased within-block covariance; equal-block pooled covariance multipliers 2 and 2; full-rank scaled-pivot 4x4 inverse; pivot epsilon 1e-12; inverse residual tolerance 1e-8; W negative tolerance 1e-10; W gate 3.356693980033321; recent-return direction epsilon 1e-12; 80 D1 history bars; 180-minute entry grace; 4-day completed-close staleness; ATR(20)*3.5 stop; 40-day stale exit; 1500-point spread ceiling."
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
review_focus: "Falsify a direct-WTI monthly empirical-characteristic-function distribution-shift continuation sleeve outside the directional XAU/SP500/NDX/XNG book. Verify close/return orientation, fixed membership, percentiles, Fourier feature order, covariance scaling, inverse guards, W threshold, recent-return side, consumed month, fixed risk, frozen stop, and next-month lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_tradable_month_bar, fifty_one_completed_d1_closes, no_current_bar_price, fifty_adjacent_log_returns, fixed_twenty_five_old_recent_membership, pooled_linear_semi_iqr, source_default_fourier_points, exact_feature_order, biased_within_block_covariance, exact_pooled_covariance, full_rank_inverse, fixed_pivot_and_residual_guards, exact_es_quadratic_form, chi_square_four_median_gate, recent_cumulative_return_direction, no_statistic_magnitude_sizing, monthly_attempt_state, risk_mode_dual, hard_stop_present, friday_close_disabled, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-09-01 and decisions/2026-09-01_qm5_41268_wti_monthly_epps_singleton_shift_trend_g0.md: R1 passes through one durable AI source, complete peer-reviewed WTI evidence, a named peer-reviewed method record with body-access boundary, complete pinned official method/source arithmetic, hashes, adverse findings, and explicit synthesis boundaries; R2 locks data, statistic, gate, direction, attempt, risk, stop, spread, and lifecycle; R3 uses registered native WTI D1 with continuous-CFD risk; R4 uses deterministic native arithmetic only. Corrected-root dedup returned CLEAN across 4,767 registry rows, 1,404 cards, and 45 Wiki nodes; manual review separates the ECF/covariance quadratic form from existing Cramer-von Mises, energy, Wasserstein, mean-location, rank-scale, and change-point builds."
---

# QM5_41268 WTI Epps-Singleton Distribution-Shift Trend

## Hypothesis

WTI supply, storage, transport, refining, hedging, geopolitical, and demand
adjustments can shift the shape of its daily return distribution. When the
latest twenty-five completed WTI daily returns differ from the preceding
twenty-five in source-defined empirical-characteristic-function space,
continue the recent twenty-five-session return direction for one broker
month.

The direct `XTIUSD.DWX` carrier is absent from the certified
XAU/SP500/NDX/XNG book. It is intended to introduce crude-oil supply/demand
exposure rather than another index, metal, or short-horizon XNG oscillator.
This does not prove decorrelation. Q02 owns activity/economics; later gates
own robustness; unchanged Q09 alone owns realized overlap.

## Source Traceability And Claim Boundary

The single governed source is
`strategy-seeds/sources/AI-CODEX-WTI-MEPPS-SHIFT-20260901/source.md`, approved
and committed as `9245d4e12e` before card extraction. Moskowitz, Ooi, and
Pedersen support only the broad own-return continuation carrier and explicit
WTI membership. Epps-Singleton plus pinned SciPy evidence support only the
two-sample empirical-characteristic-function arithmetic.

The peer-reviewed method paper body was not accessible. This card claims only
publisher metadata/abstract and the author bibliography for that paper and
uses complete official SciPy documentation/source for exact arithmetic. The
fixed daily blocks, full-rank-only inverse, chi-square median gate,
cumulative-return side, CFD translation, risk, activity, and lifecycle are
pre-result QM choices. No statistical or trading result is imported as an
efficacy claim.

## Non-Duplicate Boundary

The corrected-root receipt
`artifacts/qm5_wti_mepps_shift_tr_preallocation_dedup_20260901.json`, SHA-256
`239D9D85B296F529E01D092031C1457E92E263259B2CEC5879577B5FC460CF69`,
found no exact or fuzzy identity.

`QM5_41255` compares empirical CDFs; `QM5_41258` uses pairwise energy
distance; `QM5_41259` uses sorted-quantile Wasserstein distance;
`QM5_41262` uses raw close mean-location; and `QM5_41267` uses squared ranks
for a relative-scale state. This card instead compares four Fourier-feature
means through a pooled feature covariance and full-rank quadratic form on
fixed daily-return blocks.

Verdict:
`DISTINCT_WTI_MONTHLY_FIXED_25_BY_25_DAILY_RETURN_EPPS_SINGLETON_ECF_DISTRIBUTION_SHIFT_MEDIAN_GATE_RECENT_RETURN_CONTINUATION`.

## Rules

### Data and signal formula

On the first executable tick of each genuine normalized broker month:

```text
C[0..50] = fifty-one chronological completed WTI D1 closes
r[i] = log(C[i+1]/C[i]), i=0..49
old = r[0..24]; recent = r[25..49]

q25 = sorted_pool[12] + 0.25*(sorted_pool[13]-sorted_pool[12])
q75 = sorted_pool[36] + 0.75*(sorted_pool[37]-sorted_pool[36])
sigma = (q75-q25)/2
t1=0.4/sigma; t2=0.8/sigma
g(r)=[cos(t1*r),cos(t2*r),sin(t1*r),sin(t2*r)]

cov_block=(1/25)*sum((g-mean_g)*(g-mean_g)')
est_cov=2*cov_old+2*cov_recent
delta=mean_old-mean_recent
W=50*delta'*inverse(est_cov)*delta

qualify iff full-rank guarded inverse is valid and W>=3.356693980033321
BUY iff sum(recent)>1e-12
SELL iff sum(recent)<-1e-12
FLAT otherwise
```

The current D1 bar is excluded. Closes must be positive, finite, strictly
chronological, and the newest completed bar no more than four calendar days
stale. The inverse requires scaled pivots above `1e-12`, an identity residual
at most `1e-8`, and finite arithmetic. A statistic in `[-1e-10,0)` clamps to
zero; a lower value consumes flat.

The threshold is the chi-square-four median and only a fixed activity gate.
There is no CDF lookup, conventional significance claim, optimizer, adaptive
threshold, or magnitude-based risk scaling.

## 4. Entry Rules

1. Require exact EA ID 41268, `XTIUSD.DWX`, D1, slot 0, registered magic
   `412680000`, fixed-risk mode, and every locked input.
2. Process malformed-position, next-month, and stale exits before entry-only
   gates.
3. Require a genuine new broker month within the first 180 minutes of its
   first D1 bar.
4. Persist the current month key before history, signal, news, spread, quote,
   ATR, sizing, margin, or order checks. A rejected gate still consumes the
   month.
5. Reject owned exposure or a same-magic entry deal already recorded in the
   current month.
6. Reconstruct closes/returns and compute the exact locked Epps-Singleton
   full-rank statistic.
7. Require `W>=3.356693980033321` and a non-neutral recent return sum.
8. Require spread at most 1,500 points, an executable quote, completed-bar
   `ATR(20,D1)`, valid metadata, fixed-risk sizing, and sufficient margin.
9. Attach one frozen `3.5*ATR(20,D1)` hard stop, no target, and submit one
   market order in the signal direction.
10. Keep only one correctly directed, registered, stop-protected position;
    otherwise close owned exposure immediately.

## 5. Exit Rules

1. Framework kill switch and broker hard stop remain authoritative.
2. Close on the first processed tick in a later normalized broker month.
3. Close after forty elapsed calendar days as stale repair.
4. Close immediately if owned exposure is duplicated, wrong-symbol, wrong-
   magic, wrong-direction, or stopless.
5. No intramonth flip, target, trail, break-even, partial close, Friday close,
   news exit, scale-in, grid, martingale, or pyramid is authorized.

## 6. Filters (No-Trade Module)

- Fail closed outside exact symbol, D1 period, EA ID, slot, fixed-risk,
  news/Friday, stress, or locked-input contract.
- Reject consumed attempt, owned exposure, same-month deal, malformed close
  history, invalid semi-IQR/features/covariance/inverse/statistic,
  non-qualifying statistic, neutral direction, excessive spread, invalid
  quote, unavailable ATR, invalid stop/volume, or insufficient margin.
- Terminal-persistent state plus deal history prevents restart retries.
  Tester initialization clears only future or prior-run markers so historical
  runs remain deterministic.
- Runtime may not read futures chains, inventory, volume, open interest,
  files, APIs, forecasts, trained outputs, optimizer results, or portfolio
  state.

## 7. Trade Management Rules

- Maintain at most one valid owned WTI position and one consumed attempt per
  broker month.
- Preserve the original hard stop; close before monthly renewal or after
  forty elapsed calendar days.
- Run malformed-position repair before entry-only gates on every tick.
- Restart recovery combines the persistent month marker with owned positions
  and same-month deal history; no restart creates a second attempt.
- No randomness, adaptation, partial close, scale-in, grid, martingale, or
  pyramiding is allowed.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| input | value | contract |
|---|---:|---|
| `strategy_close_count` | 51 | locked completed closes |
| `strategy_return_count` | 50 | locked adjacent log returns |
| `strategy_block_size` | 25 | locked old/recent membership |
| `strategy_t1` | 0.4 | locked source-default point |
| `strategy_t2` | 0.8 | locked source-default point |
| `strategy_statistic_gate` | 3.356693980033321 | locked chi-square-four median |
| `strategy_inverse_pivot_epsilon` | `1e-12` | locked full-rank guard |
| `strategy_inverse_residual_tolerance` | `1e-8` | locked inverse parity guard |
| `strategy_negative_stat_tolerance` | `1e-10` | locked roundoff guard |
| `strategy_direction_epsilon` | `1e-12` | locked side tolerance |
| `strategy_history_bars_d1` | 80 | locked bounded buffer |
| `strategy_entry_grace_minutes` | 180 | locked first-bar window |
| `strategy_max_completed_bar_age_days` | 4 | locked staleness guard |
| `strategy_atr_period_d1` | 20 | locked completed-bar ATR |
| `strategy_atr_sl_mult` | 3.5 | locked hard stop |
| `strategy_max_hold_days` | 40 | locked stale repair |
| `strategy_max_spread_points` | 1500 | locked cost guard |
| `strategy_deviation_points` | 20 | locked order deviation |

Changing the sample, return definition, split, percentile convention,
features, covariance, inverse, gate, side, risk, stop, spread, or hold after
Q02 is forbidden result-driven repair.

## Expected Behavior And Frequency

The full-rank asymptotic reference is chi-square with four degrees of freedom;
its median gate implies a one-half state prior, or roughly six monthly states
per year before dependence, neutral direction, missing data, covariance rank,
spread, ATR, sizing, and execution gates. This is not a WTI or performance
result. Q02 must retire the candidate if any full post-warm-up year has fewer
than five completed positions.

## Risk

- Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- One frozen `3.5*ATR(20,D1)` broker hard stop and no target.
- Signal/statistic magnitude never scales exposure.
- Continuous WTI gaps can exceed the broker stop; Q02 economics and later
  stress gates own this risk.
- Both news axes, legacy news mode, and Friday close are OFF to preserve the
  approved full-month lifecycle.

## Source-Defined Rules

- WTI belongs to the peer-reviewed own-return continuation universe.
- Epps-Singleton uses empirical-characteristic-function differences evaluated
  at fixed positive points, covariance normalization, an inverse quadratic
  form, and a chi-square rank reference.
- Official SciPy locks the default points, pooled semi-IQR scaling, feature
  order, biased covariance, pooled covariance, statistic, and sample boundary.
- No source defines the fixed daily blocks, median gate, direction, CFD
  equivalence, fixed risk, density, or lifecycle.

## QM Interpretations

- Fifty-one completed D1 closes, fixed twenty-five/twenty-five returns,
  full-rank-only inversion, fixed numerical guards, the chi-square-four median
  gate, recent-return side, monthly hold, ATR stop, spread cap, and consumed
  attempt are transparent pre-result choices.
- The median gate is not a conventional significance claim and the EA never
  calculates a p-value.
- Direct WTI adds a different carrier by design; it is not proof of portfolio
  neutrality or decorrelation.

## Framework Execution Overrides

- Friday close is disabled to preserve the approved full-month hold.
- News temporal mode is OFF; news compliance profile is NONE; legacy news
  mode is OFF.
- Backtest risk is fixed 1,000 account-currency units; percentage risk is
  zero; stress rejection probability is zero in the canonical set.

## Exit Precedence

1. Framework kill switch and hard-stop enforcement.
2. Position-integrity repair.
3. New-broker-month close.
4. Forty-day stale close.
5. Entry-only history, signal, news, spread, quote, ATR, sizing, and margin
   gates.
6. One new position entry.

## Runtime Data Dependencies

Exact `XTIUSD.DWX` native D1 timestamps and closes, broker time, symbol
metadata, quotes, completed-bar ATR, framework position/deal state, and one
terminal-persistent attempt marker. No external runtime dataset exists.

## Framework Alignment

| card rule | module / implementation target |
|---|---|
| framework, risk, news, Friday, stress, and locked-input contract | `Strategy_NoTradeFilter` plus `OnInit` validation |
| closes, returns, percentiles, features, covariance, inverse, statistic, side, quote, ATR, and sizing | `Strategy_EntrySignal` and bounded helpers |
| malformed-position, next-month, and stale repair | `Strategy_ManageOpenPosition` |
| monthly/stale lifecycle reason mapping | `Strategy_ExitSignal` plus framework close helper |
| both news axes OFF | `Strategy_NewsFilterHook` and framework initialization |

## Failure Conditions

Retire on zero positions, fewer than five in any full post-warm-up year,
failed SciPy/fixture parity, malformed restart behavior, nonpositive governed
economics, or any downstream gate failure. No sample, statistic, gate, side,
threshold, or hold rescue is authorized.

## Falsification And Requalification

Any change to symbol, timeframe, close/return count, block membership,
percentile convention, Fourier points/features, covariance, inverse guard,
statistic gate, direction, attempt timing, risk, stop, spread, or exit requires
a new binary and full pipeline requalification. Ambiguous history, arithmetic,
or state fails closed. Q02 may kill the card but may not tune it; Q09 alone may
establish decorrelation.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-09-01 | initial WTI Epps-Singleton distribution-shift card | G0 | APPROVED; build pending |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-09-01 | APPROVED; R1-R4 PASS | source approval, corrected-root dedup receipt, G0 decision, and this card |
| Q01 Build Validation | - | NOT_BUILT | pending magic allocation and exact implementation |
| Q02 Baseline Screening | - | NOT_ENQUEUED_Q01_PENDING | one paced enqueue only after strict Q01 and CPU admission |

## Safety Boundary

This card authorizes only one branch build, deterministic reference tests,
strict Q01, one D1 `RISK_FIXED` backtest setfile, and one paced non-live Q02
handoff if the governed CPU ceiling permits. It does not authorize a manual
tester run, optimization, live/demo/shadow/stress setfile, AutoTrading,
`T_Live`, deploy/live manifest, portfolio-gate mutation, portfolio admission,
or correlation waiver.

