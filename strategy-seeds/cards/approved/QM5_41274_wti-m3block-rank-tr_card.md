---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-WTI-M3BLOCK-RANK-TREND-20260901_S01
variant_id: AI-CODEX-WTI-M3BLOCK-RANK-TREND-20260901_S01
source_id: AI-CODEX-WTI-M3BLOCK-RANK-TREND-20260901
ea_id: QM5_41274
slug: wti-m3block-rank-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41274_wti-m3block-rank-tr_card.md
execution_contract_status: APPROVED
created: 2026-09-01
created_by: Research+Development
last_updated: 2026-09-01
g0_status: APPROVED
g0_decision: decisions/2026-09-01_qm5_41274_wti_monthly_three_block_rank_trend_g0.md
source_approval: decisions/2026-09-01_wti_monthly_three_block_rank_trend_source_approval.md
source_author: "OpenAI Codex"
source_authors: "OpenAI Codex; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "OpenAI Codex (2026), WTI completed-month three-block ordinal close trend continuation; supporting record Moskowitz, Ooi, and Pedersen (2012), Journal of Financial Economics 104(2), DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: ai_originated_governed_source
    citation: "OpenAI Codex (2026). WTI completed-month three-block ordinal close trend continuation."
    location: "strategy-seeds/sources/AI-CODEX-WTI-M3BLOCK-RANK-TREND-20260901/source.md"
    quality_tier: governed_source
    role: exact_trading_hypothesis_formula_activity_boundary_risk_and_lifecycle
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: monthly_own_return_continuation_and_explicit_wti_membership_only
strategy_mechanic: monthly-wti-last15-completed-daily-closes-three-chronological-five-session-blocks-all-75-cross-block-ordered-pair-comparisons-midpoint-direction-next-month-continuation
sources:
  - "[[sources/AI-CODEX-WTI-M3BLOCK-RANK-TREND-20260901]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/three-block-ordinal-dominance]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-daily-close-order]]"
  - "[[indicators/cross-block-ordinal-win-count]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, ordinal-price-path, three-block-order, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
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
magic: 412740000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately 10-12 completed WTI positions per full post-warm-up year; one consumed attempt per broker month and every valid strict-order state has a side. Q02 must establish at least five completed positions per full year or retire."
expected_trades_per_year_per_symbol: 11
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_AI_MECHANIZATION_AND_CONTINUOUS_CFD_TRANSLATION_RISK
r1_reasoning: "Complete-read peer-reviewed WTI monthly continuation evidence; exact daily-close ordinal conjunction disclosed as untested QM synthesis."
r2_mechanical: PASS
r2_reasoning: "Month clock, sessions, final-fifteen selection, fixed blocks, ties, 75 comparisons, midpoint, side, attempt, risk, stop, spread, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_reasoning: "Registered native XTIUSD.DWX D1 history and MT5 state supply every runtime input; roll, basis, financing, gap, and broker-label risks remain."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed closes, comparisons, integer counts, ATR risk, quotes, positions, deals, and persistent state; no trained output or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: immediately completed broker month with 17-23 D1 sessions; final 15 chronological closes; 3 fixed blocks of 5; pairwise close difference above 0.5 point; all 75 cross-block comparisons; long at 2W>75, short at 2W<75; 120 D1 history bars; 180-minute month-entry grace; ATR(20)*3.5 frozen stop; 40-day stale exit; 1500-point spread ceiling."
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
review_focus: "Falsify a direct-WTI completed-month ordinal path sleeve outside the certified XAU/SP500/NDX/XNG book. Verify month/session membership, final fifteen closes, fixed 5/5/5 blocks, half-point tie rule, all 75 comparisons, strict midpoint side, consumed month, fixed risk, frozen stop, and next-month lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_tradable_month_bar, immediately_completed_month_only, bounded_month_session_count, final_fifteen_daily_closes, no_current_month_price, fixed_three_blocks, pairwise_close_tie_rejection, all_75_cross_block_comparisons, strict_midpoint_direction, monthly_attempt_state, risk_mode_dual, hard_stop_present, friday_close_disabled, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-09-01 and decisions/2026-09-01_qm5_41274_wti_monthly_three_block_rank_trend_g0.md: R1 uses complete-read peer-reviewed WTI evidence with disclosed QM translation; R2 locks clock, data, arithmetic, side, attempt, risk, stop, spread, and lifecycle; R3 uses registered native WTI D1 with continuous-CFD risk; R4 uses deterministic native arithmetic only. Corrected-root dedup found no exact identity across 4,773 registry rows, 1,409 cards, and 45 Wiki nodes; fixed vectors distinguish the only naming-driven fuzzy neighbor and the closest three-block/endpoint systems."
---

