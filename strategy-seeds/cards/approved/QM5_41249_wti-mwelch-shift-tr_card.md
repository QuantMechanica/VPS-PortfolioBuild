---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-WTI-MWELCH-20260831_S01
variant_id: AI-CODEX-WTI-MWELCH-20260831_S01
source_id: AI-CODEX-WTI-MWELCH-20260831
ea_id: QM5_41249
slug: wti-mwelch-shift-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41249_wti-mwelch-shift-tr_card.md
execution_contract_status: APPROVED
created: 2026-08-31
created_by: Research+Development
last_updated: 2026-08-31
g0_status: APPROVED
g0_decision: decisions/2026-08-31_qm5_41249_wti_monthly_welch_mean_shift_trend_g0.md
source_approval: decisions/2026-08-31_wti_monthly_welch_mean_shift_trend_source_approval.md
source_author: "OpenAI Codex"
source_authors: "OpenAI Codex; B. L. Welch; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; SciPy community"
source_citation: "OpenAI Codex (2026), WTI monthly fixed-block Welch mean-shift continuation; supporting records Welch (1938), Biometrika 29(3-4), DOI 10.1093/biomet/29.3-4.350; Moskowitz, Ooi, and Pedersen (2012), Journal of Financial Economics 104(2), DOI 10.1016/j.jfineco.2011.11.003; SciPy 1.18.0 ttest_ind documentation and source."
source_citations:
  - type: ai_originated_governed_source
    citation: "OpenAI Codex (2026). WTI monthly fixed-block Welch mean-shift continuation."
    location: "strategy-seeds/sources/AI-CODEX-WTI-MWELCH-20260831/source.md"
    quality_tier: governed_source
    role: exact_trading_hypothesis_formula_thresholds_risk_and_lifecycle
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: monthly_own_return_continuation_and_explicit_wti_membership
  - type: peer_reviewed_statistical_method_record
    citation: "Welch, B. L. (1938). The Significance of the Difference Between Two Means When the Population Variances Are Unequal. Biometrika 29(3-4), 350-362."
    location: "DOI 10.1093/biomet/29.3-4.350; bibliographic metadata only"
    quality_tier: A_record_only
    role: unequal_variance_two_sample_mean_comparison_lineage
  - type: official_public_method_implementation
    citation: "SciPy community, scipy.stats.ttest_ind documentation and source, version 1.18.0."
    location: "https://docs.scipy.org/doc/scipy/reference/generated/scipy.stats.ttest_ind.html; https://github.com/scipy/scipy/blob/v1.18.0/scipy/stats/_stats_py.py"
    quality_tier: A_method_implementation
    role: statistic_orientation_and_unequal_variance_standard_error
strategy_mechanic: monthly-wti-twelve-completed-log-returns-fixed-six-old-six-recent-welch-unequal-variance-standardized-mean-shift-recent-mean-aligned-continuation
sources:
  - "[[sources/AI-CODEX-WTI-MWELCH-20260831]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/unequal-variance-mean-shift]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-log-return]]"
  - "[[indicators/welch-standardized-mean-shift]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, return-regime-shift, fixed-block-welch-score, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
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
magic: 412490000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately 5-8 completed WTI positions per full post-warm-up year; one consumed attempt per broker month. Q02 must prove at least five in every full scored year or retire."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_AI_SYNTHESIS_AND_METHOD_ACCESS_BOUNDARY
r1_reasoning: "One durable AI-originated source ID; complete-read peer-reviewed WTI evidence; named Welch bibliographic record; complete official public SciPy method evidence; exact trading conjunction disclosed as untested QM synthesis."
r2_mechanical: PASS
r2_reasoning: "Month clock, endpoints, returns, fixed samples, means, unbiased variances, standard error, score boundary, recent-mean alignment, attempt, risk, stop, spread, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_reasoning: "Registered native XTIUSD.DWX D1 and MT5 state supply every runtime input; continuous-CFD roll, basis, financing, gap, and broker-month-label risks remain."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, finite arithmetic, square roots, comparisons, ATR risk, quote, position, deal, and persistent state; no trained output or prohibited runtime feed."
parameters_to_test: "Locked Q02 baseline only: 13 consecutive completed month-end closes; 12 adjacent log returns; fixed old/recent blocks of 6; arithmetic means; unbiased sample variances; Welch se2; inclusive absolute score boundary 0.75 with recent-mean sign alignment; 900 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 frozen stop; 40-day stale exit; 1500-point spread ceiling."
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
review_focus: "Falsify a direct-WTI monthly unequal-variance return-regime sleeve outside the certified XAU/SP500/NDX/XNG book. Verify exact completed endpoints, log-return orientation, fixed six/six blocks, unbiased variances, Welch denominator, inclusive 0.75 boundary, recent-mean sign alignment, consumed month, fixed risk, frozen stop, and next-month lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_tradable_month_bar, thirteen_consecutive_completed_months, no_current_month_price, twelve_adjacent_log_returns, fixed_six_old_six_recent_membership, arithmetic_means, unbiased_variance_denominator_five, unequal_variance_standard_error, degenerate_variance_flat, inclusive_score_boundary, recent_mean_sign_alignment, monthly_attempt_state, risk_mode_dual, hard_stop_present, friday_close_disabled, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-31 and decisions/2026-08-31_qm5_41249_wti_monthly_welch_mean_shift_trend_g0.md: R1 passes with one durable AI source, complete-read peer-reviewed WTI evidence, a named peer-reviewed Welch record, complete official public SciPy method evidence, and explicit synthesis/access boundaries; R2 locks endpoints, returns, blocks, means, variances, score, side, attempt, risk, stop, spread, and lifecycle; R3 uses registered native WTI D1 with continuous-CFD risk; R4 uses deterministic native arithmetic only. Corrected-root canonical dedup returned CLEAN across 4,748 registry rows, 1,386 cards, and 45 Wiki nodes; manual review separates price-rank, ECDF, run, daily-median, endogenous-CUSUM, and certified-XNG families."
---

