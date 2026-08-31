---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-WTI-CHOWBREAK-20260831_S01
variant_id: AI-CODEX-WTI-CHOWBREAK-20260831_S01
source_id: AI-CODEX-WTI-CHOWBREAK-20260831
ea_id: QM5_41254
slug: wti-chow-break-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41254_wti-chow-break-tr_card.md
execution_contract_status: APPROVED
created: 2026-08-31
created_by: Research+Development
last_updated: 2026-08-31
g0_status: APPROVED
g0_decision: decisions/2026-08-31_qm5_41254_wti_chow_break_trend_g0.md
source_approval: decisions/2026-08-31_wti_chow_break_trend_source_approval.md
source_author: "OpenAI Codex"
source_authors: "OpenAI Codex; Gregory C. Chow; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "OpenAI Codex (2026), WTI monthly scanned two-regression structural-break continuation; supporting records Chow (1960), Econometrica 28(3), DOI 10.2307/1910133, and Moskowitz, Ooi, and Pedersen (2012), JFE 104(2), DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: ai_originated_governed_source
    citation: "OpenAI Codex (2026). WTI monthly scanned two-regression structural-break continuation."
    location: "strategy-seeds/sources/AI-CODEX-WTI-CHOWBREAK-20260831/source.md"
    quality_tier: governed_source
    role: exact_trading_hypothesis_formula_thresholds_risk_and_lifecycle
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: monthly_own_return_continuation_and_explicit_wti_membership_only
  - type: peer_reviewed_method_bibliography
    citation: "Chow, G. C. (1960). Tests of Equality Between Sets of Coefficients in Two Linear Regressions. Econometrica 28(3), 591-605."
    location: "DOI 10.2307/1910133; content retrieval deferred by strategy-seeds/sources/AI-CODEX-WTI-CHOWBREAK-20260831/retrieval_route_20260831.json"
    quality_tier: A
    role: bibliographic_naming_context_only_no_content_or_significance_claim_transferred
strategy_mechanic: monthly-wti-252-completed-d1-log-price-pooled-versus-two-segment-ols-chow-f-scan-interior-splits-63-189-latest-max-tie-inclusive-f3-post-break-slope-continuation
sources:
  - "[[sources/AI-CODEX-WTI-CHOWBREAK-20260831]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/structural-break]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-d1-log-price]]"
  - "[[indicators/two-segment-ols-rss-score]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, regression-break, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
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
magic: 412540000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately 8-12 completed WTI positions per full post-warm-up year; one consumed attempt per broker month. Q02 must prove at least five in every full scored year or retire."
expected_trades_per_year_per_symbol: 8
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_AI_SYNTHESIS_AND_POLICY_BOUNDARY
r1_reasoning: "One durable AI-originated source ID and prompt/output trail; complete-read peer-reviewed WTI evidence supports only carrier/cadence/direction; the inaccessible method citation is explicitly bounded and transfers no result."
r2_mechanical: PASS
r2_reasoning: "Month clock, completed-D1 window, log transform, pooled and split OLS arithmetic, split range, score, tolerance, tie, threshold, post-break side, attempt, risk, stop, spread, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_reasoning: "Registered native XTIUSD.DWX D1 history and MT5 state supply every runtime input; continuous-CFD roll, basis, financing, gap, and broker-month-label risks remain."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, finite arithmetic, OLS sums, comparisons, ATR risk, quotes, positions, deals, and persistent state; no trained output, banned signal indicator, or prohibited runtime feed."
parameters_to_test: "Locked Q02 baseline only: 252 completed D1 closes/log prices; pooled intercept+slope OLS; two-segment OLS split scan k=63..189; F=((RSS0-RSSk)/2)/(RSSk/248); latest exact-tie selection; inclusive activity threshold 3.0; RSS epsilon 1e-16; negative-improvement relative tolerance 1e-12; post-break slope epsilon 1e-12; 500 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 frozen stop; 40-day stale exit; 1500-point spread ceiling."
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
review_focus: "Falsify a direct-WTI monthly structural-break trend sleeve outside the certified XAU/SP500/NDX/XNG carrier set. Verify completed D1 history, log-price orientation, pooled/split OLS and RSS arithmetic, interior scan and latest-tie rule, 3.0 activity boundary, post-break slope side, consumed month, fixed risk, frozen stop, and next-month lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_tradable_month_bar, 252_completed_d1_closes, no_current_bar_price, finite_log_price, pooled_ols, split_ols, split_63_189, chow_style_rss_score, negative_improvement_tolerance, latest_exact_tie, inclusive_f3_boundary, post_break_slope_direction, monthly_attempt_state, risk_mode_dual, hard_stop_present, friday_close_disabled, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-31 and decisions/2026-08-31_qm5_41254_wti_chow_break_trend_g0.md: R1 passes through one durable AI source, a complete governed peer-reviewed WTI packet, and an explicit policy boundary on the method citation; R2 locks data, OLS/RSS arithmetic, scan, tie, threshold, side, attempt, risk, stop, spread, and lifecycle; R3 uses registered native WTI D1 with continuous-CFD risk; R4 uses deterministic native arithmetic only. Corrected-root canonical dedup found no exact or fuzzy identity across 4,753 registry rows, 1,391 cards, and 45 Wiki nodes; manual review separates one-line OLS, monthly mean-CUSUM, fixed-block Welch, and CSS variance-shift families."
---

