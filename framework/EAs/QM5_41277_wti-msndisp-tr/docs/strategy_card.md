---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-WTI-MSNDISP-TREND-20260901_S01
variant_id: AI-CODEX-WTI-MSNDISP-TREND-20260901_S01
source_id: AI-CODEX-WTI-MSNDISP-TREND-20260901
ea_id: QM5_41277
slug: wti-msndisp-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41277_wti-msndisp-tr_card.md
execution_contract_status: APPROVED
created: 2026-09-01
created_by: Research+Development
last_updated: 2026-09-02
g0_status: APPROVED
g0_decision: decisions/2026-09-01_qm5_41277_wti_monthly_sn_dispersion_trend_g0.md
source_approval: decisions/2026-09-01_wti_monthly_sn_dispersion_trend_source_approval.md
source_author: "OpenAI Codex"
source_authors: "OpenAI Codex; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; Peter J. Rousseeuw; Christophe Croux; robustbase authors"
source_citation: "OpenAI Codex (2026), WTI completed-month Sn-core dispersion-normalized trend continuation; supporting records Moskowitz, Ooi, and Pedersen (2012), Journal of Financial Economics 104(2), DOI 10.1016/j.jfineco.2011.11.003; Rousseeuw and Croux (1993), Journal of the American Statistical Association 88(424), DOI 10.1080/01621459.1993.10476408; CRAN robustbase 0.99-7 commit 54c5cc98e27050a78bbd03be15f07a7ba88de62a."
source_citations:
  - type: ai_originated_governed_source
    citation: "OpenAI Codex (2026). WTI completed-month Sn-core dispersion-normalized trend continuation."
    location: "strategy-seeds/sources/AI-CODEX-WTI-MSNDISP-TREND-20260901/source.md"
    quality_tier: governed_source
    role: exact_trading_hypothesis_formula_activity_boundary_risk_and_lifecycle
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: monthly_own_return_continuation_and_explicit_wti_membership_only
  - type: peer_reviewed_statistical_method
    citation: "Rousseeuw, P. J. and Croux, C. (1993). Alternatives to the Median Absolute Deviation. Journal of the American Statistical Association 88(424), 1273-1283."
    location: "DOI 10.1080/01621459.1993.10476408; retrieval evidence strategy-seeds/sources/AI-CODEX-WTI-MSNDISP-TREND-20260901/retrieval_route_rousseeuw_croux_sn_20260901.json"
    quality_tier: A
    role: sn_nested_median_scale_functional_only
  - type: primary_software
    citation: "CRAN robustbase 0.99-7, R/qnsn.R and src/qn_sn.c."
    location: "commit 54c5cc98e27050a78bbd03be15f07a7ba88de62a; retrieval evidence strategy-seeds/sources/AI-CODEX-WTI-MSNDISP-TREND-20260901/retrieval_route_robustbase_sn_20260901.json"
    quality_tier: A
    role: exact_low_high_median_convention_and_multiplier_separation
