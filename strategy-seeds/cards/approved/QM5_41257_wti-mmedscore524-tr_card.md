---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-WTI-MMEDSCORE524-20260831_S01
variant_id: AI-CODEX-WTI-MMEDSCORE524-20260831_S01
source_id: AI-CODEX-WTI-MMEDSCORE524-20260831
ea_id: QM5_41257
slug: wti-mmedscore524-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41257_wti-mmedscore524-tr_card.md
execution_contract_status: APPROVED
created: 2026-08-31
created_by: Research+Development
last_updated: 2026-08-31
g0_status: APPROVED
g0_decision: decisions/2026-08-31_qm5_41257_wti_monthly_median_score524_trend_g0.md
source_approval: decisions/2026-08-31_wti_monthly_median_score524_trend_source_approval.md
source_author: "OpenAI Codex"
source_authors: "OpenAI Codex; George W. Brown; Alexander M. Mood; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "OpenAI Codex (2026), WTI monthly exact non-neutral median-score continuation; supporting records Brown and Mood (1951), Proceedings of the Second Berkeley Symposium, 159-166, and Moskowitz, Ooi, and Pedersen (2012), JFE 104(2), DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: ai_originated_governed_source
    citation: "OpenAI Codex (2026). WTI monthly exact non-neutral median-score continuation."
    location: "strategy-seeds/sources/AI-CODEX-WTI-MMEDSCORE524-20260831/source.md"
    quality_tier: governed_source
    role: exact_trading_hypothesis_formula_thresholds_risk_and_lifecycle
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: monthly_own_return_continuation_and_explicit_wti_membership_only
  - type: peer_reviewed_method_bibliography
    citation: "Brown, G. W., and Mood, A. M. (1951). On Median Tests for Linear Hypotheses. Proceedings of the Second Berkeley Symposium, 159-166."
    location: "Bibliographic context only; NIST method URL retrieval deferred by strategy-seeds/sources/AI-CODEX-WTI-MMEDSCORE524-20260831/retrieval_route_20260831.json"
    quality_tier: A
    role: bibliographic_naming_context_only_no_content_or_significance_claim_transferred
strategy_mechanic: monthly-wti-twelve-completed-log-returns-fixed-six-old-six-recent-pooled-grand-median-score-exact-hypergeometric-nonneutral-four-of-six-location-shift-continuation
sources:
  - "[[sources/AI-CODEX-WTI-MMEDSCORE524-20260831]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/nonparametric-location-shift]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-log-return]]"
  - "[[indicators/pooled-grand-median-score]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, location-shift, median-score, exact-label-enumeration, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
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
magic: 412570000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately 6-7 completed WTI positions per full post-warm-up year; one consumed attempt per broker month. Exact strict-rank qualification is 524/924, about 6.805 decisions/year before downstream market gates."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_AI_SYNTHESIS_AND_POLICY_BOUNDARY
r1_reasoning: "One durable AI-originated source ID and prompt/output trail; complete-read peer-reviewed WTI evidence; policy-deferred method context; exact median-score conjunction disclosed as untested QM synthesis."
r2_mechanical: PASS
r2_reasoning: "Month clock, endpoints, returns, fixed blocks, ties, pooled order, upper-half count, all 924 assignments, inclusive 524 boundary, side, attempt, risk, stop, spread, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_reasoning: "Registered native XTIUSD.DWX D1 history and MT5 state supply every runtime input; continuous-CFD roll, basis, financing, gap, and broker-month-label risks remain."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, finite sorting, integer rank counts, deterministic enumeration, comparisons, ATR risk, quotes, positions, deals, and persistent state; no trained output, prohibited signal indicator, or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: 13 consecutive completed month-end closes; 12 adjacent log returns; fixed old/recent blocks of 6; pairwise-distinct pooled returns; recent count in pooled ranks 7..12; all 924 six-label assignments; inclusive exact tail count at most 524; long at H>=4, short at H<=2; 900 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 frozen stop; 40-day stale exit; 1500-point spread ceiling."
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
review_focus: "Falsify a direct-WTI monthly location-shift sleeve outside the certified XAU/SP500/NDX/XNG book. Verify endpoints, return orientation, fixed labels, strict ties, pooled upper-half count, all 924 assignments, tail cap 524, exact side, consumed month, fixed risk, frozen stop, and next-month lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_tradable_month_bar, thirteen_consecutive_completed_months, no_current_month_price, twelve_adjacent_log_returns, fixed_six_old_six_recent_membership, pairwise_distinct_returns, pooled_grand_median_score, exact_924_label_assignments, inclusive_tail_count_524, nonneutral_recent_count_four_or_two, monthly_attempt_state, risk_mode_dual, hard_stop_present, friday_close_disabled, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-31 and decisions/2026-08-31_qm5_41257_wti_monthly_median_score524_trend_g0.md: R1 passes through one durable AI source, a complete governed peer-reviewed WTI packet, and explicit policy boundary; R2 locks data, arithmetic, enumeration, boundary, side, attempt, risk, stop, spread, and lifecycle; R3 uses registered native WTI D1 with continuous-CFD risk; R4 uses deterministic native arithmetic only. Corrected-root dedup found no exact identity across 4,756 registry rows, 1,393 cards, and 45 Wiki nodes; manual review separates integrated ECDF, MAD scale, continuous median-difference, and Mann-Whitney families."
---

