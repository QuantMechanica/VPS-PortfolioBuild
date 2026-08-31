---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-WTI-MWASSER-20260901_S01
variant_id: AI-CODEX-WTI-MWASSER-20260901_S01
source_id: AI-CODEX-WTI-MWASSER-20260901
ea_id: QM5_41259
slug: wti-mwasser-shift-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41259_wti-mwasser-shift-tr_card.md
execution_contract_status: APPROVED
created: 2026-09-01
created_by: Research+Development
last_updated: 2026-09-01
g0_status: APPROVED
g0_decision: decisions/2026-09-01_qm5_41259_wti_monthly_wasserstein_shift_trend_g0.md
source_approval: decisions/2026-09-01_wti_monthly_wasserstein_shift_trend_source_approval.md
source_author: "OpenAI Codex"
source_authors: "OpenAI Codex; Aaditya Ramdas; Nicolas Garcia; Marco Cuturi; SciPy community; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "OpenAI Codex (2026), WTI monthly exact-permutation Wasserstein-1 shift continuation; supporting records Ramdas, Garcia, and Cuturi (2015), arXiv 1509.02237; SciPy 1.13.1 pinned at commit 44e4ebaac992fde33f04638b99629d23973cb9b2; and Moskowitz, Ooi, and Pedersen (2012), JFE 104(2), DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: ai_originated_governed_source
    citation: "OpenAI Codex (2026). WTI monthly exact-permutation Wasserstein-1 shift continuation."
    location: "strategy-seeds/sources/AI-CODEX-WTI-MWASSER-20260901/source.md"
    quality_tier: governed_source
    role: exact_trading_hypothesis_formula_thresholds_risk_and_lifecycle
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: monthly_own_return_continuation_and_explicit_wti_membership_only
  - type: public_statistical_paper
    citation: "Ramdas, A., Garcia, N., and Cuturi, M. (2015). On Wasserstein Two Sample Testing and Related Families of Nonparametric Tests."
    location: "arXiv:1509.02237; retrieval evidence strategy-seeds/sources/AI-CODEX-WTI-MWASSER-20260901/retrieval_route_ramdas_wasserstein_20260901.json"
    quality_tier: A
    role: nonparametric_two_sample_wasserstein_and_quantile_representation_only
  - type: primary_statistical_software
    citation: "SciPy community (2024). scipy.stats.wasserstein_distance, SciPy 1.13.1 documentation and source."
    location: "scipy/scipy commit 44e4ebaac992fde33f04638b99629d23973cb9b2; retrieval evidence strategy-seeds/sources/AI-CODEX-WTI-MWASSER-20260901/retrieval_route_scipy_wasserstein_20260901.json"
    quality_tier: A
    role: wasserstein_one_empirical_definition_and_equal_weight_implementation_only
strategy_mechanic: monthly-wti-twelve-completed-log-returns-fixed-six-old-six-recent-one-dimensional-wasserstein-one-sorted-quantile-distance-exact-924-label-permutation-three-fifths-tail-recent-minus-old-median-continuation
sources:
  - "[[sources/AI-CODEX-WTI-MWASSER-20260901]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/nonparametric-distribution-shift]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-log-return]]"
  - "[[indicators/wasserstein-one-distance]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, distribution-shift, wasserstein-one, exact-label-permutation, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
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
magic: 412590000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately 6-7 completed WTI positions per full post-warm-up year; one consumed attempt per broker month. The locked equally spaced market-free reference qualifies 540/924 label states, about 7.013 decisions/year before market and execution gates."
expected_trades_per_year_per_symbol: 7
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_AI_SYNTHESIS_AND_PRIMARY_METHOD_EVIDENCE
r1_reasoning: "One durable AI-originated source ID and prompt/output trail; complete governed peer-reviewed WTI evidence; public Wasserstein method paper; pinned official SciPy documentation/source; explicit no-performance and translation boundaries."
r2_mechanical: PASS
r2_reasoning: "Month clock, endpoints, returns, fixed blocks, sorting, equal-weight W1 formula, tolerance, all 924 assignments, inclusive three-fifths tail, medians, side, attempt, risk, stop, spread, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_reasoning: "Registered native XTIUSD.DWX D1 history and MT5 state supply every runtime input; continuous-CFD roll, basis, financing, gap, and broker-month-label risks remain."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, finite sorting/subtraction/absolute-value/sum loops, exhaustive fixed-label enumeration, medians, comparisons, ATR risk, quotes, positions, deals, and persistent state; no trained output, prohibited signal indicator, random runtime sampling, or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: 13 consecutive completed month-end closes; 12 adjacent log returns; fixed old/recent blocks of 6; W1=mean(abs(sort(old)[j]-sort(recent)[j]),j=0..5); all 924 six-label assignments; relative comparison epsilon 1e-12; inclusive exact tail at most 554 (5*tail<=3*924); even-sample median direction epsilon 1e-12; 900 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 frozen stop; 40-day stale exit; 1500-point spread ceiling."
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
review_focus: "Falsify a direct-WTI monthly quantile-transport distribution-shift sleeve outside the certified XAU/SP500/NDX/XNG book. Verify endpoints, return orientation, fixed membership, sorting, Wasserstein arithmetic, inclusive tolerance, all 924 assignments, tail cap 554, median side, consumed month, fixed risk, frozen stop, and next-month lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_tradable_month_bar, thirteen_consecutive_completed_months, no_current_month_price, twelve_adjacent_log_returns, fixed_six_old_six_recent_membership, ascending_six_value_sorts, equal_weight_sorted_quantile_pairing, wasserstein_mean_six_absolute_differences, exact_924_label_assignments, relative_inclusive_tail_tolerance, three_fifths_tail_count_554, even_sample_median_direction, monthly_attempt_state, risk_mode_dual, hard_stop_present, friday_close_disabled, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-09-01 and decisions/2026-09-01_qm5_41259_wti_monthly_wasserstein_shift_trend_g0.md: R1 passes through one durable AI source, complete governed peer-reviewed WTI evidence, a public statistical paper, pinned official SciPy evidence, and explicit boundaries; R2 locks data, W1 arithmetic, enumeration, boundary, side, attempt, risk, stop, spread, and lifecycle; R3 uses registered native WTI D1 with continuous-CFD risk; R4 uses deterministic native arithmetic only. Corrected-root dedup found no exact identity across 4,758 registry rows, 1,395 cards, and 45 Wiki nodes; nonlinear fixtures separate energy-distance, integrated-ECDF, and MAD-scale neighbors."
---

