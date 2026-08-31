---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-WTI-MBRUNNER-20260831_S01
variant_id: AI-CODEX-WTI-MBRUNNER-20260831_S01
source_id: AI-CODEX-WTI-MBRUNNER-20260831
ea_id: QM5_41251
slug: wti-mbrunner-shift-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41251_wti-mbrunner-shift-tr_card.md
execution_contract_status: APPROVED
created: 2026-08-31
created_by: Research+Development
last_updated: 2026-08-31
g0_status: APPROVED
g0_decision: decisions/2026-08-31_qm5_41251_wti_monthly_brunner_munzel_shift_trend_g0.md
source_approval: decisions/2026-08-31_wti_monthly_brunner_munzel_shift_trend_source_approval.md
source_author: "OpenAI Codex"
source_authors: "OpenAI Codex; Edgar Brunner; Ullrich Munzel; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; lawstat authors"
source_citation: "OpenAI Codex (2026), WTI monthly Brunner-Munzel stochastic-dominance continuation; supporting records Brunner and Munzel (2000), Biometrical Journal 42(1), DOI 10.1002/(SICI)1521-4036(200001)42:1<17::AID-BIMJ17>3.0.CO;2-U; Moskowitz, Ooi, and Pedersen (2012), Journal of Financial Economics 104(2), DOI 10.1016/j.jfineco.2011.11.003; CRAN lawstat 3.6 manual and pinned source."
source_citations:
  - type: ai_originated_governed_source
    citation: "OpenAI Codex (2026). WTI monthly Brunner-Munzel stochastic-dominance continuation."
    location: "strategy-seeds/sources/AI-CODEX-WTI-MBRUNNER-20260831/source.md"
    quality_tier: governed_source
    role: exact_trading_hypothesis_formula_thresholds_risk_and_lifecycle
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: monthly_own_return_continuation_and_explicit_wti_membership
  - type: peer_reviewed_statistical_method_record
    citation: "Brunner, E. and Munzel, U. (2000). The Nonparametric Behrens-Fisher Problem: Asymptotic Theory and a Small-Sample Approximation. Biometrical Journal 42(1), 17-25."
    location: "DOI 10.1002/(SICI)1521-4036(200001)42:1<17::AID-BIMJ17>3.0.CO;2-U"
    quality_tier: A
    role: heteroskedastic_rank_test_relative_effect_and_variance_lineage
  - type: official_public_method_implementation
    citation: "CRAN lawstat 3.6, brunner.munzel.test manual and source."
    location: "https://stat.ethz.ch/CRAN/web/packages/lawstat/lawstat.pdf; https://github.com/cran/lawstat/blob/master/R/brunner.munzel.test.R; Git blob de99dac14eaec03bada934e1ae2b2bf9714e9ebf"
    quality_tier: A_method_implementation
    role: corrected_combined_rank_within_rank_placement_variance_and_studentization_formula