# QM5_41257 WTI Exact Non-Neutral Median-Score Trend

## Hypothesis

WTI's physical supply, storage, transport, refining, hedging, geopolitical, and
demand shocks can shift the center of monthly returns. When the newest six
completed returns have a non-neutral majority in the upper or lower half of
the pooled old-versus-new sample, continue that direction for one month.

This is an untested direct-crude structural-trend hypothesis. Q02 owns activity
and economics; later gates own robustness; unchanged Q09 alone owns overlap.

## Source traceability and claim boundary

The single source is
`strategy-seeds/sources/AI-CODEX-WTI-MMEDSCORE524-20260831/source.md`, approved
at commit `a83d108fb9` before extraction. The peer-reviewed WTI record supports
only carrier, monthly cadence, and own-return continuation. Method references
are bibliographic context with policy-deferred content. The score, boundary,
CFD translation, risk, and lifecycle are pre-result QM choices.

The exact `524/924 * 12 = 6.805` activity prior was computed before market
testing. Retired `QM5_41256` documents why the stricter 74/924 source was
stopped before a card or build.

## Non-duplicate boundary

The canonical receipt
`artifacts/qm5_wti_mmedscore524_tr_preallocation_dedup_20260831.json` found no
exact identity. This card uses only the pooled upper-half recent count, unlike
the full integrated ECDF path (`QM5_41255`), within-block MAD scale
(`QM5_41250`), any nonzero continuous median difference (`QM5_41137`), or all
36 cross-block wins (`QM5_41176`). Retired unbuilt `QM5_41256` has the distinct
5-of-6/tail-74 contract.

Verdict:
`DISTINCT_WTI_MONTHLY_FIXED_SIX_BY_SIX_RETURN_POOLED_GRAND_MEDIAN_SCORE_EXACT_924_TAIL524_NONNEUTRAL_LOCATION_SHIFT_CONTINUATION`.

## Rules

### Market, clock, and data

- Host and trade exact `XTIUSD.DWX`, D1, slot 0, magic `412570000`.
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
require all twelve returns finite and pairwise distinct

sort pooled returns ascending with labels retained
H = count of actual recent labels in pooled ranks 7..12

tail_count = 0; assignment_count = 0
for each 12-bit mask with exactly six set bits:
    H_perm = set bits in ranks 7..12
    if abs(H_perm-3) >= abs(H-3): tail_count++
    assignment_count++

require assignment_count == 924
require tail_count <= 524
BUY if H >= 4; SELL if H <= 2; FLAT if H == 3
```

A tie, wrong enumeration, excessive tail, or neutral `H` consumes the month
flat. Count or tail magnitude never scales risk.

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
exposure, same-month deal, pooled tie, invalid enumeration, crossed quote,
excessive spread, invalid ATR/stop metadata, or nonpositive fixed-risk size.

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
| `strategy_tail_count_max` | 524 | locked |
| `strategy_recent_high_long_min` | 4 | locked |
| `strategy_recent_high_short_max` | 2 | locked |
| `strategy_history_bars` | 900 | locked |
| `strategy_entry_grace_minutes` | 180 | locked |
| `strategy_endpoint_stale_days` | 10 | locked |
| `strategy_atr_period` | 20 | locked |
| `strategy_atr_sl_mult` | 3.5 | locked |
| `strategy_stale_days` | 40 | locked |
| `strategy_max_spread_points` | 1500 | locked |

Changing the sample, split, score, boundary, direction, risk, stop, or hold
after Q02 is forbidden.

## Reputable-source criteria

| gate | verdict | evidence |
|---|---|---|
| R1 | PASS_WITH_AI_SYNTHESIS_AND_POLICY_BOUNDARY | One AI source, complete-read WTI support, explicit method-policy boundary. |
| R2 | PASS | Exact clock, data, score, enumeration, side, risk, and lifecycle. |
| R3 | PASS | Native registered WTI D1 and MT5 state; CFD risks disclosed. |
| R4 | PASS | Deterministic native arithmetic; no trained or prohibited runtime signal. |

## Risk and kill criteria

- Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- Retire on zero positions, fewer than five completed positions in any full
  post-warm-up year, nonpositive governed economics, or failed fixture.
- Fail current-month leakage, wrong months/returns/labels, accepted ties,
  wrong `H`, assignment count other than 924, wrong tail cap 524, wrong side,
  missing stop, wrong risk mode, retry, or nondeterminism.
- Q09 alone can establish realized correlation; no waiver is granted.

## Framework alignment

- no_trade: exact identity, fixed-risk mode, month/attempt/history/rank state,
  position/deal, spread, quote, ATR, stop, and sizing guards.
- trade_entry: cached non-neutral median-score direction, one fixed-risk WTI
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
| v1 | 2026-08-31 | initial non-neutral median-score WTI card | G0 | APPROVED |

## Pipeline phase status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 | 2026-08-31 | APPROVED; R1-R4 PASS | source approval, dedup, card |
| Q01 | - | NOT_BUILT | pending magic allocation and implementation |
| Q02 | - | NOT_ENQUEUED_Q01_PENDING | enqueue after strict Q01 and CPU admission |