# QM5_41259 WTI Exact-Permutation Wasserstein-1 Shift Trend

## Hypothesis

WTI's physical supply, storage, transport, refining, hedging, geopolitical, and
demand shocks can move the quantiles of monthly returns. When the newest six
completed returns have a sufficiently broad Wasserstein-1 displacement from
the prior six, continue the direction of the block-median shift for one
monthly package.

This is an untested direct-crude structural-trend hypothesis. Q02 owns
activity and economics; later gates own robustness; unchanged Q09 alone owns
overlap.

## Source traceability and claim boundary

The single source is
`strategy-seeds/sources/AI-CODEX-WTI-MWASSER-20260901/source.md`, approved at
commit `f87ed68648` before extraction. The peer-reviewed WTI record supports
only carrier, monthly cadence, and own-return continuation. Ramdas et al. and
pinned SciPy evidence support only the Wasserstein definition, two-sample
context, and one-dimensional quantile representation. The exact split,
exhaustive tail, 60% activity boundary, CFD translation, risk, and lifecycle
are pre-result QM choices.

No statistical or trading result is imported as an efficacy claim.

## Non-duplicate boundary

The canonical receipt
`artifacts/qm5_wti_mwasser_shift_tr_preallocation_dedup_20260901.json` found no
exact identity. `QM5_41258` uses all cross- and within-block pair distances in
energy distance; `QM5_41255` uses a pooled-rank integrated ECDF path; and
`QM5_41250` uses within-block MAD scale. This card uses monotone sorted
quantile pairing and actual return spacing.

With squared pooled values and pseudo-recent ranks `{0,1,2,5,8,10}`, energy
qualifies at tail 508 while Wasserstein stays flat at 572. With values
`exp(rank/3)` and ranks `{0,2,3,5,7,10}`, Wasserstein qualifies at 540 while
energy stays flat at 556. On the exponential values, ranks `{0,1,4,6,8,9}`
qualify Wasserstein at 496 while integrated ECDF stays flat at 700; ranks
`{0,1,2,4,8,10}` reverse the result at 588 versus 230.

Verdict:
`DISTINCT_WTI_MONTHLY_FIXED_SIX_BY_SIX_WASSERSTEIN_ONE_SORTED_QUANTILE_DISTANCE_EXACT_924_LABEL_PERMUTATION_THREE_FIFTHS_TAIL_MEDIAN_DIRECTION_CONTINUATION`.

## Rules

### Market, clock, and data

- Host and trade exact `XTIUSD.DWX`, D1, slot 0, magic `412590000`.
- Act only within 180 elapsed minutes of the first D1 bar of a genuine new
  broker month. Persist the `yyyymm` attempt before every fallible gate.
- Reconstruct thirteen immediately prior consecutive completed month-end
  closes from a bounded 900-D1 buffer. Exclude every current-month price.
- Require positive finite closes, strict chronology, exact month continuity,
  and a newest endpoint no more than ten calendar days before current month.

### Exact signal

```text
r[i] = log(C[i+1] / C[i]), i=0..11
old = r[0..5]; recent = r[6..11]

sort old and recent ascending
W1_observed = sum(abs(old[j]-recent[j]), j=0..5) / 6

tail_count = 0; assignment_count = 0
for each 12-bit mask having exactly six set bits:
    pseudo_recent = sorted values selected by mask
    pseudo_old = sorted complement
    W1_perm = sum(abs(pseudo_old[j]-pseudo_recent[j]), j=0..5) / 6
    if W1_perm + 1e-12*max(1,abs(W1_observed)) >= W1_observed:
        tail_count++
    assignment_count++

require assignment_count == 924
require tail_count <= 554
require 5*tail_count <= 3*assignment_count

median6(x) = average of sorted x[2] and x[3]
direction_delta = median6(recent) - median6(old)
BUY  iff direction_delta >  1e-12
SELL iff direction_delta < -1e-12
FLAT otherwise
```