# QM5_41249 WTI Monthly Welch Mean-Shift Trend

## Hypothesis

WTI has physical supply, production, storage, transport, refining, hedging,
investment, geopolitical, and demand drivers absent from the certified
XAU/SP500/NDX/XNG carrier set. Those slow forces can shift both the mean and
variance of monthly WTI returns. A fixed six-month recent regime whose mean
has moved away from the preceding six months under an unequal-variance
standard error may persist through the next month.

This is a direct-crude structural-trend hypothesis, not evidence of
profitability or decorrelation. Q02 owns activity and baseline economics;
later gates own robustness; unchanged Q09 alone owns portfolio overlap.

## Source traceability and claim boundary

The single governed source ID resolves to
`strategy-seeds/sources/AI-CODEX-WTI-MWELCH-20260831/source.md`, authorized by
`decisions/2026-08-31_wti_monthly_welch_mean_shift_trend_source_approval.md`
at commit `de569f5f74` before extraction. Its reproducible retrieval evidence
is `strategy-seeds/sources/AI-CODEX-WTI-MWELCH-20260831/retrieval_route_20260831.json`.

Supporting evidence is bounded as follows:

- Moskowitz, Ooi, and Pedersen (2012) supply complete-read peer-reviewed
  monthly own-return continuation evidence and explicit WTI membership.
- Welch (1938) supplies a named peer-reviewed unequal-variance mean-
  comparison record; the body was inaccessible and no body result is
  reconstructed.
- SciPy 1.18.0 supplies complete public method documentation and tag-pinned
  source for statistic orientation and the unequal-variance form.

None tests this fixed twelve-return sample, six/six split, `0.75` boundary,
recent-mean alignment, WTI CFD, fixed risk, stop, or lifecycle. No source
performance, significance, density, cost, CFD-equivalence, correlation, or
portfolio statistic transfers.

## Non-duplicate boundary

The corrected-root pre-allocation checker returned `CLEAN` across 4,748 EA
registry identities, 1,386 card files, and 45 Strategy Wiki nodes. Receipt:
`artifacts/qm5_wti_mwelch_shift_tr_preallocation_dedup_20260831.json`.

The load-bearing differences are:

- Mann-Whitney `QM5_41176` counts all 36 cross-block wins among month-end
  price levels. This card uses adjacent returns, arithmetic means, and two
  magnitude-bearing sample variances.
- KS `QM5_41183` uses the maximum signed ECDF count gap of price levels. This
  card has no rank, combined sort, or ECDF.
- Wald-Wolfowitz `QM5_41184` counts pooled block-label runs. This card has no
  label sequence or run threshold.
- daily median shift `QM5_41137` compares daily log-price medians in two
  months. This card uses monthly returns over fixed half-years.
- centered CUSUM `QM5_41245` searches eleven return splits and retains one
  central maximum. This card fixes one split and uses separate variances.
- certified `QM5_12567` is a long-only XNG cumulative-RSI pullback; this card
  is symmetric monthly WTI and contains no oscillator.

Verdict:
`CLEAN_WTI_MONTHLY_FIXED_SIX_BY_SIX_WELCH_RETURN_MEAN_SHIFT_ALIGNED_CONTINUATION`.

## Rules

### Market, clock, and data

- Host and trade exact `XTIUSD.DWX` on D1, slot 0, magic `412490000`.
- Run only on the first executable D1 tick after a genuine normalized broker-
  month transition and within 180 elapsed minutes of raw current-bar open.
- Persist the new `yyyymm` attempt before every fallible entry gate. A
  restart, stop-out, invalid signal, or order failure never permits a same-
  month retry.
- Reconstruct exactly thirteen immediately prior consecutive completed
  broker-month end closes, oldest to newest, from a bounded 900-D1 buffer.
