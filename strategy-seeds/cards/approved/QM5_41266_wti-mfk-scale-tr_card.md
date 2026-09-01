---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-WTI-MFK-SCALE-20260901_S01
variant_id: AI-CODEX-WTI-MFK-SCALE-20260901_S01
source_id: AI-CODEX-WTI-MFK-SCALE-20260901
ea_id: QM5_41266
slug: wti-mfk-scale-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41266_wti-mfk-scale-tr_card.md
execution_contract_status: APPROVED
created: 2026-09-01
created_by: Research+Development
last_updated: 2026-09-01
g0_status: APPROVED
g0_decision: decisions/2026-09-01_qm5_41266_wti_monthly_fligner_killeen_scale_trend_g0.md
source_approval: decisions/2026-09-01_wti_monthly_fligner_killeen_scale_trend_source_approval.md
source_author: "OpenAI Codex"
source_authors: "OpenAI Codex; Michael A. Fligner; Timothy J. Killeen; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; SciPy community"
source_citation: "OpenAI Codex (2026), WTI monthly Fligner-Killeen scale-expansion continuation; supporting records Fligner and Killeen (1976), JASA 71(353), DOI 10.1080/01621459.1976.10481517; Moskowitz, Ooi, and Pedersen (2012), JFE 104(2), DOI 10.1016/j.jfineco.2011.11.003; SciPy 1.18.0 signed-tag-pinned source."
source_citations:
  - type: ai_originated_governed_source
    citation: "OpenAI Codex (2026). WTI monthly Fligner-Killeen scale-expansion continuation."
    location: "strategy-seeds/sources/AI-CODEX-WTI-MFK-SCALE-20260901/source.md"
    quality_tier: governed_source
    role: exact_trading_hypothesis_formula_activity_boundary_execution_risk_and_lifecycle
  - type: peer_reviewed_wti_carrier_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete governed packet strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: monthly_own_return_continuation_family_and_explicit_wti_membership_only
  - type: peer_reviewed_statistical_method
    citation: "Fligner, M. A. and Killeen, T. J. (1976). Distribution-Free Two-Sample Tests for Scale. Journal of the American Statistical Association 71(353), 210-213."
    location: "DOI 10.1080/01621459.1976.10481517; publisher metadata/abstract only with explicit full-body access boundary"
    quality_tier: A_metadata_boundary
    role: named_distribution_free_two_sample_scale_method_identity_only
  - type: primary_statistical_software
    citation: "SciPy community (2026). scipy.stats.fligner, SciPy 1.18.0 documentation and signed-tag-pinned source."
    location: "commit 54ef5423f2e4376230ec3bfda6912a07a50958e3; strategy-seeds/sources/AI-CODEX-WTI-MFK-SCALE-20260901/retrieval_route_20260901.json"
    quality_tier: A_official
    role: exact_median_deviation_midrank_normal_score_and_statistic_arithmetic
strategy_mechanic: monthly-wti-twelve-completed-log-returns-fixed-six-old-six-recent-group-median-absolute-deviations-pooled-midrank-normal-scores-fligner-killeen-recent-scale-expansion-recent-cumulative-return-continuation
sources:
  - "[[sources/AI-CODEX-WTI-MFK-SCALE-20260901]]"
concepts:
  - "[[concepts/wti-time-series-momentum]]"
  - "[[concepts/robust-scale-regime]]"
indicators:
  - "[[indicators/completed-month-log-return]]"
  - "[[indicators/fligner-killeen-normal-score-scale-state]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, scale-expansion, fligner-killeen, median-centered-absolute-deviation, normal-score-rank, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
