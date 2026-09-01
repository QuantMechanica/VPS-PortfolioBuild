---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-WTI-MMOOD-SCALE-20260901_S01
variant_id: AI-CODEX-WTI-MMOOD-SCALE-20260901_S01
source_id: AI-CODEX-WTI-MMOOD-SCALE-20260901
ea_id: QM5_41267
slug: wti-mmood-scale-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41267_wti-mmood-scale-tr_card.md
execution_contract_status: APPROVED
created: 2026-09-01
created_by: Research+Development
last_updated: 2026-09-01
g0_status: APPROVED
g0_decision: decisions/2026-09-01_qm5_41267_wti_monthly_mood_scale_trend_g0.md
source_approval: decisions/2026-09-01_wti_monthly_mood_scale_trend_source_approval.md
source_author: "OpenAI Codex"
source_authors: "OpenAI Codex; A. M. Mood; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; SciPy community"
source_citation: "OpenAI Codex (2026), WTI monthly Mood squared-rank scale non-contraction continuation; supporting records Mood (1954), Annals of Mathematical Statistics 25(3), DOI 10.1214/aoms/1177728719; Moskowitz, Ooi, and Pedersen (2012), JFE 104(2), DOI 10.1016/j.jfineco.2011.11.003; SciPy 1.18.0 signed-tag-pinned source."
source_citations:
  - type: ai_originated_governed_source
    citation: "OpenAI Codex (2026). WTI monthly Mood squared-rank scale non-contraction continuation."
    location: "strategy-seeds/sources/AI-CODEX-WTI-MMOOD-SCALE-20260901/source.md"
    quality_tier: governed_source
    role: exact_trading_hypothesis_formula_activity_boundary_execution_risk_and_lifecycle
  - type: peer_reviewed_wti_carrier_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete governed packet strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: monthly_own_return_continuation_family_and_explicit_wti_membership_only
  - type: peer_reviewed_statistical_method
    citation: "Mood, A. M. (1954). On the Asymptotic Efficiency of Certain Nonparametric Two-Sample Tests. The Annals of Mathematical Statistics 25(3), 514-522."
    location: "DOI 10.1214/aoms/1177728719; publisher metadata/indexed abstract only with explicit full-body access boundary"
    quality_tier: A_metadata_boundary
    role: named_squared_rank_two_sample_dispersion_method_identity_only
  - type: primary_statistical_software
    citation: "SciPy community (2026). scipy.stats.mood, SciPy 1.18.0 documentation and signed-tag-pinned source."
    location: "commit 54ef5423f2e4376230ec3bfda6912a07a50958e3; strategy-seeds/sources/AI-CODEX-WTI-MMOOD-SCALE-20260901/retrieval_route_20260901.json"
    quality_tier: A_official
    role: exact_pooled_rank_squared_score_expectation_variance_and_standardized_statistic_arithmetic
strategy_mechanic: monthly-wti-twelve-completed-log-returns-fixed-six-old-six-recent-pooled-average-ranks-mood-squared-rank-recent-scale-noncontraction-recent-cumulative-return-continuation
sources:
  - "[[sources/AI-CODEX-WTI-MMOOD-SCALE-20260901]]"
concepts:
  - "[[concepts/wti-time-series-momentum]]"
  - "[[concepts/nonparametric-scale-regime]]"
indicators:
  - "[[indicators/completed-month-log-return]]"
  - "[[indicators/mood-squared-rank-scale-state]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, scale-noncontraction, mood-squared-rank, pooled-rank, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
