---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-WTI-MLEPAGE-SHIFT-20260901_S01
variant_id: AI-CODEX-WTI-MLEPAGE-SHIFT-20260901_S01
source_id: AI-CODEX-WTI-MLEPAGE-SHIFT-20260901
ea_id: QM5_41270
slug: wti-mlepage-shift-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41270_wti-mlepage-shift-tr_card.md
execution_contract_status: APPROVED
created: 2026-09-01
created_by: Research+Development
last_updated: 2026-09-01
g0_status: APPROVED
g0_decision: decisions/2026-09-01_qm5_41270_wti_monthly_lepage_shift_trend_g0.md
source_approval: decisions/2026-09-01_wti_monthly_lepage_shift_trend_source_approval.md
source_author: "OpenAI Codex"
source_authors: "OpenAI Codex; Yves Lepage; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; Abid Hussain; Michail Tsagris"
source_citation: "OpenAI Codex (2026), WTI monthly Lepage joint location-scale shift continuation; supporting records Lepage (1971), Biometrika 58(1), DOI 10.1093/biomet/58.1.213; Moskowitz, Ooi, and Pedersen (2012), JFE 104(2), DOI 10.1016/j.jfineco.2011.11.003; Hussain and Tsagris (2025), arXiv:2509.19126v3; CRAN LePage 1.0, DOI 10.32614/CRAN.package.LePage."
source_citations:
  - type: ai_originated_governed_source
    citation: "OpenAI Codex (2026). WTI monthly Lepage joint location-scale shift continuation."
    location: "strategy-seeds/sources/AI-CODEX-WTI-MLEPAGE-SHIFT-20260901/source.md"
    quality_tier: governed_source
    role: exact_trading_hypothesis_formula_activity_boundary_execution_risk_and_lifecycle
  - type: peer_reviewed_wti_carrier_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete governed packet strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: own_return_continuation_family_and_explicit_wti_membership_only
  - type: peer_reviewed_statistical_method
    citation: "Lepage, Y. (1971). A combination of Wilcoxon's and Ansari-Bradley's statistics. Biometrika 58(1), 213-217."
    location: "DOI 10.1093/biomet/58.1.213; publisher metadata/abstract and Crossref record with explicit body-access boundary"
    quality_tier: A_metadata_boundary
    role: named_original_joint_location_scale_method_identity_only
  - type: complete_author_method_preprint
    citation: "Hussain, A., and Tsagris, M. (2025). Enhanced Lepage-type test statistics for location-scale shifts with right-skewed data. arXiv:2509.19126v3."
    location: "complete 20-page read; retrieval receipt strategy-seeds/sources/AI-CODEX-WTI-MLEPAGE-SHIFT-20260901/retrieval_route_20260901.json"
    quality_tier: A_author_preprint
    role: classical_component_moments_joint_statistic_asymptotic_reference_and_adverse_limitations
  - type: primary_statistical_software
    citation: "Tsagris, M., and Hussain, A. (2025). LePage: LePage Type Tests, R package version 1.0."
    location: "CRAN package DOI 10.32614/CRAN.package.LePage; complete source archive and hashes in retrieval receipt"
    quality_tier: A_official
    role: exact_pooled_rank_symmetric_score_component_normalization_joint_statistic_and_chi_square_reference_arithmetic
strategy_mechanic: monthly-wti-fifty-completed-d1-log-returns-fixed-twenty-five-old-twenty-five-recent-lepage-wilcoxon-ansari-bradley-joint-location-scale-chi-square-two-median-gated-recent-cumulative-return-continuation
sources:
  - "[[sources/AI-CODEX-WTI-MLEPAGE-SHIFT-20260901]]"
concepts:
  - "[[concepts/wti-time-series-momentum]]"
  - "[[concepts/joint-location-scale-regime]]"
indicators:
  - "[[indicators/completed-d1-log-return]]"
  - "[[indicators/lepage-joint-rank-statistic]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, joint-location-scale-shift, lepage, wilcoxon-rank-sum, ansari-bradley, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