symbol_slots: [0]
magic: 412660000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately 5-6 completed WTI positions per full post-warm-up year after thirteen completed month ends; one consumed attempt per broker month. Equal-block label symmetry puts 462 of 924 distinct-rank allocations in the recent-scale-above-old state before deviation ties, neutral recent return, data, and execution gates."
expected_trades_per_year_per_symbol: 5
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_AI_SYNTHESIS_AND_PRIMARY_METHOD_EVIDENCE
r1_reasoning: "One durable AI-originated source; complete-read peer-reviewed WTI carrier evidence; named peer-reviewed Fligner-Killeen method record with explicit body-access boundary; complete signed-tag-pinned official SciPy documentation/source; explicit no-performance boundary."
r2_mechanical: PASS
r2_reasoning: "Month clock, endpoints, returns, fixed blocks, medians, deviations, relative ties, pooled midranks, fixed normal scores, group means, score variance, statistic, scale direction, side, attempt, risk, stop, spread, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_reasoning: "Registered native XTIUSD.DWX D1 history and MT5 state supply every runtime input; continuous-CFD roll, basis, financing, gap, and broker-month risks remain explicit."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, sorting, absolute values, fixed table lookup, finite arithmetic, comparisons, ATR risk controls, quotes, positions, deals, and persistent state; no trained output, prohibited signal indicator, random runtime sampling, or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: 13 completed month-end closes; 12 adjacent log returns; fixed old/recent blocks of 6; block-specific even medians; 12 median-centered absolute deviations; anchored sorted-run relative tie epsilon 1e-12; pooled midranks with rank-sum 78; 23 locked Phi^-1(0.5+R/26) integer/half-integer normal-score constants; pooled score variance divisor 11 and minimum 1e-18; finite exact two-group statistic; recent score mean strictly above old; recent six-return cumulative direction epsilon 1e-12; 900 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 stop; 40-day stale exit; 1500-point spread ceiling."
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
review_focus: "Falsify a direct-WTI monthly median-centered normal-score scale-regime continuation sleeve outside the directional XAU/SP500/NDX/XNG book. Verify completed endpoints, return orientation, fixed membership, even medians, deviations, relative midranks, every score constant, group means, variance/statistic, recent-only scale direction, cumulative-return side, consumed month, fixed risk, frozen stop, and next-month lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_tradable_month_bar, thirteen_consecutive_completed_months, no_current_month_price, twelve_adjacent_log_returns, fixed_six_old_six_recent_membership, even_sample_medians, group_median_absolute_deviations, anchored_relative_tie_runs, midrank_sum_78, fixed_normal_score_table, exact_group_score_means, pooled_score_variance_divisor_eleven, finite_fligner_killeen_statistic, recent_scale_expansion_only, recent_cumulative_return_direction, no_chi_square_or_pvalue_gate, monthly_attempt_state, risk_mode_dual, hard_stop_present, friday_close_disabled, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-09-01 and decisions/2026-09-01_qm5_41266_wti_monthly_fligner_killeen_scale_trend_g0.md: R1 passes through one durable AI source, complete peer-reviewed WTI evidence, a named peer-reviewed method record with body-access boundary, complete pinned official method/source arithmetic, hashes, adverse findings, and explicit synthesis boundaries; R2 locks data, scores, direction, attempt, risk, stop, spread, and lifecycle; R3 uses registered native WTI D1 with continuous-CFD risk; R4 uses deterministic native arithmetic only. Corrected-root dedup found no exact identity across 4,765 registry rows, 1,402 cards, and 45 Wiki nodes; fixed fixtures prove decision disagreement with the closest Ansari-Bradley and permutation-MAD neighbors."
---

# QM5_41266 WTI Fligner-Killeen Scale-Expansion Trend

## Hypothesis

WTI supply, storage, transport, refining, hedging, geopolitical, and demand
adjustments can create persistent return and volatility regimes. When the
median-centered dispersion of the latest six completed monthly WTI returns
occupies higher pooled normal-score ranks than the preceding six, continue
the recent six-month WTI return direction for one broker month.

The direct `XTIUSD.DWX` carrier is absent from the certified
XAU/SP500/NDX/XNG book. It is intended to introduce crude-oil supply/demand
exposure rather than another index, metal, or short-horizon XNG oscillator.
This does not prove decorrelation. Q02 owns activity/economics; later gates
own robustness; unchanged Q09 alone owns realized overlap.

## Source Traceability And Claim Boundary

The single governed source is
`strategy-seeds/sources/AI-CODEX-WTI-MFK-SCALE-20260901/source.md`, approved
and committed as `b13f35117b` before card extraction. Moskowitz, Ooi, and
Pedersen support only the broad monthly own-return continuation carrier and
explicit WTI membership. Fligner and Killeen plus pinned SciPy evidence
support only the median-centered normal-score scale arithmetic.