strategy_mechanic: monthly-wti-completed-month-final17-closes-sixteen-daily-log-returns-sixteen-leave-one-out-lower-medians-lower-median-sn-core-net-displacement-greater-than-three-core-continuation
sources:
  - "[[sources/AI-CODEX-WTI-MSNDISP-TREND-20260901]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/sn-core-robust-dispersion]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-daily-log-returns]]"
  - "[[indicators/sn-nested-median-core]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, robust-dispersion-normalized, sn-core, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
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
magic: 412770000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately 6-8 completed WTI positions per full post-warm-up year; one consumed attempt per broker month and a fixed Sn-core coherence gate. Q02 must establish at least five completed positions per full year or retire."
expected_trades_per_year_per_symbol: 7
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_SN_TRADING_MECHANIZATION_AND_CONTINUOUS_CFD_TRANSLATION_RISK
r1_reasoning: "Complete-read peer-reviewed WTI monthly continuation evidence plus complete-read peer-reviewed Sn method evidence and commit-pinned primary software; exact daily-return trading conjunction disclosed as untested QM synthesis."
r2_mechanical: PASS
r2_reasoning: "Month clock, sessions, final seventeen closes, sixteen returns, endpoint identity, 16x15 leave-one-out distances, inner and outer lower medians, omitted multipliers, inclusive three-core gate, side, attempt, risk, stop, spread, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_reasoning: "Registered native XTIUSD.DWX D1 history and MT5 state supply every runtime input; roll, basis, financing, gap, and broker-label risks remain."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, sorting, comparisons, ATR risk, quotes, positions, deals, and persistent state; no trained output or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: immediately completed broker month with 17-23 D1 sessions; final 17 chronological closes; 16 adjacent log returns; 16 leave-one-out arrays of 15 absolute distances; eighth one-based inner lower median; eighth one-based outer lower median; no 1.1926 or finite-sample multiplier; sn_core above 1e-12; inclusive abs(net)>=3*sn_core; endpoint tolerance 1e-10; 120 D1 history bars; 180-minute month-entry grace; ATR(20)*3.5 frozen stop; 40-day stale exit; 1500-point spread ceiling."
risk_fixed_backtest: 1000
risk_percent_backtest: 0
portfolio_weight_backtest: 1
news_temporal_mode: QM_NEWS_TEMPORAL_OFF
news_compliance_profile: QM_NEWS_COMPLIANCE_NONE
friday_close_enabled: false
pipeline_phase: Q02
q01_status: PASS
q02_status: ENQUEUED_PENDING
force_build: true
review_focus: "Falsify a direct-WTI completed-month Sn-core dispersion-normalized trend sleeve outside the certified XAU/SP500/NDX/XNG book. Verify month/session membership, final seventeen closes, sixteen return orientation, endpoint identity, all 240 directed leave-one-out distances, exact inner/outer lower medians, absent multipliers, inclusive three-core side, consumed month, fixed risk, frozen stop, and next-month lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_tradable_month_bar, immediately_completed_month_only, bounded_month_session_count, final_seventeen_daily_closes, no_current_month_price, sixteen_log_returns, endpoint_identity, sixteen_leave_one_out_distance_arrays, inner_lower_median_index_seven, outer_lower_median_index_seven, no_sn_consistency_multiplier, no_finite_sample_multiplier, sn_core_floor, inclusive_three_core_direction, monthly_attempt_state, risk_mode_dual, hard_stop_present, friday_close_disabled, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-09-01 and decisions/2026-09-01_qm5_41277_wti_monthly_sn_dispersion_trend_g0.md: R1 uses complete-read peer-reviewed WTI and Sn evidence plus pinned primary-software arithmetic with disclosed QM trading translation; R2 locks clock, data, nested medians, side, attempt, risk, stop, spread, and lifecycle; R3 uses registered native WTI D1 with continuous-CFD risk; R4 uses deterministic native arithmetic only. Corrected-root dedup found no exact identity and one expected Qn fuzzy neighbor across 4,776 registry rows, 1,412 cards, and 45 Wiki nodes; two fixed vectors prove two-way qualification disagreement."
---

# QM5_41277 WTI Completed-Month Sn-Core Dispersion Trend

## Hypothesis

When the net move across the final sixteen daily returns of a completed WTI
broker month is large relative to the raw Sn nested-median dispersion core of
those returns, carry that robustly coherent direction into the next month.
The leave-one-out median-of-medians core limits the influence of isolated
daily shocks and asks a different question from a global Qn distance order
statistic, L1 path efficiency, or RMS coherence.

This is an untested direct-crude structural-trend hypothesis. WTI adds a
physical-energy carrier absent from the stated XAU/SP500/NDX/XNG book, but
carrier difference is not a correlation result. Q02 owns activity and
economics; later gates own robustness; unchanged Q09 alone owns overlap.

## Source Traceability And Claim Boundary

The source of record is
`strategy-seeds/sources/AI-CODEX-WTI-MSNDISP-TREND-20260901/source.md`,
authorized before extraction by
`decisions/2026-09-01_wti_monthly_sn_dispersion_trend_source_approval.md`.
Moskowitz, Ooi, and Pedersen support only WTI membership, monthly cadence,
and broad own-return continuation. Rousseeuw and Croux plus pinned
`robustbase` support only the Sn functional and median conventions.

No source tests a WTI-only within-month Sn trading gate, continuous CFD,
fixed-dollar ATR risk, or the QM book. The exact formula and execution
contract below are pre-result QM synthesis. No source alpha, profit factor,
p-value, drawdown, trade count, cost, CFD equivalence, or decorrelation
statistic is imported.

## Non-Duplicate Boundary