symbol_slots: [0]
magic: 412700000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately 6 completed WTI positions per full post-warm-up year after fifty-one completed D1 closes; one consumed attempt per broker month. The chi-square-two median gate has a one-half asymptotic state prior before overlap, dependence, ties, neutral direction, data, and execution gates."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_AI_SYNTHESIS_AND_PRIMARY_METHOD_EVIDENCE
r1_reasoning: "One durable AI-originated source; complete-read peer-reviewed WTI evidence; named original Lepage peer-reviewed method with body-access boundary; complete author preprint and complete official CRAN implementation evidence; explicit no-performance boundary."
r2_mechanical: PASS
r2_reasoning: "Month clock, completed closes/returns, fixed blocks, strict ties, pooled ordinary and symmetric ranks, component moments, statistic, median threshold, side, attempt, risk, stop, spread, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_reasoning: "Registered native XTIUSD.DWX D1 history and MT5 state supply every runtime input; continuous-CFD roll, basis, financing, gap, and broker-month risks remain explicit."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, sorting, fixed rank arithmetic, comparisons, ATR risk controls, quotes, positions, deals, and persistent state; no trained output, prohibited signal indicator, random runtime sampling, or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: 51 completed D1 closes; 50 adjacent log returns; fixed old/recent blocks of 25; pairwise-distinct pooled returns; ordinary ranks 1..50; symmetric scores min(rank,51-rank); Wilcoxon mean/variance 637.5/2656.25; Ansari-Bradley mean/variance 325/(32500/49); Lepage gate 1.3862943611198906; recent-return direction epsilon 1e-12; 80 D1 history bars; 180-minute entry grace; 4-day completed-close staleness; ATR(20)*3.5 stop; 40-day stale exit; 1500-point spread ceiling."
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
review_focus: "Falsify a direct-WTI monthly joint ordinal location-scale continuation sleeve outside the directional XAU/SP500/NDX/XNG book. Verify close/return orientation, fixed membership, strict tie rejection, pooled ranks, mirrored scores, exact component moments, joint statistic and gate, recent-return side, consumed month, fixed risk, frozen stop, and next-month lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_tradable_month_bar, fifty_one_completed_d1_closes, no_current_bar_price, fifty_adjacent_log_returns, fixed_twenty_five_old_recent_membership, pairwise_distinct_returns, pooled_ordinary_ranks, symmetric_end_rank_scores, exact_component_moments, joint_lepage_statistic, chi_square_two_median_gate, recent_cumulative_return_direction, no_statistic_magnitude_sizing, monthly_attempt_state, risk_mode_dual, hard_stop_present, friday_close_disabled, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-09-01 and decisions/2026-09-01_qm5_41270_wti_monthly_lepage_shift_trend_g0.md: R1 passes through one durable AI source, complete peer-reviewed WTI evidence, the original Lepage metadata record with access boundary, a complete author preprint, complete official CRAN source arithmetic, hashes, adverse findings, and explicit synthesis boundaries; R2 locks data, ranks, components, joint gate, direction, attempt, risk, stop, spread, and lifecycle; R3 uses registered native WTI D1 with continuous-CFD risk; R4 uses deterministic native arithmetic only. Corrected-root dedup raised QM5_41268 as one fuzzy neighbor; mandatory manual formula review proved the ordinal joint rank statistic distinct from its ECF/covariance inverse and from existing separate monthly location-only and scale-only builds."
---

# QM5_41270 WTI Lepage Joint Location-Scale Shift Trend

## Hypothesis

WTI supply, storage, transport, refining, producer hedging, geopolitical, and
end-demand adjustments can change both the center and tail occupancy of its
daily return distribution. When the latest twenty-five completed WTI daily
returns show a sufficiently large joint ordinal location-scale displacement
from the preceding twenty-five, continue the recent twenty-five-session
return direction for one broker month.

The direct `XTIUSD.DWX` carrier is absent from the certified
XAU/SP500/NDX/XNG book. It is intended to introduce crude-oil physical-market
exposure rather than another index, directional metal, or short-horizon XNG
oscillator. This does not prove decorrelation. Q02 owns activity/economics;
later gates own robustness; unchanged Q09 alone owns realized overlap.

## Source Traceability And Claim Boundary

The single governed source is
`strategy-seeds/sources/AI-CODEX-WTI-MLEPAGE-SHIFT-20260901/source.md`,
approved and committed as `b6d352b26b` before card extraction. Moskowitz,
Ooi, and Pedersen support only the broad own-return continuation carrier and
explicit WTI membership. Lepage metadata, the complete Hussain-Tsagris
preprint, and complete CRAN source support only the classical joint rank
arithmetic and asymptotic reference.

The original 1971 article body was not accessible. The card claims only its
publisher metadata/abstract and Crossref record; exact arithmetic comes from
the completely read author preprint and official package source. Fixed daily
blocks, strict ties, median activity gate, cumulative-return side, CFD
translation, risk, activity, and lifecycle are pre-result QM choices. No
statistical or trading result is imported as an efficacy claim.