strategy_mechanic: monthly-wti-twenty-completed-log-returns-fixed-ten-old-ten-recent-brunner-munzel-studentized-rank-placement-stochastic-dominance-absolute-threshold-0625-continuation
sources:
  - "[[sources/AI-CODEX-WTI-MBRUNNER-20260831]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/stochastic-dominance-shift]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-log-return]]"
  - "[[indicators/brunner-munzel-rank-placement-score]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, stochastic-dominance-shift, brunner-munzel, rank-placement-variance, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
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
magic: 412510000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately 6 completed WTI positions per full post-warm-up year; one consumed attempt per broker month. Exact pre-data distinct-rank allocation density is 6.305 attempts/year. Q02 must prove at least five in every full scored year or retire."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_AI_SYNTHESIS_AND_CORRECTED_METHOD_BOUNDARY
r1_reasoning: "One durable AI-originated source ID; complete-read peer-reviewed WTI evidence; peer-reviewed Brunner-Munzel method record; official CRAN manual and pinned corrected implementation; exact trading conjunction disclosed as untested QM synthesis."
r2_mechanical: PASS
r2_reasoning: "Month clock, endpoints, returns, fixed ten/ten samples, exact midranks, placement variances, studentized score, finite degeneracy rule, inclusive 0.625 boundaries, attempt, risk, stop, spread, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_reasoning: "Registered native XTIUSD.DWX D1 and MT5 state supply every runtime input; continuous-CFD roll, basis, financing, gap, and broker-month-label risks remain."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, finite ranks and arithmetic, square roots, comparisons, ATR risk, quote, position, deal, and persistent state; no trained output or prohibited runtime feed."
parameters_to_test: "Locked Q02 baseline only: 21 consecutive completed month-end closes; 20 adjacent log returns; fixed old/recent blocks of 10; exact average ranks for ties; source-defined pooled/within rank-placement variances; denominator epsilon 1e-12; finite directional cap 1e6; inclusive absolute score boundary 0.625; 1200 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 frozen stop; 40-day stale exit; 1500-point spread ceiling."
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
review_focus: "Falsify a direct-WTI monthly rank-placement regime sleeve outside the certified XAU/SP500/NDX/XNG book. Verify exact completed endpoints, log-return orientation, fixed ten/ten blocks, average ties, combined/within ranks, placement variances, degenerate denominator, inclusive +/-0.625 boundaries, consumed month, fixed risk, frozen stop, and next-month lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_tradable_month_bar, twenty_one_consecutive_completed_months, no_current_month_price, twenty_adjacent_log_returns, fixed_ten_old_ten_recent_membership, exact_average_ties, combined_old_then_recent_rank_orientation, source_placement_variances, denominator_epsilon, finite_complete_separation_limit, inclusive_score_boundaries, monthly_attempt_state, risk_mode_dual, hard_stop_present, friday_close_disabled, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-31 and decisions/2026-08-31_qm5_41251_wti_monthly_brunner_munzel_shift_trend_g0.md: R1 passes with one durable AI source, complete-read peer-reviewed WTI evidence, peer-reviewed method metadata, an official CRAN manual, a pinned corrected implementation, and explicit synthesis boundaries; R2 locks endpoints, returns, blocks, ranks, placement variances, score, side, attempt, risk, stop, spread, and lifecycle; R3 uses registered native WTI D1 with continuous-CFD risk; R4 uses deterministic native arithmetic only. Corrected-root canonical dedup found no exact identity across 4,750 registry rows, 1,388 cards, and 45 Wiki nodes; manual review separates Welch, permutation-MAD, Mann-Whitney, KS, Pettitt, and certified-XNG families."
---

# QM5_41251 WTI Monthly Brunner-Munzel Shift Trend

## Hypothesis

WTI has physical supply, production, storage, transport, refining, hedging,
investment, geopolitical, and demand drivers absent from the certified
XAU/SP500/NDX/XNG carrier set. Those slow forces can shift both the ordering
and dispersion of monthly WTI returns. A fixed recent ten-month block whose
return distribution stochastically dominates or trails the prior ten months
after separate rank-placement variance studentization may continue through
the next month.

This is a direct-crude structural-trend hypothesis, not evidence of
profitability or decorrelation. Q02 owns activity and baseline economics;
later gates own robustness; unchanged Q09 alone owns portfolio overlap.

## Source traceability and claim boundary

The single governed source ID resolves to
`strategy-seeds/sources/AI-CODEX-WTI-MBRUNNER-20260831/source.md`, authorized
by
`decisions/2026-08-31_wti_monthly_brunner_munzel_shift_trend_source_approval.md`
at commit `7fa33b6ea0`. Its reproducible read evidence is
`strategy-seeds/sources/AI-CODEX-WTI-MBRUNNER-20260831/retrieval_route_20260831.json`.

Moskowitz, Ooi, and Pedersen (2012) supply complete-read peer-reviewed monthly
own-return continuation evidence and explicit NYMEX WTI membership. Brunner
and Munzel (2000), the official CRAN manual, and the pinned corrected
`lawstat` source supply the rank-placement statistic. They do not test this
fixed twenty-return sample, the `0.625` boundary, a continuous WTI CFD, fixed
risk, stop, or lifecycle. No source performance, significance, density,
cost, CFD-equivalence, correlation, or portfolio statistic transfers.