All closes, returns, sort inputs, pair differences, sums, distances, medians,
and comparisons must be finite. An invalid enumeration, excessive tail, or
zero median direction consumes the month flat. Distance magnitude never
scales risk.

## 4. Entry Rules

- Reject existing owned exposure or a same-magic current-month entry deal.
- Both news axes, legacy news mode, and Friday close are OFF.
- Reject crossed/negative quotes and a positive spread above 1,500 points.
- Require completed-bar `ATR(20,D1)` and a normalized `3.5*ATR` stop.
- Open at most one market position with `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`, a frozen broker hard stop, and no target.

## 5. Exit Rules

- Close on the first tick in a later normalized broker month.
- Close after forty elapsed calendar days as stale repair.
- No target, opposite-signal exit, or same-month re-entry.

## 6. Filters (No-Trade Module)

Fail closed on wrong symbol/timeframe/ID/slot/magic, unlocked input, invalid
risk/news/Friday/stress state, malformed history, late attachment, existing
exposure, same-month deal, invalid W1 arithmetic or enumeration, excessive
tail, neutral direction, crossed quote, excessive spread, invalid ATR/stop
metadata, or nonpositive fixed-risk size.

## 7. Trade Management Rules

Repair duplicates, wrong symbol/magic/side, invalid volume, missing stop, or
invalid open time by closing. Do not trail, break even, partially close, grid,
martingale, scale in, or pyramid.

## Parameters to test

Q02 has one locked baseline and no optimization surface:

| parameter | default | status |
|---|---:|---|
| `strategy_month_returns` | 12 | locked |
| `strategy_block_size` | 6 | locked |
| `strategy_assignment_count` | 924 | locked |
| `strategy_tail_numerator` | 3 | locked |
| `strategy_tail_denominator` | 5 | locked |
| `strategy_tail_count_max` | 554 | locked |
| `strategy_wasserstein_epsilon` | 1e-12 | locked |
| `strategy_direction_epsilon` | 1e-12 | locked |
| `strategy_history_bars` | 900 | locked |
| `strategy_entry_grace_minutes` | 180 | locked |
| `strategy_endpoint_stale_days` | 10 | locked |
| `strategy_atr_period` | 20 | locked |
| `strategy_atr_sl_mult` | 3.5 | locked |
| `strategy_stale_days` | 40 | locked |
| `strategy_max_spread_points` | 1500 | locked |

Changing the sample, distance definition, sort/pair convention, tolerance,
tail, direction, risk, stop, or hold after Q02 is forbidden.

## Reputable-source criteria

| gate | verdict | evidence |
|---|---|---|
| R1 | PASS_WITH_AI_SYNTHESIS_AND_PRIMARY_METHOD_EVIDENCE | One AI source, complete governed WTI support, public method paper, pinned official SciPy evidence, explicit no-alpha boundary. |
| R2 | PASS | Exact clock, data, W1 formula, enumeration, side, risk, and lifecycle. |
| R3 | PASS | Native registered WTI D1 and MT5 state; CFD risks disclosed. |
| R4 | PASS | Deterministic native arithmetic; no trained or prohibited runtime signal. |

## Risk and kill criteria

- Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- Retire on zero positions, fewer than five in any full scored year,
  nonpositive governed economics, or failed fixture.
- Fail current-month leakage, wrong return orientation, wrong sort/pairing,
  wrong divisor six, wrong assignment count, tolerance, tail cap, side,
  missing stop, wrong risk mode, retry, or nondeterminism.
- Q09 alone can establish realized correlation; no waiver is granted.

## Framework alignment

- no_trade: exact identity, fixed-risk mode, month/attempt/history/W1 state,
  position/deal, spread, quote, ATR, stop, and sizing guards.
- trade_entry: cached qualified Wasserstein direction, one fixed-risk WTI
  order, frozen ATR stop, no target.
- trade_management: malformed-position, next-month, and forty-day repair.
- trade_close: framework close helper and deterministic reason mapping.

## Safety boundary

Authorized: one branch build, reference tests, strict Q01, one D1 fixed-risk
setfile, and one paced non-live Q02 enqueue if CPU admission permits. Excluded:
manual tester, live/demo/shadow/stress/optimization preset, AutoTrading,
`T_Live`, deploy/live manifest, portfolio-gate change, admission, or waiver.

## Pipeline history

| version | date | reason | phase | verdict |
|---|---|---|---|---|
| v1 | 2026-09-01 | initial exact-permutation Wasserstein-1 WTI card | G0 | APPROVED |

## Pipeline phase status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 | 2026-09-01 | APPROVED; R1-R4 PASS | source approval, dedup, card |
| Q01 | - | NOT_BUILT | pending magic allocation and implementation |
| Q02 | - | NOT_ENQUEUED_Q01_PENDING | enqueue after strict Q01 and CPU admission |