The peer-reviewed method paper body was not accessible. The card claims only
publisher metadata/abstract for that paper and uses the complete official
SciPy documentation/source for exact arithmetic. Fixed samples, recent-only
scale direction, cumulative-return side, CFD translation, risk, activity,
and lifecycle are pre-result QM choices. No statistical or trading result is
imported as an efficacy claim.

## Non-Duplicate Decision

The canonical receipt
`artifacts/qm5_wti_mfk_scale_tr_preallocation_dedup_20260901.json`, SHA-256
`26F24CE6AB0AA859ACC4B6711B1F4DD2C07DDBD33744CB078F623DBFE031AF70`,
found no exact identity. Its single fuzzy match is the expected same-sample
Ansari-Bradley neighbor.

- `QM5_41261` ranks raw returns and applies symmetric pooled-tail scores plus
  exact 924-label enumeration. This card centers each group first, ranks
  absolute deviations with ties as midranks, applies positive normal scores,
  and never enumerates labels.
- `QM5_41250` recomputes magnitude-sensitive MAD for every relabeling and
  applies an exact upper-tail cap. This card preserves the observed group
  centers and one pooled score path.
- `QM5_41252` searches an ordered daily square-return change point over 252
  observations. This card uses fixed monthly blocks and no break search.
- `QM5_12567` is a long-only XNG cumulative-RSI2 pullback. This card is
  symmetric long/short WTI and contains no oscillator state.

The locked FK-only and Ansari-only fixtures in the governed source prove both
qualification-disagreement directions.

Verdict:
`DISTINCT_WTI_MONTHLY_FIXED_SIX_BY_SIX_GROUP_MEDIAN_ABSOLUTE_DEVIATION_POOLED_MIDRANK_NORMAL_SCORE_FLIGNER_KILLEEN_RECENT_SCALE_EXPANSION_CUMULATIVE_RETURN_CONTINUATION`.

## Markets, Timeframe, And Cadence

- Exact host/traded symbol: `XTIUSD.DWX`; D1 only; slot 0; magic `412660000`.
- Decide only on the first executable tick after a genuine broker-month
  transition and within 180 elapsed minutes of the raw D1 bar open.
- Formation is thirteen consecutive completed month ends; current-month
  prices are excluded.
- Hold to the next broker-month boundary; forty elapsed calendar days is
  stale repair.
- Label symmetry implies about six recent-scale states per twelve attempts
  before ties and execution gates. Retire below five completed positions in
  any full post-warm-up year.

## Formula

For chronological completed-month closes `C[0..12]`:

```text
r[i] = ln(C[i+1]/C[i]), i=0..11
old = r[0..5]; recent = r[6..11]

m_old = median6(old); m_recent = median6(recent)
z_old[i] = abs(old[i]-m_old)
z_recent[i] = abs(recent[i]-m_recent)

sort z; form relative-tolerance runs against each run's first value
assign occupied midranks R in [1,12]; require sum(R)=78
a(R) = Phi^-1(0.5 + R/26)

A_old = mean(a_old); A_recent = mean(a_recent); A_all = mean(all a)
s2 = sum((a-A_all)^2)/11
require s2 > 1e-18
X2 = 6*((A_old-A_all)^2+(A_recent-A_all)^2)/s2
require finite X2

require A_recent > A_old + 1e-12*max(1,abs(A_old),abs(A_recent))
recent_return = sum(r[6..11])

BUY  iff recent_return >  1e-12
SELL iff recent_return < -1e-12
FLAT otherwise
```

`median6` is the average of sorted indices two and three. Sort pooled
deviations ascending. Starting at the first unassigned value, extend a tie run
only while each candidate is within
`1e-12*max(1,abs(run_anchor),abs(candidate))` of that run's first value; every
run member receives the average occupied rank. Require exactly twelve
assignments and rank sum 78. The 23 possible integer/half-integer score values
are locked constants cross-checked against the official formula. Invalid
arithmetic, a broken rank invariant, tied score means, non-expanding recent
scale, or neutral return consumes the month flat.

