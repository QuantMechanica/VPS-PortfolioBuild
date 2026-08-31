---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-WTI-CSSVOLSHIFT-20260831_S01
variant_id: AI-CODEX-WTI-CSSVOLSHIFT-20260831_S01
source_id: AI-CODEX-WTI-CSSVOLSHIFT-20260831
ea_id: QM5_41252
slug: wti-css-volshift-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41252_wti-css-volshift-tr_card.md
execution_contract_status: APPROVED
created: 2026-08-31
created_by: Research+Development
last_updated: 2026-08-31
g0_status: APPROVED
g0_decision: decisions/2026-08-31_qm5_41252_wti_css_variance_shift_trend_g0.md
source_approval: decisions/2026-08-31_wti_css_variance_shift_trend_source_approval.md
source_author: "OpenAI Codex"
source_authors: "OpenAI Codex; Carla Inclan; George C. Tiao; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "OpenAI Codex (2026), WTI monthly centered-sum-of-squares variance-shift continuation; supporting records Inclan and Tiao (1994), JASA 89(427), DOI 10.1080/01621459.1994.10476824, and Moskowitz, Ooi, and Pedersen (2012), JFE 104(2), DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: ai_originated_governed_source
    citation: "OpenAI Codex (2026). WTI monthly centered-sum-of-squares variance-shift continuation."
    location: "strategy-seeds/sources/AI-CODEX-WTI-CSSVOLSHIFT-20260831/source.md"
    quality_tier: governed_source
    role: exact_trading_hypothesis_formula_thresholds_risk_and_lifecycle
  - type: peer_reviewed_statistical_paper
    citation: "Inclan, C. and Tiao, G. C. (1994). Use of Cumulative Sums of Squares for Retrospective Detection of Changes of Variance. Journal of the American Statistical Association 89(427), 913-923."
    location: "DOI 10.1080/01621459.1994.10476824; complete-read evidence strategy-seeds/sources/AI-CODEX-WTI-CSSVOLSHIFT-20260831/retrieval_route_20260831.json"
    quality_tier: A
    role: centered_cumulative_sum_of_squares_variance_change_statistic_and_finite_sample_quantiles
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: monthly_own_return_continuation_and_explicit_wti_membership
strategy_mechanic: monthly-wti-252-completed-d1-log-returns-one-pass-centered-cumulative-sum-of-squares-dominant-variance-change-score-above-063-post-break-return-sign-continuation
sources:
  - "[[sources/AI-CODEX-WTI-CSSVOLSHIFT-20260831]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/variance-change-point]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-d1-log-return]]"
  - "[[indicators/centered-cumulative-sum-of-squares]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, variance-change-point, cumulative-sum-of-squares, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
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
magic: 412520000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately 7-10 completed WTI positions per full post-warm-up year; one consumed attempt per broker month. Q02 must prove at least five in every full scored year or retire."
expected_trades_per_year_per_symbol: 7
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_AI_SYNTHESIS_BOUNDARY
r1_reasoning: "One durable AI-originated source ID, a complete-read peer-reviewed variance-change paper, and complete-read peer-reviewed WTI momentum evidence; exact trading conjunction disclosed as an untested QM synthesis."
r2_mechanical: PASS
r2_reasoning: "Month clock, D1 window, returns, centering, squares, cumulative path, interior splits, normalization, tie rule, threshold, post-shift side, attempt, risk, stop, spread, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_reasoning: "Registered native XTIUSD.DWX D1 and MT5 state supply every runtime input; continuous-CFD roll, basis, financing, gap, and broker-month-label risks remain."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, finite arithmetic, squares, cumulative sums, comparisons, ATR risk, quote, position, deal, and persistent state; no trained output or prohibited runtime feed."
parameters_to_test: "Locked Q02 baseline only: 253 completed D1 closes; 252 adjacent log returns; full-window arithmetic-mean centering; squared centered returns; centered cumulative sum of squares; split search 21..231; sqrt(252/2) normalization; latest exact-tie selection; inclusive score threshold 0.63; total-square epsilon 1e-16; post-shift raw-return direction epsilon 1e-12; 500 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 frozen stop; 40-day stale exit; 1500-point spread ceiling."
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
review_focus: "Falsify a direct-WTI monthly variance-shift trend sleeve outside the certified XAU/SP500/NDX/XNG book. Verify completed D1 history, return orientation, mean centering, square path, CSS score, interior split and latest-tie rule, 0.63 boundary, post-shift return side, consumed month, fixed risk, frozen stop, and next-month lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_tradable_month_bar, 253_completed_d1_closes, no_current_bar_price, 252_adjacent_log_returns, full_window_mean_center, centered_square_path, split_21_231, sqrt_t_over_2_normalization, latest_exact_tie, inclusive_063_boundary, post_shift_raw_return_direction, monthly_attempt_state, risk_mode_dual, hard_stop_present, friday_close_disabled, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-31 and decisions/2026-08-31_qm5_41252_wti_css_variance_shift_trend_g0.md: R1 passes with one durable AI source, complete-read peer-reviewed variance-change and WTI evidence, and explicit synthesis boundary; R2 locks data, CSS arithmetic, split, tie, threshold, side, attempt, risk, stop, spread, and lifecycle; R3 uses registered native WTI D1 with continuous-CFD risk; R4 uses deterministic native arithmetic only. Corrected-root canonical dedup found no exact or fuzzy identity across 4,751 registry rows, 1,389 cards, and 45 Wiki nodes; manual review separates monthly mean-CUSUM, permutation-MAD, volatility-of-volatility rank, and certified-XNG families."
---