- Exclude every current-month price. Require positive finite closes, strict
  chronology, exact month continuity, and a newest endpoint no more than ten
  calendar days before the current month bar.

### Exact signal

For chronological completed-month closes `C[0..12]`:

```text
for i = 0..11:
    r[i] = log(C[i+1] / C[i])

old    = r[0..5]
recent = r[6..11]

mean_old    = sum(old) / 6
mean_recent = sum(recent) / 6

var_old    = sum((old[i]    - mean_old)^2 for i=0..5) / 5
var_recent = sum((recent[i] - mean_recent)^2 for i=0..5) / 5

se2 = var_old/6 + var_recent/6
require se2 > 1e-18
score = (mean_recent - mean_old) / sqrt(se2)

BUY  iff score >=  0.75 and mean_recent >  1e-12
SELL iff score <= -0.75 and mean_recent < -1e-12
FLAT otherwise
```

Every close, logarithm, return, sum, mean, centered difference, variance,
`se2`, square root, and score must be finite. Degenerate variance, boundary
miss, sign disagreement, zero recent mean, malformed endpoint, or arithmetic
failure consumes the month flat. There is no p-value, degrees-of-freedom
calculation, fitted split, pooled variance, fallback, or signal-strength
sizing.

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
- Reject malformed or current-month history, late attachment, an existing
  owned position, a same-month entry deal, crossed quotes, excessive spread,
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
| `strategy_month_returns` | 12 | locked | adjacent completed monthly log returns |
| `strategy_block_size` | 6 | locked | fixed older and recent samples |
| `strategy_score_floor` | `0.75` | locked | inclusive absolute score boundary |
| `strategy_zero_epsilon` | `1e-12` | locked | recent-mean direction tolerance |
| `strategy_min_se2` | `1e-18` | locked | degenerate-standard-error guard |
| `strategy_history_bars` | 900 | locked | bounded D1 reconstruction buffer |
| `strategy_entry_grace_minutes` | 180 | locked | first-month-bar entry window |
| `strategy_endpoint_stale_days` | 10 | locked | newest completed endpoint age ceiling |
| `strategy_atr_period` | 20 | locked | completed-D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | locked | frozen broker hard-stop multiple |
| `strategy_stale_days` | 40 | locked | survivor repair |
| `strategy_max_spread_points` | 1500 | locked | entry execution ceiling |

Changing the return count, split, mean, variance denominator, standard error,
score boundary, sign alignment, risk, or hold after observing Q02 is
forbidden.

## Reputable-source criteria

| gate | verdict | evidence |
|---|---|---|
| R1 | PASS_WITH_AI_SYNTHESIS_AND_METHOD_ACCESS_BOUNDARY | One durable source ID; complete WTI paper record; Welch metadata; complete public SciPy method evidence; explicit untested translation. |
| R2 | PASS | Clock, data, formula, blocks, means, variances, score, side, attempt, risk, stop, spread, and exits are exact. |
| R3 | PASS | Registered native WTI D1 and MT5 state only; roll/basis/financing/gap risks disclosed. |
| R4 | PASS | Deterministic native arithmetic only; no trained output, banned signal, external runtime feed, grid, martingale, scale-in, or pyramid. |

## Risk and kill criteria

- Q02 uses exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- WTI gaps, continuous-CFD roll/basis, financing, small-sample variance
  instability, return-magnitude sensitivity, and month-label offsets are
  material risks.
- Retire on zero positions, fewer than five completed positions in any full
  post-warm-up year, nonpositive governed economics, or a failed
  deterministic fixture.
- Fail on current-month leakage, missing/duplicate months, wrong return order,
  wrong block membership, population-variance denominator, pooled variance,
  degenerate-standard-error entry, wrong score boundary, wrong recent-mean
  alignment, missing stop, wrong risk mode, same-month retry, or
  nondeterminism.
- Q09 alone may establish realized portfolio correlation. This card grants no
  correlation waiver or portfolio admission.

## Framework alignment

- no_trade: exact host/timeframe/ID/slot, locked inputs, fixed-risk mode,
  month grace, persistent attempt, endpoint integrity, signal integrity,
  position/deal, spread, quote, ATR, stop, and sizing guards.
- trade_entry: cached aligned mean-shift direction, one fixed-risk WTI order,
  frozen ATR hard stop, no target.
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
| v1 | 2026-08-31 | initial fixed-block Welch WTI mean-shift card | G0 | APPROVED; build pending |

## Pipeline phase status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-31 | APPROVED; R1-R4 PASS | source approval, corrected-root dedup receipt, and this card |
| Q01 Build Validation | - | NOT_BUILT | pending magic allocation and exact implementation |
| Q02 Baseline Screening | - | NOT_ENQUEUED_Q01_PENDING | one paced enqueue only after strict Q01 and CPU admission |