## Non-Duplicate Boundary

The corrected-root receipt
`artifacts/qm5_wti_mlepage_shift_tr_preallocation_dedup_20260901.json`,
SHA-256
`FFF74031E1A7636A78816E6EB0AB67B6CA2731467577CA4D656D96A4B52C2A97`,
checked 4,769 registry rows, 1,406 cards, and 45 Wiki nodes. It found one
fuzzy match, `QM5_41268_wti-mepps-shift-tr`, which triggered the required
manual review.

`QM5_41268` compares four empirical-characteristic-function feature means
through a pooled covariance and full-rank matrix inverse. This card discards
all return spacing after pooled ranking and combines a monotone location rank
score with a mirrored tail/center scale score. `QM5_41176` and `QM5_41261`
are separate six-by-six monthly location-only and scale-only rules. This card
can qualify only through two individually sub-threshold components: the fixed
recent-rank path
`{1,2,4,5,7,8,9,10,12,13,16,23,25,28,29,30,34,37,38,39,40,41,43,45,48}`
has component squares `0.9600941176470589` and `1.356923076923077`, but joint
`L=2.317017194570136`.

Verdict:
`DISTINCT_WTI_MONTHLY_FIXED_25_BY_25_DAILY_RETURN_LEPAGE_JOINT_WILCOXON_ANSARI_BRADLEY_LOCATION_SCALE_CHI_SQUARE_TWO_MEDIAN_GATE_RECENT_RETURN_CONTINUATION`.

## Rules

### Data and signal formula

On the first executable tick of each genuine normalized broker month:

```text
C[0..50] = fifty-one chronological completed WTI D1 closes
r[i] = log(C[i+1]/C[i]), i=0..49
old = r[0..24]; recent = r[25..49]
require all fifty returns finite and pairwise distinct

rank pooled returns ascending j=1..50
ordinary_score(j)=j
symmetric_score(j)=min(j,51-j)
W=sum ordinary_score for recent observations
A=sum symmetric_score for recent observations

zW2=(W-637.5)^2/2656.25
zA2=(A-325)^2/(32500/49)
L=zW2+zA2

qualify iff L>=1.3862943611198906
BUY iff sum(recent)>1e-12
SELL iff sum(recent)<-1e-12
FLAT otherwise
```

The current D1 bar is excluded. Closes must be positive, finite, strictly
chronological, and the newest completed bar no more than four calendar days
stale. Sorting retains the old/recent label. Any exact return tie, malformed
rank path, nonfinite component, or negative component consumes flat.

The threshold is exactly `2*ln(2)`, the chi-square-two median, and only a
fixed activity gate. There is no p-value, permutation at runtime,
significance claim, adaptive threshold, optimizer, or magnitude-based risk
scaling.

## 4. Entry Rules

1. Require exact EA ID 41270, `XTIUSD.DWX`, D1, slot 0, registered magic
   `412700000`, fixed-risk mode, and every locked input.
2. Process malformed-position, next-month, and stale exits before entry-only
   gates.
3. Require a genuine new broker month within the first 180 minutes of its
   first D1 bar.
4. Persist the current month key before history, signal, news, spread, quote,
   ATR, sizing, margin, or order checks. A rejected gate still consumes the
   month.
5. Reject owned exposure or a same-magic entry deal already recorded in the
   current month.
6. Reconstruct closes/returns, reject ties, pool and rank, and compute the
   exact locked Lepage component squares and joint statistic.
7. Require `L>=1.3862943611198906` and a non-neutral recent return sum.
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
  history, any exact return tie, invalid pooled rank/score path, nonfinite
  component/statistic, sub-threshold joint statistic, neutral direction,
  excessive spread, invalid quote, unavailable ATR, invalid stop/volume, or
  insufficient margin.
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
| `strategy_w_mean` | 637.5 | locked Wilcoxon expectation |
| `strategy_w_variance` | 2656.25 | locked Wilcoxon variance |
| `strategy_a_mean` | 325 | locked Ansari-Bradley expectation |
| `strategy_a_variance` | 663.26530612244898 | locked `32500/49` variance |
| `strategy_statistic_gate` | 1.3862943611198906 | locked chi-square-two median |
| `strategy_direction_epsilon` | `1e-12` | locked side tolerance |
| `strategy_history_bars_d1` | 80 | locked bounded buffer |
| `strategy_entry_grace_minutes` | 180 | locked first-bar window |
| `strategy_max_completed_bar_age_days` | 4 | locked staleness guard |
| `strategy_atr_period_d1` | 20 | locked completed-bar ATR |
| `strategy_atr_sl_mult` | 3.5 | locked hard stop |
| `strategy_max_hold_days` | 40 | locked stale repair |
| `strategy_max_spread_points` | 1500 | locked cost guard |
| `strategy_deviation_points` | 20 | locked order deviation |