# QM5_41252 WTI Centered-Sum-of-Squares Variance-Shift Trend

## Hypothesis

WTI has physical supply, production, storage, transport, refining, hedging,
investment, geopolitical, and demand drivers absent from the certified
XAU/SP500/NDX/XNG carrier set. Those forces can create discrete changes in
daily return variance. A dominant variance shift over the completed trading
year may identify a new information regime; the raw cumulative return after
that shift may continue for one monthly package.

This is a direct-crude structural-trend hypothesis, not evidence of
profitability or decorrelation. Q02 owns activity and baseline economics;
later gates own robustness; unchanged Q09 alone owns portfolio overlap.

## Source traceability and claim boundary

The single governed source ID resolves to
`strategy-seeds/sources/AI-CODEX-WTI-CSSVOLSHIFT-20260831/source.md`, authorized
by `decisions/2026-08-31_wti_css_variance_shift_trend_source_approval.md` at
commit `ccd9946d05` before extraction. Its reproducible read evidence is
`strategy-seeds/sources/AI-CODEX-WTI-CSSVOLSHIFT-20260831/retrieval_route_20260831.json`.

Inclan and Tiao (1994) supply the centered cumulative-sum-of-squares variance-
change statistic, its normalization, and finite-sample quantiles. Moskowitz,
Ooi, and Pedersen (2012) supply complete-read peer-reviewed monthly own-return
continuation evidence and explicit WTI membership. Neither source tests this
exact conjunction, continuous CFD, 252-D1 rolling use, interior guard,
`0.63` activity boundary, fixed risk, stop, or lifecycle. No source
performance, significance, density, cost, CFD-equivalence, correlation, or
portfolio statistic transfers.

## Non-duplicate boundary

The corrected-root pre-allocation checker found no exact or fuzzy identity
across 4,751 EA registry identities, 1,389 card files, and 45 Strategy Wiki
nodes. Receipt:
`artifacts/qm5_wti_css_volshift_tr_preallocation_dedup_20260831.json`.

The load-bearing differences are:

- mean-CUSUM `QM5_41245` accumulates centered monthly return levels and trades
  the post-split mean. This card accumulates squared centered daily returns
  to locate a variance shift and uses a separate post-shift raw return.
- permutation-MAD `QM5_41250` fixes old/recent monthly blocks and enumerates
  label assignments. This card retains the order of 252 daily returns,
  searches an interior split, and performs no permutation.
- VoV-regime `QM5_20298` ranks a monthly volatility-of-volatility measure.
  This card uses no volatility rank or fixed old/recent volatility blocks.
