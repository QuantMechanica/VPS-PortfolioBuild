---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-WTI-MENERGY-20260901_S01
variant_id: AI-CODEX-WTI-MENERGY-20260901_S01
source_id: AI-CODEX-WTI-MENERGY-20260901
ea_id: QM5_41258
slug: wti-menergy-shift-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41258_wti-menergy-shift-tr_card.md
execution_contract_status: APPROVED
created: 2026-09-01
created_by: Research+Development
last_updated: 2026-09-01
g0_status: APPROVED
g0_decision: decisions/2026-09-01_qm5_41258_wti_monthly_energy_distance_shift_trend_g0.md
source_approval: decisions/2026-09-01_wti_monthly_energy_distance_shift_trend_source_approval.md
source_author: "OpenAI Codex"
source_authors: "OpenAI Codex; Gabor J. Szekely; Maria L. Rizzo; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "OpenAI Codex (2026), WTI monthly exact-permutation energy-distance shift continuation; supporting records CRAN energy 1.7-12 pinned at commit 5c2b2d553b4245ebe2a7fd933d93b8917cea799b and Moskowitz, Ooi, and Pedersen (2012), JFE 104(2), DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: ai_originated_governed_source
    citation: "OpenAI Codex (2026). WTI monthly exact-permutation energy-distance shift continuation."
    location: "strategy-seeds/sources/AI-CODEX-WTI-MENERGY-20260901/source.md"
    quality_tier: governed_source
    role: exact_trading_hypothesis_formula_thresholds_risk_and_lifecycle
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: monthly_own_return_continuation_and_explicit_wti_membership_only
  - type: primary_statistical_software
    citation: "Rizzo, M. and Szekely, G. (2024). energy 1.7-12: E-Statistics, CRAN package manual and R source."
    location: "cran/energy commit 5c2b2d553b4245ebe2a7fd933d93b8917cea799b; retrieval evidence strategy-seeds/sources/AI-CODEX-WTI-MENERGY-20260901/retrieval_route_cran_energy_20260901.json"
    quality_tier: A
    role: two_sample_energy_distance_formula_and_resampling_context_only
strategy_mechanic: monthly-wti-twelve-completed-log-returns-fixed-six-old-six-recent-two-sample-energy-distance-exact-924-label-permutation-three-fifths-tail-recent-minus-old-median-continuation
sources:
  - "[[sources/AI-CODEX-WTI-MENERGY-20260901]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/nonparametric-distribution-shift]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-log-return]]"
  - "[[indicators/two-sample-energy-distance]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, distribution-shift, energy-distance, exact-label-permutation, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
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
magic: 412580000
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
r1_track_record: PASS_WITH_AI_SYNTHESIS_AND_PINNED_PRIMARY_SOFTWARE
r1_reasoning: "One durable AI-originated source ID and prompt/output trail; complete-read peer-reviewed WTI evidence; complete pinned CRAN method manual/source; explicit Wiley policy boundary; exact trading conjunction disclosed as untested QM synthesis."
r2_mechanical: PASS
r2_reasoning: "Month clock, endpoints, returns, fixed blocks, energy formula, tolerance, all 924 assignments, inclusive three-fifths tail, medians, side, attempt, risk, stop, spread, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_reasoning: "Registered native XTIUSD.DWX D1 history and MT5 state supply every runtime input; continuous-CFD roll, basis, financing, gap, and broker-month-label risks remain."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, finite absolute-distance loops, exhaustive fixed-label enumeration, medians, comparisons, ATR risk, quotes, positions, deals, and persistent state; no trained output, prohibited signal indicator, random runtime sampling, or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: 13 consecutive completed month-end closes; 12 adjacent log returns; fixed old/recent blocks of 6; two-sample E=3*(2*M_cross-M_old-M_recent) with ordered-pair averages including within-block self-distances; all 924 six-label assignments; relative comparison epsilon 1e-12; inclusive exact tail at most 554 (5*tail<=3*924); even-sample median direction epsilon 1e-12; 900 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 frozen stop; 40-day stale exit; 1500-point spread ceiling."
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
review_focus: "Falsify a direct-WTI monthly distribution-shift sleeve outside the certified XAU/SP500/NDX/XNG book. Verify endpoints, return orientation, fixed membership, energy arithmetic, inclusive tolerance, all 924 assignments, tail cap 554, median side, consumed month, fixed risk, frozen stop, and next-month lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_tradable_month_bar, thirteen_consecutive_completed_months, no_current_month_price, twelve_adjacent_log_returns, fixed_six_old_six_recent_membership, energy_cross_and_within_ordered_pair_means, within_self_distances_included, energy_weight_three, exact_924_label_assignments, relative_inclusive_tail_tolerance, three_fifths_tail_count_554, even_sample_median_direction, monthly_attempt_state, risk_mode_dual, hard_stop_present, friday_close_disabled, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-09-01 and decisions/2026-09-01_qm5_41258_wti_monthly_energy_distance_shift_trend_g0.md: R1 passes through one durable AI source, a complete governed peer-reviewed WTI packet, complete pinned primary statistical software, and an explicit policy boundary; R2 locks data, distance arithmetic, enumeration, boundary, side, attempt, risk, stop, spread, and lifecycle; R3 uses registered native WTI D1 with continuous-CFD risk; R4 uses deterministic native arithmetic only. Corrected-root dedup found no exact identity across 4,757 registry rows, 1,394 cards, and 45 Wiki nodes; fixed fixtures separate integrated ECDF, MAD scale, and median-score neighbors."
---

# QM5_41258 WTI Exact-Permutation Energy-Distance Shift Trend