The canonical receipt
`artifacts/qm5_wti_msndisp_tr_preallocation_dedup_20260901.json` found no
exact identity and one expected fuzzy neighbor, `QM5_41275`.

- This card uses sixteen leave-one-out inner lower medians followed by an
  outer lower median. `QM5_41275` selects one global 36th order statistic from
  120 unordered distances.
- Fixed vector A buys here while Qn, L1, and RMS stay flat. Fixed vector B
  stays flat here while Qn, L1, and RMS buy. Exact values are locked in the
  approved source and executable reference tests.
- Old/recent scale-state strategies compare two monthly-return groups. This
  card uses one fixed completed month's daily-return distribution.
- `QM5_20187` has only an endpoint sign. Certified `QM5_12567` is a two-day
  long-only XNG pullback.

Verdict:
`DISTINCT_WTI_COMPLETED_MONTH_FINAL17_RETURN_SN_NESTED_MEDIAN_DISPERSION_NORMALIZED_CONTINUATION`.

## Rules

### Market, Clock, And Data

- Host and trade exact `XTIUSD.DWX`, D1, slot 0, magic `412770000`.
- Act only within 180 elapsed minutes of the first D1 bar of a genuine new
  broker month. Persist the `yyyymm` attempt before every fallible entry gate.
- Reconstruct only the immediately completed broker month from a bounded
  120-D1 buffer. Require 17 through 23 chronological completed sessions.
- Select its final seventeen closes in chronological order. Exclude every
  current-month price.
- Require positive finite closes and strictly increasing timestamps.

### Exact Signal

```text
r[i] = ln(C[i+1] / C[i]), i=0..15
net  = sum(r)
require abs(net - ln(C[16]/C[0])) <= 1e-10

for i=0..15:
    D_i = sort(abs(r[i]-r[j]) for j!=i)
    require len(D_i) == 15
    inner[i] = D_i[7]

I = sort(inner)
sn_core = I[7]
require sn_core > 1e-12

BUY  if net >=  3*sn_core
SELL if net <= -3*sn_core
FLAT otherwise
```

`D_i[7]` is the eighth one-based value of an odd fifteen-value set. `I[7]`
is the lower median, the eighth one-based value of sixteen inner medians. The
EA deliberately omits the `1.1926` consistency multiplier and every
finite-sample multiplier. The three-core boundary is inclusive. Wrong
history, membership, chronology, close, return, endpoint, distance count,
sort, median index, core, or side consumes the month flat. Signal magnitude
never scales risk.

This is a deterministic classifier, not a statistical test. There is no
p-value, significance threshold, independence claim, or volatility forecast.

### Entry Rules

- Reject existing owned exposure or a same-magic current-month entry deal.
- Both news axes, legacy news mode, and Friday close are OFF.
- Reject crossed/negative quotes and a positive spread above 1,500 points.
- Require completed-bar `ATR(20,D1)` and a normalized `3.5*ATR` stop.
- Open at most one market position with `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`, a frozen broker hard stop, and no target.

### Exit And Management Rules

- Close on the first tick in a later broker month.
- Close after forty elapsed calendar days as stale repair.
- Close duplicate, wrong-symbol, wrong-magic, wrong-side, invalid-volume, or
  stopless owned exposure before entry-only gates.
- No target, trail, break-even, partial close, grid, martingale, scale-in,
  pyramid, opposite-signal exit, or same-month retry.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| parameter | default | status |
|---|---:|---|
| `strategy_month_sessions_min` | 17 | locked |
| `strategy_month_sessions_max` | 23 | locked |
| `strategy_close_count` | 17 | locked |
| `strategy_return_count` | 16 | locked |
| `strategy_inner_distance_count` | 15 | locked |
| `strategy_inner_median_one_based` | 8 | locked |
| `strategy_outer_count` | 16 | locked |
| `strategy_outer_lomed_one_based` | 8 | locked |
| `strategy_sn_core_floor` | `1e-12` | locked |
| `strategy_net_core_multiplier` | 3.0 | locked |
| `strategy_endpoint_tolerance` | `1e-10` | locked |
| `strategy_history_bars_d1` | 120 | locked |
| `strategy_entry_window_minutes` | 180 | locked |
| `strategy_atr_period_d1` | 20 | locked |
| `strategy_atr_sl_mult` | 3.5 | locked |
| `strategy_max_hold_days` | 40 | locked |
| `strategy_max_spread_points` | 1500 | locked |
| `strategy_deviation_points` | 20 | locked |