- certified `QM5_12567` is a long-only XNG cumulative-RSI pullback; this card
  is symmetric monthly WTI and contains no oscillator.

Verdict:
`DISTINCT_WTI_MONTHLY_252_D1_CENTERED_CUMULATIVE_SQUARES_DOMINANT_INTERIOR_VARIANCE_SHIFT_POST_BREAK_RETURN_CONTINUATION`.

## Rules

### Market, clock, and data

- Host and trade exact `XTIUSD.DWX` on D1, slot 0, magic `412520000`.
- Run only on the first executable D1 tick after a genuine normalized broker-
  month transition and within 180 elapsed minutes of raw current-bar open.
- Persist the new `yyyymm` attempt before every fallible entry gate. A
  restart, stop-out, invalid signal, or order failure never permits a same-
  month retry.
- Reconstruct exactly 253 immediately prior completed D1 closes, oldest to
  newest, from a bounded 500-D1 buffer.
- Exclude the current D1 bar. Require positive finite closes, strict
  chronology, and a newest completed bar no more than ten calendar days before
  the current month bar.

### Exact signal

For chronological completed D1 closes `P[0..252]`:

```text
T = 252
for i = 0..251:
    r[i] = log(P[i+1] / P[i])

mean_r = sum(r) / T
for i = 0..251:
    a[i] = r[i] - mean_r
    q[i] = a[i] * a[i]

C_T = sum(q)
require C_T > 1e-16

running = 0
for i = 0..251:
    running += q[i]
    if 21 <= i+1 <= 231:
        k = i+1
        D_k = running / C_T - k / T
        M_k = sqrt(T / 2) * abs(D_k)
        retain the largest M_k; an exact tie retains the larger k

require max_M >= 0.63
post_return = sum(r[i] for i = selected_k..251)

BUY  iff post_return >  1e-12
SELL iff post_return < -1e-12
FLAT otherwise
```

Every close, logarithm, return, mean, centered return, square, cumulative sum,
ratio, score, and post-shift return must be finite. Invalid total square, an
interior maximum below `0.63`, or a zero direction consumes the month flat.
The score never scales risk. The boundary is a source-table activity quantile,
not a significance test.

## 4. Entry Rules

- Reject an owned position or a same-magic entry deal already present for the
  current normalized broker month.
- Both news axes and legacy news mode are OFF. Friday close is OFF.
- Reject crossed or negative quotes and a genuinely positive spread above
  1,500 points. A modeled zero `.DWX` spread remains valid.
- Require valid completed-bar `ATR(20,D1)`, valid point/tick metadata, and a
  normalized stop distance of `3.5 * ATR`.