symbol_slots: [0]
magic: 412670000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately 6 completed WTI positions per full post-warm-up year after thirteen completed month ends; one consumed attempt per broker month. The inclusive Mood-score state qualifies 498 of 924 unique-rank label assignments before neutral recent return, data, and execution gates."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_AI_SYNTHESIS_AND_PRIMARY_METHOD_EVIDENCE
r1_reasoning: "One durable AI-originated source; complete-read peer-reviewed WTI carrier evidence; named peer-reviewed Mood method record with explicit body-access boundary; complete signed-tag-pinned official SciPy documentation/source; explicit no-performance boundary."
r2_mechanical: PASS
r2_reasoning: "Month clock, endpoints, returns, fixed blocks, anchored tie rejection, pooled ranks, exact score, expectation, variance, inclusive gate, side, attempt, risk, stop, spread, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_reasoning: "Registered native XTIUSD.DWX D1 history and MT5 state supply every runtime input; continuous-CFD roll, basis, financing, gap, and broker-month risks remain explicit."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, sorting, integer ranks, finite fixed arithmetic, comparisons, ATR risk controls, quotes, positions, deals, and persistent state; no trained output, prohibited signal indicator, random runtime sampling, or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: 13 completed month-end closes; 12 adjacent log returns; fixed old/recent blocks of 6; anchored sorted-run relative tie epsilon 1e-12 with any tie consuming flat; integer pooled ranks 1..12 with rank-sum 78; Mood old-block squared-rank score around center 6.5; fixed expectation 71.5 and variance 364; finite standardized statistic; inclusive score<=71.5 recent scale-non-contraction gate; recent six-return cumulative direction epsilon 1e-12; 900 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 stop; 40-day stale exit; 1500-point spread ceiling."
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
review_focus: "Falsify a direct-WTI monthly pooled-raw-return squared-rank scale-regime continuation sleeve outside the directional XAU/SP500/NDX/XNG book. Verify completed endpoints, return orientation, fixed membership, anchored tie rejection, ranks, score, fixed moments, inclusive gate, cumulative-return side, consumed month, fixed risk, frozen stop, and next-month lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_tradable_month_bar, thirteen_consecutive_completed_months, no_current_month_price, twelve_adjacent_log_returns, fixed_six_old_six_recent_membership, anchored_relative_tie_rejection, integer_rank_sum_78, exact_mood_squared_rank_score, fixed_expectation_71_5, fixed_variance_364, finite_standardized_statistic, inclusive_recent_scale_noncontraction, recent_cumulative_return_direction, no_probability_or_pvalue_gate, monthly_attempt_state, risk_mode_dual, hard_stop_present, friday_close_disabled, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-09-01 and decisions/2026-09-01_qm5_41267_wti_monthly_mood_scale_trend_g0.md: R1 passes through one durable AI source, complete peer-reviewed WTI evidence, a named peer-reviewed method record with body-access boundary, complete pinned official method/source arithmetic, hashes, adverse findings, and explicit synthesis boundaries; R2 locks data, ranks, score, gate, direction, attempt, risk, stop, spread, and lifecycle; R3 uses registered native WTI D1 with continuous-CFD risk; R4 uses deterministic native arithmetic only. Corrected-root dedup found no exact identity across 4,766 registry rows, 1,403 cards, and 45 Wiki nodes; fixed fixtures prove decision disagreement with the closest Ansari-Bradley, Fligner-Killeen, and permutation-MAD neighbors."
---

# QM5_41267 WTI Mood Squared-Rank Scale Non-Contraction Trend

## Hypothesis

WTI supply, storage, transport, refining, hedging, geopolitical, and demand
adjustments can create persistent return and volatility regimes. When the
pooled squared ranks of the latest six completed monthly WTI returns indicate
dispersion no lower than the preceding six, continue the recent six-month WTI
return direction for one broker month.

The direct `XTIUSD.DWX` carrier is absent from the certified
XAU/SP500/NDX/XNG book. It is intended to introduce crude-oil supply/demand
exposure rather than another index, metal, or short-horizon XNG oscillator.
This does not prove decorrelation. Q02 owns activity/economics; later gates
own robustness; unchanged Q09 alone owns realized overlap.

## Source Traceability And Claim Boundary

The single governed source is
`strategy-seeds/sources/AI-CODEX-WTI-MMOOD-SCALE-20260901/source.md`, approved
and committed as `6ef372bc80` before card extraction. Moskowitz, Ooi, and
Pedersen support only the broad monthly own-return continuation carrier and
explicit WTI membership. Mood plus pinned SciPy evidence support only the
pooled squared-rank scale arithmetic.

The peer-reviewed method paper body was not accessible. This card claims only
publisher metadata and the indexed abstract for that paper and uses complete
official SciPy documentation/source for exact no-tie arithmetic. Fixed
samples, tie rejection, inclusive score-center comparison, cumulative-return
side, CFD translation, risk, activity, and lifecycle are pre-result QM
choices. No statistical or trading result is imported as an efficacy claim.

## Non-Duplicate Boundary

The corrected-root receipt
`artifacts/qm5_wti_mmood_scale_tr_preallocation_dedup_20260901.json`, SHA-256
`CFE1AC425C20CD89B2196F25432B2E5640D3D5F44618BE182F8F7207BA77CA5F`,
found no exact identity.

`QM5_41261` uses symmetric end-rank weights plus an exact label tail.
`QM5_41266` ranks block-median absolute deviations and applies normal scores.
`QM5_41250` recomputes group MAD under every label assignment. This card uses
one pooled raw-return rank assignment, squared distance from rank center, and
a fixed expectation/variance. The approved source contains two unique-return
fixtures proving both decision-disagreement directions.

Verdict:
`DISTINCT_WTI_MONTHLY_FIXED_SIX_BY_SIX_RAW_RETURN_POOLED_INTEGER_RANK_MOOD_SQUARED_RANK_RECENT_SCALE_NONCONTRACTION_CUMULATIVE_RETURN_CONTINUATION`.

## Rules

### Data and signal formula

On the first executable tick of each genuine normalized broker month:

```text
C[0..12] = thirteen consecutive completed WTI broker-month end closes
r[i] = log(C[i+1]/C[i]), i=0..11
old = r[0..5]; recent = r[6..11]

sort all twelve raw returns ascending
reject any anchored relative-1e-12 tie
assign integer ranks R=1..12 to original observations
require all ranks assigned once and sum(R)=78

M_old = sum((R_old-6.5)^2)
E0 = 71.5
Var0 = 364
z = (M_old-E0)/sqrt(Var0); require finite

qualify iff M_old <= 71.5
BUY iff sum(recent) > 1e-12
SELL iff sum(recent) < -1e-12
FLAT otherwise
```