## Non-duplicate boundary

The corrected-root pre-allocation checker found no exact identity across
4,750 registry identities, 1,388 card files, and 45 Strategy Wiki nodes. It
returned fuzzy neighbors `QM5_41249` and `QM5_41250`. Receipt:
`artifacts/qm5_wti_mbrunner_shift_tr_preallocation_dedup_20260831.json`.

The load-bearing differences are:

- Welch `QM5_41249` uses raw arithmetic means and raw sample variances. This
  card uses only midranks and separate pooled-versus-within rank-placement
  variances, making the score invariant to monotone transforms.
- permutation-MAD `QM5_41250` qualifies a dispersion expansion across 924
  relabelings and uses the raw recent mean for side. This card qualifies a
  studentized stochastic-order location effect and enumerates no labels at
  runtime.
- Mann-Whitney `QM5_41176` thresholds one unstudentized cross-pair count. This
  card estimates separate rank-placement variances and distinguishes equal-U
  heteroskedastic arrangements.
- KS `QM5_41183` uses a maximum directional empirical-CDF gap. This card uses
  an average relative effect and studentization rather than a supremum.
- Pettitt `QM5_41172` searches candidate split locations. This card fixes one
  old/recent ten-month split.
- certified `QM5_12567` is a long-only XNG cumulative-RSI pullback; this card
  is symmetric monthly direct WTI and contains no oscillator.

Verdict:
`DISTINCT_WTI_MONTHLY_FIXED_TEN_BY_TEN_BRUNNER_MUNZEL_STUDENTIZED_RANK_PLACEMENT_STOCHASTIC_DOMINANCE_CONTINUATION`.

## Rules

### Market, clock, and data

- Host and trade exact `XTIUSD.DWX` on D1, slot 0, magic `412510000`.
- Run only on the first executable D1 tick after a genuine normalized broker-
  month transition and within 180 elapsed minutes of raw current-bar open.
- Persist the new `yyyymm` attempt before every fallible entry gate. A
  restart, stop-out, invalid signal, or order failure never permits a same-
  month retry.
- Reconstruct exactly twenty-one immediately prior consecutive completed
  broker-month end closes, oldest to newest, from a bounded 1,200-D1 buffer.
- Exclude every current-month price. Require positive finite closes, strict
  chronology, exact month continuity, and a newest endpoint no more than ten
  calendar days before the current month bar.

### Exact signal

For chronological completed-month closes `C[0..20]`:

```text
for i = 0..19:
    r[i] = log(C[i+1] / C[i])

old    = r[0..9]
recent = r[10..19]
pooled = old || recent

rank each vector independently using exact average ranks for exact ties
m_old    = mean(pooled_rank[0..9])
m_recent = mean(pooled_rank[10..19])

v_old = sum((pooled_rank[i] - rank_old[i]
             - m_old + 5.5)^2 for i=0..9) / 9
v_recent = sum((pooled_rank[10+i] - rank_recent[i]
                - m_recent + 5.5)^2 for i=0..9) / 9

numerator = 100 * (m_recent - m_old) / 20
denominator = sqrt(10*v_old + 10*v_recent)

if denominator > 1e-12:
    score = numerator / denominator
else if m_recent - m_old > 1e-12:
    score = +1e6
else if m_recent - m_old < -1e-12:
    score = -1e6
else:
    FLAT

BUY  iff score >= +0.625
SELL iff score <= -0.625
FLAT otherwise
```

Every close, logarithm, return, rank, mean, variance component, numerator,
denominator, and score must be finite. Ties receive exact average ranks; no
jitter is added. The EA does not compute a p-value, degrees of freedom, or
confidence interval. The score never scales risk.

The fixed threshold has a pre-data distinct-rank allocation density of
97,078 / 184,756 = 52.5439%, or about 6.305 monthly attempts per twelve
clocks. This is not a market result. Receipt:
`artifacts/qm5_wti_mbrunner_shift_tr_threshold_density_20260831.json`.

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
  owned position, a same-month entry deal, an invalid rank score, an interior
  score, crossed quotes, excessive spread, invalid ATR/stop metadata, or a
  nonpositive fixed-risk size.