## Rules

- Consume the normalized broker month before every fallible entry gate.
- Select the latest close in each of the thirteen immediately prior
  consecutive broker months from a bounded 900-D1 buffer.
- Reject current-month input, missing/duplicate months, nonchronological or
  nonpositive closes, nonfinite arithmetic, or a newest endpoint more than ten
  calendar days stale.
- Preserve fixed old/recent membership. Sort copies only for medians and the
  anchored deviation tie runs; rank pooled deviations only once.
- Use exact relative ties, midranks, score table, divisor eleven, and
  two-group statistic. Never substitute raw variance, MAD permutation,
  symmetric end scores, chi-square probability, or fitted threshold.
- Trade only recent scale expansion and follow only the recent six-return
  cumulative sign.
- Both news axes, legacy news mode, and Friday close are OFF.

## 4. Entry Rules

1. Require exact EA ID, symbol, D1 period, slot, registered magic, fixed-risk
   mode, framework inputs, and every locked strategy input.
2. Process malformed-position and prior-month/stale exits before entry-only
   gates.
3. Require a genuine new broker month within the 180-minute entry window.
4. Persist current `yyyymm` before history, signal, news, spread, quote, ATR,
   sizing, margin, or order checks. No outcome retries that month.
5. Reject owned exposure or same-magic entry deals already recorded in the
   current broker month.
6. Reconstruct thirteen completed endpoints and calculate the exact locked
   Fligner-Killeen score state with strict invariants.
7. Require recent score expansion and non-neutral recent cumulative return.
8. Require spread in bounds, executable quote, completed-bar `ATR(20,D1)`,
   valid metadata, fixed-risk sizing, and sufficient margin.
9. Attach a frozen `3.5*ATR(20,D1)` hard stop, no target, and submit one market
   order in the signal direction.
10. Keep only one correctly directed, correctly registered, stop-protected
    position; otherwise close owned exposure immediately.

## 5. Exit Rules

1. Framework kill switch and broker hard stop remain authoritative.
2. Close on the first processed tick in a later normalized broker month before
   considering replacement risk.
3. Close after forty elapsed calendar days as stale repair.
4. Close immediately if owned exposure is duplicated, wrong-symbol, wrong-
   magic, wrong-direction, or stopless.
5. No intramonth flip, target, trail, break-even, partial close, Friday close,
   news exit, scale-in, grid, martingale, or pyramid is authorized.

## 6. Filters (No-Trade Module)

- Fail closed outside exact symbol, period, EA ID, slot, fixed-risk,
  news/Friday, stress, or locked-input contract.
- Reject consumed attempt, owned exposure, same-month deal, malformed month
  history, invalid return/median/deviation/rank/score/statistic arithmetic,
  non-expanding recent scale, neutral direction, excessive spread, invalid
  quote, unavailable ATR, invalid stop/volume, or insufficient margin.
- Terminal-persistent state plus deal history prevents restart retries. Tester
  initialization clears only future or prior-run markers so historical runs
  remain deterministic.
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

## 8. Parameters To Test

Q02 has one locked baseline and no optimization surface:

| input | value | contract |
|---|---:|---|
| `strategy_endpoint_count` | 13 | locked |
| `strategy_return_count` | 12 | locked |
| `strategy_block_size` | 6 | locked |
| `strategy_score_table_size` | 23 | locked integer/half-rank map |
| `strategy_relative_epsilon` | `1e-12` | locked anchored-tie/scale/side tolerance |
| `strategy_min_score_variance` | `1e-18` | locked denominator floor |
| `strategy_history_bars_d1` | 900 | locked |
| `strategy_entry_window_minutes` | 180 | locked |
| `strategy_max_endpoint_gap_days` | 10 | locked |
| `strategy_atr_period_d1` | 20 | locked |
| `strategy_atr_sl_mult` | 3.5 | locked |
| `strategy_max_hold_days` | 40 | locked |
| `strategy_max_spread_points` | 1500 | locked |
| `strategy_deviation_points` | 20 | locked |