Changing the sample, return definition, split, tie rule, ordinary/symmetric
scores, component moments, joint gate, side, risk, stop, spread, or hold after
Q02 is forbidden result-driven repair.

## Expected Behavior And Frequency

The source asymptotic reference is chi-square with two degrees of freedom;
its median gate implies a one-half state prior, or roughly six monthly states
per year before overlap, dependence, ties, neutral direction, missing data,
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
- The two adjacent return blocks overlap in calendar regime and are not
  independent samples. `L` is therefore a deterministic structural score,
  not a valid significance claim.

## Source-Defined Rules

- WTI belongs to the peer-reviewed own-return continuation universe.
- The classical Lepage construction combines squared standardized Wilcoxon
  location and Ansari-Bradley scale rank components.
- The even-N component expectations and variances, symmetric score path, and
  chi-square-two asymptotic reference follow the fully read method records.
- No source defines this WTI sample, threshold, direction, activity, stop,
  risk, CFD mapping, or portfolio claim.

## QM Interpretations

- The 25/25 daily-return blocks, strict tie rejection, chi-square median as an
  activity gate, recent cumulative-return continuation, monthly clock,
  fixed-dollar risk, ATR stop, spread cap, and stale repair are transparent
  pre-result choices.
- New robustified Lepage variants were not selected because this card values
  a small, auditable classical ordinal score and makes no inference claim.
- Q09 decorrelation cannot be inferred from carrier identity or source
  narrative; it must be measured unchanged downstream.

## Framework Execution Overrides

- Friday close is disabled to preserve the approved full-month hold.
- News temporal mode is `QM_NEWS_TEMPORAL_OFF`.
- News compliance profile is `QM_NEWS_COMPLIANCE_NONE`.
- Legacy news mode passed to framework initialization is OFF.
- Backtest risk is fixed 1,000 account-currency units; percentage risk is
  zero; stress rejection probability is zero.

## Exit Precedence

1. Framework kill switch and hard-stop enforcement.
2. Lifecycle-integrity repair.
3. New-broker-month close.
4. Forty-day stale close.
5. Entry-only history, signal, news, spread, quote, ATR, sizing, and margin
   gates.
6. New single-position entry.

## Runtime Data Dependencies

Exact `XTIUSD.DWX` native D1 timestamps and closes, broker time, symbol
metadata, quotes, completed-bar ATR, framework position/deal state, and a
terminal-persistent attempt marker. No external runtime dataset exists.

## Failure Conditions

Retire on zero positions, fewer than five completed positions in any full
post-warm-up year, failed CRAN/formula fixture parity, nondeterministic rank
output, malformed position behavior, nonpositive governed economics, or any
downstream gate failure. No threshold, side, sample, or hold rescue is
authorized.

## Logging

Log normalized month key, decision bar, label offset, close/return counts,
ordinary rank sum, symmetric score sum, both component squares, joint
statistic, recent return, chosen side, attempt state, ATR/stop distance,
volume, magic, order outcome, repair action, and exit reason. Never log
credentials or external account data.

## Framework Alignment

| card rule | module / implementation target |
|---|---|
| framework, risk, news, Friday, stress, and locked-input contract | `Strategy_NoTradeFilter` plus `OnInit` framework validation |
| completed closes/returns, strict pooled ranks, joint statistic, side, quote, ATR, and sizing | `Strategy_EntrySignal` and bounded helpers |
| malformed-position, new-month, and forty-day repair | `Strategy_ManageOpenPosition` |
| lifecycle reason mapping | `Strategy_ExitSignal` plus framework close helper |
| both news axes OFF | `Strategy_NewsFilterHook` and framework initialization |

## Status

`APPROVED_FOR_BRANCH_BUILD_AND_NON_LIVE_Q01_Q02_ONLY`. This card does not
authorize optimization, portfolio admission, threshold changes,
live/demo/shadow/stress presets, deploy/live manifests, `T_Live`, or
AutoTrading.