Changing the sample, median convention, multiplier, side, carrier, risk,
stop, spread, or hold after Q02 is forbidden.

## Expected Behaviour And Frequency

There is one consumed attempt per broker month and at most twelve entries per
full year. The six-to-eight ordering prior is not a source probability. Q02
must establish at least five completed positions in every full post-warm-up
year or retire the candidate.

## Reputable-Source Criteria

| gate | verdict | evidence |
|---|---|---|
| R1 | PASS_WITH_SN_TRADING_MECHANIZATION_AND_CONTINUOUS_CFD_TRANSLATION_RISK | Complete-read peer-reviewed WTI trend and Sn method evidence plus pinned primary-software arithmetic; exact trading conjunction disclosed as untested QM synthesis. |
| R2 | PASS | Exact clock, data, returns, endpoint identity, 16x15 distances, inner/outer lower medians, omitted multipliers, inclusive direction, attempt, risk, and lifecycle. |
| R3 | PASS | Native registered WTI D1 and MT5 state; roll/basis/financing/gap risks disclosed. |
| R4 | PASS | Deterministic native logarithms, sorting, comparisons, and state only; no trained signal or external runtime feed. |

## Risk

Q02-Q10 use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. This card authorizes no live preset.

Retire on zero positions, fewer than five completed positions in any full
post-warm-up year, nonpositive governed economics, failed deterministic
fixtures, or any downstream gate failure. Fail current-month leakage, wrong
month/session membership, wrong final-seventeen selection, reversed return,
endpoint mismatch, missing or duplicate leave-one-out distance, wrong
sort/index/core, hidden multiplier, wrong inclusive gate/side, retry, missing
stop, wrong risk mode, late entry, missed exit, or nondeterminism. No
result-driven rescue is authorized.

WTI gaps, geopolitical and inventory shocks, CFD roll/basis and financing,
hard-stop slippage, sparse monthly decisions, and correlation with XNG or
risk assets can dominate the premise. A nested median can ignore a minority
of extreme returns; the fixed-vector disagreement is deliberate, not hidden.

## Framework Alignment

- `no_trade`: exact identity, carrier, period, risk/news/Friday/input locks,
  month clock, attempt, history, position/deal, quote, spread, ATR, stop, and
  sizing guards.
- `trade_entry`: cached Sn-core side, one fixed-risk WTI market order, frozen
  ATR stop, and no target.
- `trade_management`: malformed-position, next-month, and forty-day repair.
- `trade_close`: framework close helper, broker hard stop, and kill switch.

## Validation Plan

1. Card schema lint and forbidden-token scan.
2. Canonical dedup receipt plus two-way Sn/Qn disagreement fixtures.
3. Pure reference checks for month membership, return orientation, endpoint
   identity, all leave-one-out distances, exact medians, inclusive sides, and
   counterexamples.
4. Strict MQL5 compile and framework build check.
5. Canonical `RISK_FIXED` XTIUSD D1 backtest set only.
6. One paced Q02 enqueue if whole-host CPU admission allows it; no manual
   tester launch.

## Safety Boundary

Authorized: one registered V5 identity, one non-live source build, reference
tests, strict Q01, and at most one paced Q02 enqueue.

Forbidden: manual backtest, optimization, live/demo/shadow/stress setfiles,
external runtime data, portfolio-gate edits, correlation waiver, portfolio
admission, deploy/live manifest, `T_Live`, AutoTrading, or terminal control.

## Pipeline History

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 | 2026-09-01 | APPROVED; R1-R4 PASS | source approval, complete-read receipts, dedup, card decision |
| Q01 | 2026-09-02 | PASS | governed `COMPILE_OK`; build check PASS, 0 compile errors, 0 compile warnings |
| Q02 | 2026-09-02 | ENQUEUED_PENDING | `01fbf53a-4349-4d37-aa1f-a94279c730ca`; paced worker owns dispatch |

## Revision History

| version | date | reason | phase | verdict |
|---|---|---|---|---|
| v1 | 2026-09-01 | initial WTI Sn-core dispersion-normalized trend card | G0 | APPROVED |
| v1.1 | 2026-09-02 | governed build and paced handoff | Q01/Q02 | PASS / ENQUEUED_PENDING |