# QM5_41254 WTI Scanned Two-Regression Structural-Break Trend

## Hypothesis

WTI has physical supply, production, storage, transport, refining, hedging,
geopolitical, and demand drivers absent from the certified
XAU/SP500/NDX/XNG carrier set. Those forces can change the slope of its
log-price path. When a completed trading-year path is materially better
represented by two linear segments than one, the selected newest segment's
slope may persist for the next monthly package.

This is a direct-crude structural-trend hypothesis, not evidence of
profitability, statistical significance, or decorrelation. Q02 owns activity
and baseline economics; later gates own robustness; unchanged Q09 alone owns
portfolio overlap.

## Source traceability and claim boundary

The single governed source ID resolves to
`strategy-seeds/sources/AI-CODEX-WTI-CHOWBREAK-20260831/source.md`, authorized
by `decisions/2026-08-31_wti_chow_break_trend_source_approval.md` at commit
`08fb72d7bb` before extraction.

The complete governed Moskowitz-Ooi-Pedersen packet supplies WTI membership,
monthly decisions, and own-return continuation only. Chow (1960) is
bibliographic method context; its URL was policy-deferred, so no inaccessible
text, nominal critical value, or empirical result transfers. The exact scan,
threshold, CFD translation, risk, stop, and lifecycle are pre-result QM
choices. Scanning unknown break points and applying regression arithmetic to
serially dependent, potentially heteroskedastic log prices explicitly voids
any nominal F-test significance interpretation.

## Non-duplicate boundary

The corrected-root checker found no exact or fuzzy identity across 4,753 EA
registry rows, 1,391 card files, and 45 Strategy Wiki nodes. Receipt:
`artifacts/qm5_wti_chow_break_tr_preallocation_dedup_20260831.json`.

The load-bearing differences are:

- `QM5_20261_wti-lr-trend` uses one whole-window OLS slope and R-squared;
  this card fits a pooled path and scans every permitted two-segment break.
- `QM5_41245_wti-mcusum-shift-tr` accumulates centered monthly return levels;
  this card compares regression RSS on daily log prices.
- `QM5_41249_wti-mwelch-shift-tr` compares two fixed monthly-return means;
  this card estimates an unknown interior daily intercept/slope break.
- `QM5_41252_wti-css-volshift-tr` scans cumulative squared daily returns for
  a variance shift; this card scans log-price regression instability and
  follows the selected newest slope.
- certified `QM5_12567_cum-rsi2-commodity` is a long-only XNG oscillator
  pullback; this card is symmetric monthly WTI and contains no oscillator.

Verdict:
`DISTINCT_WTI_MONTHLY_252_D1_LOG_PRICE_SCANNED_POOLED_VS_TWO_SEGMENT_OLS_RSS_BREAK_POST_SEGMENT_SLOPE_CONTINUATION`.

## Rules

### Market, clock, and data

- Host and trade exact `XTIUSD.DWX` on D1, slot 0, magic `412540000`.
- Run only on the first executable D1 tick after a genuine normalized broker-
  month transition and within 180 elapsed minutes of raw current-bar open.
- Persist the new `yyyymm` attempt before every fallible entry gate. A
  restart, stop-out, invalid signal, or order failure never permits a same-
  month retry.
- Reconstruct exactly 252 immediately prior completed D1 closes, oldest to
  newest, from a bounded 500-D1 buffer.
- Exclude the current D1 bar. Require positive finite closes, strict
  chronology, and a newest completed bar no more than ten calendar days before
  the current month bar.

### Exact signal

For chronological completed D1 closes `P[0..251]`:

```text
T = 252
for i = 0..251:
    x[i] = i
    y[i] = log(P[i])

fit OLS y = a0 + b0*x over i=0..251
RSS0 = sum((y[i] - a0 - b0*x[i])^2)
require RSS0 > 1e-16

for k = 63..189:
    fit OLS y = a1 + b1*x over i=0..k-1
    fit OLS y = a2 + b2*x over i=k..251
    RSSk = RSS_left + RSS_right
    require RSSk > 1e-16
    improvement = RSS0 - RSSk
    reject if improvement < -1e-12 * max(1, RSS0)
    clamp a smaller negative improvement to zero
    F_k = (improvement / 2) / (RSSk / 248)
    retain the largest finite F_k
    an exact tie retains the larger k and its b2

require max_F >= 3.0

BUY  iff selected_b2 >  1e-12
SELL iff selected_b2 < -1e-12
FLAT otherwise
```