# QM5_41274 WTI Completed-Month Three-Block Ordinal Trend

## Hypothesis

When the final fifteen WTI daily closes of a completed broker month show
ordinal upward or downward migration across three chronological five-session
blocks, continue that path direction for the next broker month. The score
uses every earlier-block/later-block close comparison and ignores metric move
magnitude.

This is an untested direct-crude structural-trend hypothesis. WTI adds a
physical-energy carrier absent from the stated XAU/SP500/NDX/XNG book, but
carrier difference is not a correlation result. Q02 owns activity and
economics; later gates own robustness; unchanged Q09 alone owns overlap.

## Source Traceability And Claim Boundary

The source of record is
`strategy-seeds/sources/AI-CODEX-WTI-M3BLOCK-RANK-TREND-20260901/source.md`,
authorized before extraction by
`decisions/2026-09-01_wti_monthly_three_block_rank_trend_source_approval.md`.
The complete parent-source hash is
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.

Moskowitz, Ooi, and Pedersen document monthly own-return continuation, report
a pooled one-month commodity rule, and include WTI. They do not test a
WTI-only within-month daily-close order score, continuous CFD, fixed-dollar
ATR risk, or the QM book. The exact formula and execution contract below are
pre-result QM synthesis. No source alpha, profit factor, p-value, drawdown,
trade count, cost, CFD equivalence, or decorrelation statistic is imported.

## Non-Duplicate Boundary

The corrected-root canonical receipt
`artifacts/qm5_wti_m3block_rank_tr_preallocation_dedup_20260901.json`, SHA-256
`2CC07EFAA3F1A5618442E1DA8B17E42A24B14B3E3561C12B985AC740E26D828D`,
found no exact identity. Its sole fuzzy hit is naming-driven `QM5_41273`.

- `QM5_41115` votes three cumulative return signs with a parent anchor; this
  card counts 75 close-level comparisons without a parent. With parent 5 and
  closes `[1,2,3,4,10,11,12,13,14,9,15,16,17,18,8]`, this card buys at
  `W=68` while the block-sign vote sells on `+,-,-`.
- `QM5_41111` counts adjacent return signs and requires endpoint agreement;
  this card has neither mechanic.
- `QM5_20264` consumes thirteen monthly endpoints and all 78 pairs; this card
  consumes fifteen within-month D1 closes and 75 cross-block pairs.
- `QM5_41273` ranks twelve absolute monthly-return sizes and gates at
  `|S|>=18`; this card ranks no return magnitude.
- `QM5_20187` follows one endpoint return. Closes `[100..113,99]` buy here at
  `W=65` while the endpoint return is negative.
- `QM5_12567` is a long-only two-day XNG oscillator pullback.

Verdict:
`DISTINCT_WTI_COMPLETED_MONTH_FINAL15_CLOSE_THREE_BLOCK_75_PAIR_ORDINAL_DOMINANCE_CONTINUATION`.

## Rules

### Market, Clock, And Data

- Host and trade exact `XTIUSD.DWX`, D1, slot 0, magic `412740000`.
- Act only within 180 elapsed minutes of the first D1 bar of a genuine new
  broker month. Persist the `yyyymm` attempt before every fallible entry gate.
- Reconstruct only the immediately completed broker month from a bounded
  120-D1 buffer. Require 17 through 23 chronological completed sessions.
- Select its final fifteen closes in chronological order. Exclude every
  current-month price.
- Require positive finite closes and reject any pair whose difference is no
  greater than `0.5 * _Point`.

### Exact Signal

```text
G0 = C[0..4]
G1 = C[5..9]
G2 = C[10..14]

W = 0
N = 0
for a in 0..1:
  for b in a+1..2:
    for x in Ga:
      for y in Gb:
        N += 1
        if y > x: W += 1

require N == 75 and 0 <= W <= 75
BUY  if 2*W > 75
SELL if 2*W < 75
```

The half-point tie rejection makes `2*W==75` impossible. Wrong history,
membership, chronology, session count, close, tie, comparison count, win
count, or side consumes the month flat. Score magnitude never scales risk.