## 7. Trade Management Rules

- Repair malformed owned exposure before entry-only gates: duplicates, wrong
  symbol/magic, invalid volume, missing stop, or invalid open time close.
- Apply no stop modification after entry. There is no trail, break-even,
  partial close, grid, martingale, scale-in, or pyramid.

## Parameters to test

Q02 uses one locked baseline and no optimization surface:

| parameter | default | Q02 status | role |
|---|---:|---|---|
| `strategy_month_returns` | 20 | locked | adjacent completed monthly log returns |
| `strategy_block_size` | 10 | locked | fixed older and recent samples |
| `strategy_denominator_epsilon` | `1e-12` | locked | degenerate placement-variance guard |
| `strategy_score_cap` | `1e6` | locked | finite complete-separation direction limit |
| `strategy_score_threshold` | `0.625` | locked | inclusive entry boundary |
| `strategy_history_bars` | 1200 | locked | bounded D1 reconstruction buffer |
| `strategy_entry_grace_minutes` | 180 | locked | first-month-bar entry window |
| `strategy_endpoint_stale_days` | 10 | locked | newest completed endpoint age ceiling |
| `strategy_atr_period` | 20 | locked | completed-D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | locked | frozen broker hard-stop multiple |
| `strategy_stale_days` | 40 | locked | survivor repair |
| `strategy_max_spread_points` | 1500 | locked | entry execution ceiling |

Changing the return count, split, rank convention, placement-variance
formula, degeneracy rule, threshold, direction, risk, or hold after observing
Q02 is forbidden.

## Reputable-source criteria

| gate | verdict | evidence |
|---|---|---|
| R1 | PASS_WITH_AI_SYNTHESIS_AND_CORRECTED_METHOD_BOUNDARY | One durable source ID; complete-read peer-reviewed WTI packet; peer-reviewed method record; official manual and pinned corrected source; exact conjunction disclosed as untested. |
| R2 | PASS | Clock, data, ranks, placement variances, score, side, attempt, risk, stop, spread, and exits are exact. |
| R3 | PASS | Registered native WTI D1 and MT5 state only; roll/basis/financing/gap risks disclosed. |
| R4 | PASS | Deterministic native arithmetic only; no trained output, banned signal, external runtime feed, grid, martingale, scale-in, or pyramid. |

## Risk and kill criteria

- Q02 uses exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- WTI gaps, continuous-CFD roll/basis, financing, small-sample ranks,
  ties, score degeneracy, and month-label offsets are material risks.
- Retire on zero positions, fewer than five completed positions in any full
  post-warm-up year, nonpositive governed economics, or a failed
  deterministic fixture.
- Fail on current-month leakage, missing/duplicate months, wrong return order,
  wrong block membership, wrong average ranks, wrong pooled orientation,
  wrong placement variance or denominator, wrong finite separation handling,
  boundary error, missing stop, wrong risk mode, same-month retry, or
  nondeterminism.
- Q09 alone may establish realized portfolio correlation. This card grants no
  correlation waiver or portfolio admission.

## Framework alignment

- no_trade: exact host/timeframe/ID/slot, locked inputs, fixed-risk mode,
  month grace, persistent attempt, endpoint integrity, rank-score integrity,
  position/deal, spread, quote, ATR, stop, and sizing guards.
- trade_entry: cached Brunner-Munzel-qualified direction, one fixed-risk WTI
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
| v1 | 2026-08-31 | initial Brunner-Munzel rank-placement WTI card | G0 | APPROVED; build pending |

## Pipeline phase status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-31 | APPROVED; R1-R4 PASS | source approval, corrected-root dedup receipt, threshold-density receipt, and this card |
| Q01 Build Validation | - | NOT_BUILT | pending magic allocation and exact implementation |
| Q02 Baseline Screening | - | NOT_ENQUEUED_Q01_PENDING | one paced enqueue only after strict Q01 and CPU admission |