Every close, logarithm, OLS sum, coefficient, residual, RSS, improvement,
score, and slope must be finite. Degenerate regression, an invalid negative
improvement, a score below `3.0`, or a zero recent slope consumes the month
flat. The score never scales risk. The threshold is an activity boundary, not
a significance test.

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
  position, a same-month entry deal, invalid OLS/RSS arithmetic, a sub-
  threshold score, zero recent slope, crossed quotes, excessive spread,
  invalid ATR/stop metadata, or a nonpositive fixed-risk size.

## 7. Trade Management Rules

- Repair malformed owned exposure before entry-only gates: duplicates, wrong
  symbol/magic, invalid volume, missing stop, or invalid open time close.
- Apply no stop modification after entry. There is no trail, break-even,
  partial close, grid, martingale, scale-in, or pyramid.

## Parameters to test

Q02 uses one locked baseline and no optimization surface:

| parameter | default | Q02 status | role |
|---|---:|---|---|
| `strategy_observation_count` | 252 | locked | completed D1 log-price observations |
| `strategy_split_min` | 63 | locked | minimum observations before break |
| `strategy_split_max` | 189 | locked | maximum split / minimum 63 after break |
| `strategy_score_threshold` | `3.0` | locked | inclusive RSS-improvement activity boundary |
| `strategy_rss_epsilon` | `1e-16` | locked | degenerate pooled/split RSS guard |
| `strategy_improvement_tolerance` | `1e-12` | locked | relative negative-improvement round-off guard |
| `strategy_slope_epsilon` | `1e-12` | locked | selected recent-slope side guard |
| `strategy_history_bars` | 500 | locked | bounded completed-D1 buffer |
| `strategy_entry_grace_minutes` | 180 | locked | first-month-bar entry window |
| `strategy_endpoint_stale_days` | 10 | locked | newest completed D1 age ceiling |
| `strategy_atr_period` | 20 | locked | completed-D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | locked | frozen broker hard-stop multiple |
| `strategy_stale_days` | 40 | locked | survivor repair |
| `strategy_max_spread_points` | 1500 | locked | entry execution ceiling |

Changing the observation count, regression model, split range, score formula,
tie rule, threshold, direction, risk, or hold after observing Q02 is forbidden.

## Reputable-source criteria

| gate | verdict | evidence |
|---|---|---|
| R1 | PASS_WITH_AI_SYNTHESIS_AND_POLICY_BOUNDARY | One durable source ID and prompt/output trail; complete-read peer-reviewed WTI evidence; deferred method citation transfers no claim. |
| R2 | PASS | Clock, data, OLS/RSS scan, tie, threshold, side, attempt, risk, stop, spread, and exits are exact. |
| R3 | PASS | Registered native WTI D1 and MT5 state only; roll/basis/financing/gap risks disclosed. |
| R4 | PASS | Deterministic native arithmetic only; no trained output, banned signal, external runtime feed, grid, martingale, scale-in, or pyramid. |

## Risk and kill criteria

- Q02 uses exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- WTI gaps, continuous-CFD roll/basis, financing, path outliers, false break
  selection, serial dependence, heteroskedasticity, and broker-month offsets
  are material risks.
- Retire on zero positions, fewer than five completed positions in any full
  post-warm-up year, nonpositive governed economics, or a failed deterministic
  fixture.
- Fail on current-bar leakage, wrong close/log order, wrong OLS or RSS,
  wrong split or latest-tie selection, wrong improvement tolerance, wrong
  inclusive `3.0` boundary, wrong post-break side, missing stop, wrong risk
  mode, same-month retry, or nondeterminism.
- Q09 alone may establish realized portfolio correlation. This card grants no
  correlation waiver or portfolio admission.

## Framework alignment

- no_trade: exact host/timeframe/ID/slot, locked inputs, fixed-risk mode,
  month grace, persistent attempt, completed-history integrity, regression
  signal integrity, position/deal, spread, quote, ATR, stop, and sizing guards.
- trade_entry: cached structural-break-qualified recent-slope direction, one
  fixed-risk WTI order, frozen ATR hard stop, no target.
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
| v1 | 2026-08-31 | initial scanned two-regression WTI structural-break card | G0 | APPROVED; build pending |

## Pipeline phase status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-31 | APPROVED; R1-R4 PASS | source approval, corrected-root dedup receipt, and this card |
| Q01 Build Validation | - | NOT_BUILT | pending magic allocation and exact implementation |
| Q02 Baseline Screening | - | NOT_ENQUEUED_Q01_PENDING | one paced enqueue only after strict Q01 and CPU admission |