Changing the sample, return definition, split, center, deviation transform,
tie rule, score map, statistic, scale direction, side, risk, stop, spread, or
hold after Q02 is forbidden result-driven repair.

## Source-Defined Rules

- WTI belongs to the peer-reviewed monthly own-return continuation universe.
- Fligner-Killeen's median form transforms samples to absolute deviations
  from group centers, pools ranks, applies normal scores, and measures their
  between-group dispersion relative to pooled score variance.
- No source defines the fixed sample, recent-only scale direction, six-month
  return side, CFD equivalence, fixed risk, density, or lifecycle.

## QM Interpretations

- Thirteen endpoints, fixed six/six monthly blocks, relative tie tolerance,
  recent scale direction, cumulative-return side, monthly hold, ATR stop,
  spread cap, and consumed attempt are transparent pre-result choices.
- `X2` is an arithmetic integrity diagnostic, not a significance or p-value
  claim; no distribution lookup enters the EA.
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

## Risk

- Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- One frozen `3.5*ATR(20,D1)` broker hard stop and no target.
- Signal/statistic magnitude never scales exposure.
- Continuous WTI gaps can exceed the broker stop; Q02 economics and later
  stress gates own this risk.

## Execution Assumptions

The Q02 run uses exact `XTIUSD.DWX`, D1, USD tester currency, canonical
100,000 deposit, registered slot magic, native quotes, and real-tick
execution. Continuous-CFD roll/basis, financing, spreads, gaps, and month
labels can invalidate the edge.

## Failure Conditions

Retire on zero positions, fewer than five in any full post-warm-up year,
failed score/fixture parity, malformed restart behavior, nonpositive governed
economics, or any downstream gate failure. No sample, score, side, threshold,
or hold rescue is authorized.

## Expected Behavior

The EA checks once per genuine broker month, often consumes flat, and opens at
most one position. It should never use a current-month price, retry a consumed
month, hold beyond the next month except for stale repair latency, or scale
risk with the score/statistic magnitude.

## Logging

Log normalized month key, endpoint keys/timestamps, twelve returns, both
medians, twelve deviations, twelve midranks/scores, group means, pooled score
variance, `X2`, recent cumulative return, side, ATR/stop distance, volume,
magic, order result, repair action, and exit reason. Never log credentials or
external account data.

## Framework Alignment

| card rule | module / implementation target |
|---|---|
| framework, risk, news, Friday, stress, locked-input contract | `Strategy_NoTradeFilter` plus `OnInit` framework validation |
| month endpoints, returns, medians, deviations, midranks, scores, statistic, side, quote, ATR, sizing | `Strategy_EntrySignal` and bounded helpers |
| malformed-position, new-month, and stale repair | `Strategy_ManageOpenPosition` |
| monthly/stale lifecycle reason mapping | `Strategy_ExitSignal` plus framework close helper |
| both news axes OFF | `Strategy_NewsFilterHook` and framework initialization |

## Falsification And Requalification

Any change to symbol, timeframe, endpoint count, return orientation, block
membership, median, deviation transform, tie rule, normal-score map, variance,
statistic, scale direction, side, attempt timing, risk, stop, spread, or exit
requires a new binary and full pipeline requalification. Ambiguous history,
arithmetic, or state fails closed. Q02 may kill the card but may not tune it;
Q09 alone may establish decorrelation.

## Safety Boundary

This card authorizes only one branch build, deterministic reference tests,
strict Q01, one D1 `RISK_FIXED` backtest setfile, and one paced non-live Q02
handoff if the governed CPU ceiling permits. It does not authorize a manual
tester run, optimization, live/demo/shadow/stress setfile, AutoTrading,
`T_Live`, deploy/live manifest, portfolio-gate mutation, portfolio admission,
or correlation waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-09-01 | initial WTI Fligner-Killeen scale-expansion card | G0 | APPROVED; build pending |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-09-01 | APPROVED; R1-R4 PASS | source approval, corrected-root dedup receipt, G0 decision, and this card |
| Q01 Build Validation | - | NOT_BUILT | pending magic allocation and exact implementation |
| Q02 Baseline Screening | - | NOT_ENQUEUED_Q01_PENDING | one paced enqueue only after strict Q01 and CPU admission |