- Submit at most one market position with `RISK_FIXED=1000`,
  `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, one frozen broker hard stop, and no
  take-profit.

## 5. Exit Rules

- Close on the first tick whose normalized broker month differs from the
  entry month.
- Close after forty elapsed calendar days as stale repair.
- Broker hard stop remains authoritative. There is no target, opposite-
  signal exit, or same-month re-entry.

## 6. Filters (No-Trade Module)

- Fail closed on wrong symbol, timeframe, EA ID, slot, magic, unlocked input,
  risk mode, news mode, Friday-close mode, or stress state.
- Consume the month before history, signal, position, deal, spread, quote,
  ATR, stop, sizing, margin, or order checks.
- Reject malformed/current-bar history, late attachment, an existing owned
  position, a same-month entry deal, invalid CSS arithmetic, a sub-threshold
  score, zero post-shift direction, crossed quotes, excessive spread, invalid
  ATR/stop metadata, or a nonpositive fixed-risk size.

## 7. Trade Management Rules

- Repair malformed owned exposure before entry-only gates: duplicates, wrong
  symbol/magic, invalid volume, missing stop, or invalid open time close.
- Apply no stop modification after entry. There is no trail, break-even,
  partial close, grid, martingale, scale-in, or pyramid.

## Parameters to test

Q02 uses one locked baseline and no optimization surface:

| parameter | default | Q02 status | role |
|---|---:|---|---|
| `strategy_return_count` | 252 | locked | completed adjacent D1 log returns |
| `strategy_split_min` | 21 | locked | minimum observations before shift |
| `strategy_split_max` | 231 | locked | maximum split / minimum 21 after shift |
| `strategy_score_threshold` | `0.63` | locked | inclusive CSS activity boundary |
| `strategy_total_square_epsilon` | `1e-16` | locked | degenerate path guard |
| `strategy_direction_epsilon` | `1e-12` | locked | post-shift return side guard |
| `strategy_history_bars` | 500 | locked | bounded completed-D1 buffer |
| `strategy_entry_grace_minutes` | 180 | locked | first-month-bar entry window |
| `strategy_endpoint_stale_days` | 10 | locked | newest completed D1 age ceiling |
| `strategy_atr_period` | 20 | locked | completed-D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | locked | frozen broker hard-stop multiple |
| `strategy_stale_days` | 40 | locked | survivor repair |
| `strategy_max_spread_points` | 1500 | locked | entry execution ceiling |

Changing the return count, mean convention, square path, split range, tie
rule, threshold, direction, risk, or hold after observing Q02 is forbidden.

## Reputable-source criteria

| gate | verdict | evidence |
|---|---|---|
| R1 | PASS_WITH_AI_SYNTHESIS_BOUNDARY | One durable source ID; complete-read peer-reviewed CSS paper and WTI packet; exact conjunction disclosed as untested. |
| R2 | PASS | Clock, data, centering, squares, path, split, score, side, attempt, risk, stop, spread, and exits are exact. |
| R3 | PASS | Registered native WTI D1 and MT5 state only; roll/basis/financing/gap risks disclosed. |
| R4 | PASS | Deterministic native arithmetic only; no trained output, banned signal, external runtime feed, grid, martingale, scale-in, or pyramid. |

## Risk and kill criteria

- Q02 uses exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- WTI gaps, continuous-CFD roll/basis, financing, outlier sensitivity,
  variance-break masking, and month-label offsets are material risks.
- Retire on zero positions, fewer than five completed positions in any full
  post-warm-up year, nonpositive governed economics, or a failed deterministic
  fixture.
- Fail on current-bar leakage, wrong close or return order, wrong mean center,
  wrong square/cumulative path, wrong normalization, wrong split or latest-tie
  selection, wrong inclusive `0.63` boundary, wrong post-shift direction,
  missing stop, wrong risk mode, same-month retry, or nondeterminism.
- Q09 alone may establish realized portfolio correlation. This card grants no
  correlation waiver or portfolio admission.

## Framework alignment

- no_trade: exact host/timeframe/ID/slot, locked inputs, fixed-risk mode,
  month grace, persistent attempt, completed-history integrity, CSS signal
  integrity, position/deal, spread, quote, ATR, stop, and sizing guards.
- trade_entry: cached CSS-qualified post-shift direction, one fixed-risk WTI
  order, frozen ATR hard stop, no target.
- trade_management: malformed-position repair, month rollover, and forty-day
  stale repair; no modification logic.
- trade_close: framework close helper, broker hard stop, and deterministic
  lifecycle reason mapping.

## Safety boundary

This card authorizes only one branch build, deterministic reference tests,
strict Q01, one D1 `RISK_FIXED` backtest setfile, and one paced non-live Q02
handoff if the governed CPU ceiling permits. It does not authorize a manual
tester run; live/demo/shadow/stress/optimization setfile; AutoTrading;
`T_Live`; deploy or live manifest; portfolio-gate mutation; portfolio
admission; or correlation waiver.

## Pipeline history

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-31 | initial centered-CSS WTI variance-shift card | G0 | APPROVED; build pending |

## Pipeline phase status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-31 | APPROVED; R1-R4 PASS | source approval, corrected-root dedup receipt, and this card |
| Q01 Build Validation | - | NOT_BUILT | pending magic allocation and exact implementation |
| Q02 Baseline Screening | - | NOT_ENQUEUED_Q01_PENDING | one paced enqueue only after strict Q01 and CPU admission |