## Hypothesis

WTI's physical supply, storage, transport, refining, hedging, geopolitical, and
demand shocks can change the location, scale, or shape of monthly returns.
When the newest six completed returns are sufficiently displaced from the
prior six under the two-sample energy distance, continue the direction of the
block-median shift for one monthly package.

This is an untested direct-crude structural-trend hypothesis. Q02 owns
activity and economics; later gates own robustness; unchanged Q09 alone owns
overlap.

## Source traceability and claim boundary

The single source is
`strategy-seeds/sources/AI-CODEX-WTI-MENERGY-20260901/source.md`, approved at
commit `3e056abc48` before extraction. The peer-reviewed WTI record supports
only carrier, monthly cadence, and own-return continuation. Pinned CRAN method
evidence supports only the distance formula and resampling context. The exact
split, exhaustive tail, 60% activity boundary, CFD translation, risk, and
lifecycle are pre-result QM choices.

The Wiley method review was policy-deferred. No inaccessible text, critical
value, empirical result, or efficacy claim transfers.

## Non-duplicate boundary

The canonical receipt
`artifacts/qm5_wti_menergy_shift_tr_preallocation_dedup_20260901.json` found no
exact identity. Energy distance uses actual return magnitudes and all cross-
and within-block absolute distances. `QM5_41255` uses only a pooled rank path,
`QM5_41250` only within-block MAD scale, and `QM5_41257` only an upper-half
label count.

Two fixed fixtures give both disagreement directions against the closest
integrated-ECDF neighbor: linear pooled values with recent ranks
`{0,1,3,5,8,10}` qualify energy at tail 540 while that neighbor stays out;
squared pooled values with recent ranks `{0,1,2,6,8,10}` produce energy tail
636 while the neighbor qualifies. The methods are not aliases.

Verdict:
`DISTINCT_WTI_MONTHLY_FIXED_SIX_BY_SIX_RETURN_ENERGY_DISTANCE_EXACT_924_LABEL_PERMUTATION_THREE_FIFTHS_TAIL_MEDIAN_DIRECTION_CONTINUATION`.

## Rules

### Market, clock, and data

- Host and trade exact `XTIUSD.DWX`, D1, slot 0, magic `412580000`.
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

mean_distance(A,B) = sum(abs(a-b) for every ordered a in A, b in B) / 36
M_cross  = mean_distance(old,recent)
M_old    = mean_distance(old,old)       # includes six zero self-distances
M_recent = mean_distance(recent,recent) # includes six zero self-distances
E_observed = 3 * (2*M_cross - M_old - M_recent)

tail_count = 0; assignment_count = 0
for each 12-bit mask having exactly six set bits:
    pseudo_recent = values selected by mask
    pseudo_old = complement
    E_perm = the same energy formula
    if E_perm + 1e-12*max(1,abs(E_observed)) >= E_observed:
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

All closes, returns, distances, sums, statistics, medians, and comparisons
must be finite. An invalid enumeration, excessive tail, or zero median
direction consumes the month flat. Statistic magnitude never scales risk.

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
exposure, same-month deal, invalid distance arithmetic or enumeration,
excessive tail, neutral direction, crossed quote, excessive spread, invalid
ATR/stop metadata, or nonpositive fixed-risk size.

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
| `strategy_energy_epsilon` | 1e-12 | locked |
| `strategy_direction_epsilon` | 1e-12 | locked |
| `strategy_history_bars` | 900 | locked |
| `strategy_entry_grace_minutes` | 180 | locked |
| `strategy_endpoint_stale_days` | 10 | locked |
| `strategy_atr_period` | 20 | locked |
| `strategy_atr_sl_mult` | 3.5 | locked |
| `strategy_stale_days` | 40 | locked |
| `strategy_max_spread_points` | 1500 | locked |

Changing the sample, statistic, distance definition, tolerance, tail,
direction, risk, stop, or hold after Q02 is forbidden.

## Reputable-source criteria

| gate | verdict | evidence |
|---|---|---|
| R1 | PASS_WITH_AI_SYNTHESIS_AND_PINNED_PRIMARY_SOFTWARE | One AI source, complete-read WTI support, pinned CRAN method evidence, explicit policy boundary. |
| R2 | PASS | Exact clock, data, distance formula, enumeration, side, risk, and lifecycle. |
| R3 | PASS | Native registered WTI D1 and MT5 state; CFD risks disclosed. |
| R4 | PASS | Deterministic native arithmetic; no trained or prohibited runtime signal. |

## Risk and kill criteria

- Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- Retire on zero positions, fewer than five in any full scored year,
  nonpositive governed economics, or failed fixture.
- Fail current-month leakage, wrong return orientation, omitted self-distance,
  wrong factor three, wrong assignment count, tolerance, tail cap, side,
  missing stop, wrong risk mode, retry, or nondeterminism.
- Q09 alone can establish realized correlation; no waiver is granted.

## Framework alignment

- no_trade: exact identity, fixed-risk mode, month/attempt/history/distance
  state, position/deal, spread, quote, ATR, stop, and sizing guards.
- trade_entry: cached qualified energy-distance direction, one fixed-risk WTI
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
| v1 | 2026-09-01 | initial exact-permutation energy-distance WTI card | G0 | APPROVED |

## Pipeline phase status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 | 2026-09-01 | APPROVED; R1-R4 PASS | source approval, dedup, card |
| Q01 | - | NOT_BUILT | pending magic allocation and implementation |
| Q02 | - | NOT_ENQUEUED_Q01_PENDING | enqueue after strict Q01 and CPU admission |