The current month is excluded. Endpoints must be positive, finite,
chronological, exactly one per consecutive month, and no more than ten
calendar days stale. An anchored tie compares every candidate with the first
value in its sorted run; chained tolerance is forbidden. Any tie consumes the
month flat.

`z` is an arithmetic integrity diagnostic only. There is no distribution
lookup, probability, p-value, critical value, optimizer, or magnitude-based
risk scaling.

## 4. Entry Rules

1. Require exact EA ID 41267, `XTIUSD.DWX`, D1, slot 0, registered magic
   `412670000`, fixed-risk mode, and every locked input.
2. Process malformed-position, next-month, and stale exits before entry-only
   gates.
3. Require a genuine new broker month within the first 180 minutes.
4. Persist the current month key before history, signal, news, spread, quote,
   ATR, sizing, margin, or order checks. A rejected gate still consumes the
   month.
5. Reject owned exposure or a same-magic entry deal already recorded in the
   current month.
6. Reconstruct endpoints and compute the exact locked Mood state.
7. Require `M_old<=71.5` and a non-neutral recent six-return sum.
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
- Reject consumed attempt, owned exposure, same-month deal, malformed month
  history, tied raw returns, invalid rank/score arithmetic, non-qualifying
  score, neutral direction, excessive spread, invalid quote, unavailable ATR,
  invalid stop/volume, or insufficient margin.
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
| `strategy_endpoint_count` | 13 | locked |
| `strategy_return_count` | 12 | locked |
| `strategy_block_size` | 6 | locked |
| `strategy_rank_center` | 6.5 | locked |
| `strategy_score_expectation` | 71.5 | locked |
| `strategy_score_variance` | 364 | locked |
| `strategy_relative_epsilon` | `1e-12` | locked anchored-tie and side tolerance |
| `strategy_history_bars_d1` | 900 | locked |
| `strategy_entry_window_minutes` | 180 | locked |
| `strategy_max_endpoint_gap_days` | 10 | locked |
| `strategy_atr_period_d1` | 20 | locked |
| `strategy_atr_sl_mult` | 3.5 | locked |
| `strategy_max_hold_days` | 40 | locked |
| `strategy_max_spread_points` | 1500 | locked |
| `strategy_deviation_points` | 20 | locked |

Changing the sample, return definition, split, tie rule, rank score, fixed
moments, inclusive gate, side, risk, stop, spread, or hold after Q02 is
forbidden result-driven repair.

## Expected Behavior And Frequency

Across all 924 assignments of six unique ranks to the old group, 426 have
`M_old<71.5`, 72 equal 71.5, and 426 exceed it. The inclusive state therefore
qualifies 498 assignments, implying approximately 6 completed trades/year
before neutral return, missing data, spread, ATR, sizing, and execution gates.
This is a combinatorial prior, not a market or performance result. Q02 must
retire the candidate if any full post-warm-up year has fewer than five
completed positions.

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

- WTI belongs to the peer-reviewed monthly own-return continuation universe.
- Mood's no-tie two-sample scale construction pools observations, assigns
  ranks, squares rank distances from the pooled center, and standardizes the
  first-sample score with fixed null expectation and variance.
- No source defines the fixed sample, tie rejection, inclusive score-center
  gate, six-month return side, CFD equivalence, fixed risk, density, or
  lifecycle.

## QM Interpretations

- Thirteen endpoints, fixed six/six monthly blocks, anchored tie tolerance,
  inclusive `M_old<=71.5` scale-non-contraction state, cumulative-return side,
  monthly hold, ATR stop, spread cap, and consumed attempt are transparent
  pre-result choices.
- The standardized Mood score is an arithmetic integrity diagnostic, not a
  significance or p-value claim; no distribution lookup enters the EA.
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
| endpoints, returns, tie rejection, ranks, score, statistic, side, quote, ATR, and sizing | `Strategy_EntrySignal` and bounded helpers |
| malformed-position, next-month, and stale repair | `Strategy_ManageOpenPosition` |
| monthly/stale lifecycle reason mapping | `Strategy_ExitSignal` plus framework close helper |
| both news axes OFF | `Strategy_NewsFilterHook` and framework initialization |

## Failure Conditions

Retire on zero positions, fewer than five in any full post-warm-up year,
failed score/fixture parity, malformed restart behavior, nonpositive governed
economics, or any downstream gate failure. No sample, score, gate, side,
threshold, or hold rescue is authorized.

## Falsification And Requalification

Any change to symbol, timeframe, endpoint count, return orientation, block
membership, tie rule, rank score, expectation, variance, inclusive gate,
direction, attempt timing, risk, stop, spread, or exit requires a new binary
and full pipeline requalification. Ambiguous history, arithmetic, or state
fails closed. Q02 may kill the card but may not tune it; Q09 alone may
establish decorrelation.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-09-01 | initial WTI Mood squared-rank card | G0 | APPROVED; build pending |

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