This ordinal score is a deterministic classifier, not a statistical test.
There is no p-value, significance threshold, independence claim, or external
method result.

### Entry Rules

- Reject existing owned exposure or a same-magic current-month entry deal.
- Both news axes, legacy news mode, and Friday close are OFF.
- Reject crossed/negative quotes and a positive spread above 1,500 points.
- Require completed-bar `ATR(20,D1)` and a normalized `3.5*ATR` stop.
- Open at most one market position with `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`, a frozen broker hard stop, and no target.

### Exit And Management Rules

- Close on the first tick in a later normalized broker month.
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
| `strategy_close_count` | 15 | locked |
| `strategy_block_size` | 5 | locked |
| `strategy_comparison_count` | 75 | locked |
| `strategy_center_doubled` | 75 | locked |
| `strategy_tie_points` | 0.5 | locked |
| `strategy_history_bars_d1` | 120 | locked |
| `strategy_entry_window_minutes` | 180 | locked |
| `strategy_atr_period_d1` | 20 | locked |
| `strategy_atr_sl_mult` | 3.5 | locked |
| `strategy_max_hold_days` | 40 | locked |
| `strategy_max_spread_points` | 1500 | locked |
| `strategy_deviation_points` | 20 | locked |

Changing the sample, blocks, tie rule, score, threshold, side, carrier, risk,
stop, spread, or hold after Q02 is forbidden.

## Expected Behaviour And Frequency

There is one consumed attempt per broker month. Every valid strict-order state
has a side because an even doubled win count cannot equal the odd center 75.
The market-free upper bound is twelve qualified states per full year before
history, ties, quote, spread, ATR, sizing, margin, or execution gates. Q02
must establish at least five completed positions in every full post-warm-up
year or retire the candidate.

## Reputable-Source Criteria

| gate | verdict | evidence |
|---|---|---|
| R1 | PASS_WITH_AI_MECHANIZATION_AND_CONTINUOUS_CFD_TRANSLATION_RISK | Complete-read peer-reviewed WTI monthly continuation evidence; exact daily-close rank path disclosed as untested QM synthesis. |
| R2 | PASS | Exact clock, data, blocks, tie rule, 75 comparisons, midpoint, side, attempt, risk, and lifecycle. |
| R3 | PASS | Native registered WTI D1 and MT5 state; roll/basis/financing/gap risks disclosed. |
| R4 | PASS | Deterministic native comparisons and state only; no trained signal or external runtime feed. |

## Risk Model And Kill Criteria

Q02-Q10 use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. This card authorizes no live preset.

Retire on zero positions, fewer than five completed positions in any full
post-warm-up year, nonpositive governed economics, failed deterministic
fixtures, or any downstream gate failure. Fail current-month leakage, wrong
month/session membership, wrong final-fifteen selection, accepted ties,
wrong blocks/comparison count/win count/side, retry, missing stop, wrong risk
mode, late entry, missed exit, or nondeterminism. No result-driven rescue is
authorized.

## Framework Alignment

- `no_trade`: exact identity, carrier, period, risk/news/Friday/input locks,
  month clock, attempt, history, tie, position/deal, quote, spread, ATR, stop,
  and sizing guards.
- `trade_entry`: cached ordinal side, one fixed-risk WTI market order, frozen
  ATR stop, and no target.
- `trade_management`: malformed-position, next-month, and forty-day repair.
- `trade_close`: framework close helper, broker hard stop, and kill switch.

## Validation Plan

1. Card schema lint and forbidden-token scan.
2. Canonical dedup receipt plus functional-neighbor fixtures.
3. Pure reference checks for month membership, final-fifteen orientation,
   ties, 5/5/5 blocks, all 75 comparisons, midpoint sides, and counterexamples.
4. Strict MQL5 compile and framework build check.
5. Canonical `RISK_FIXED` XTIUSD D1 backtest set only.
6. One paced Q02 enqueue if the whole-host CPU admission allows it; no manual
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
| G0 | 2026-09-01 | APPROVED; R1-R4 PASS | source approval, dedup, card decision |
| Q01 | - | NOT_BUILT | pending governed allocation and implementation |
| Q02 | - | NOT_ENQUEUED_Q01_PENDING | enqueue only after strict Q01 and CPU admission |

## Revision History

| version | date | reason | phase | verdict |
|---|---|---|---|---|
| v1 | 2026-09-01 | initial WTI three-block ordinal trend card | G0 | APPROVED |
