---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-WTI-ADF-KPSS-AGREE-TREND-20260904_S01
variant_id: AI-CODEX-WTI-ADF-KPSS-AGREE-TREND-20260904_S01
source_id: AI-CODEX-WTI-ADF-KPSS-AGREE-TREND-20260904
ea_id: QM5_41336
slug: wti-adf-kpss-agree-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41336_wti-adf-kpss-agree-tr_card.md
execution_contract_status: APPROVED
created: 2026-09-04
created_by: Research+Development
last_updated: 2026-09-04
g0_status: APPROVED
g0_decision: decisions/2026-09-04_qm5_41336_wti_monthly_adf_kpss_agreement_trend_g0.md
source_approval: decisions/2026-09-04_wti_monthly_adf_kpss_agreement_trend_source_approval.md
source_author: OpenAI Codex
source_authors: OpenAI Codex; Ernest P. Chan; Denis Kwiatkowski; Peter C. B. Phillips; Peter Schmidt; Yongcheol Shin; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen
source_citation: "OpenAI Codex (2026), WTI monthly ADF-KPSS persistence-agreement trend; supporting approved records Chan (2013), Algorithmic Trading, Wiley; Kwiatkowski et al. (1992), Journal of Econometrics 54, DOI 10.1016/0304-4076(92)90104-Y; Moskowitz, Ooi, and Pedersen (2012), Journal of Financial Economics 104(2), DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: governed_composite_source
    citation: "OpenAI Codex (2026). WTI monthly ADF-KPSS persistence-agreement trend."
    location: strategy-seeds/sources/AI-CODEX-WTI-ADF-KPSS-AGREE-TREND-20260904/source.md
    quality_tier: governed_source
    role: exact_conjunction_sample_threshold_risk_and_lifecycle
  - type: approved_adf_source
    citation: "Chan, E. P. (2013). Algorithmic Trading: Winning Strategies and Their Rationale. Wiley Trading."
    location: strategy-seeds/sources/AI-CODEX-WTI-MADF-PERSIST-TREND-20260903/source.md
    quality_tier: A
    role: lag_one_constant_no_time_trend_adf_arithmetic_and_boundary_orientation
  - type: peer_reviewed_econometrics_source
    citation: "Kwiatkowski, D., Phillips, P. C. B., Schmidt, P., and Shin, Y. (1992). Testing the Null Hypothesis of Stationarity against the Alternative of a Unit Root. Journal of Econometrics 54, 159-178."
    location: strategy-seeds/sources/KWIATKOWSKI-STATSMODELS-MOP-WTI-KPSS-20260902/source.md
    quality_tier: A
    role: constant_only_kpss_partial_sum_and_long_run_variance_state
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: strategy-seeds/sources/MOP-TSMOM-2012/source.md
    quality_tier: A
    role: monthly_own_return_continuation_and_explicit_wti_membership
strategy_mechanic: monthly-wti-sixty-completed-log-price-levels-lag-one-intercept-adf-t-at-least-minus2p594-and-constant-only-kpss-lag-four-at-least-0p347-agreement-gated-twelve-month-return-sign-continuation
sources:
  - "[[sources/AI-CODEX-WTI-ADF-KPSS-AGREE-TREND-20260904]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/dual-null-persistence-agreement]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-log-price]]"
  - "[[indicators/augmented-dickey-fuller-statistic]]"
  - "[[indicators/kpss-statistic]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, dual-null-agreement, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
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
magic: 413360000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately 5-9 completed WTI positions per full post-warm-up year is an uncalibrated planning prior; one attempt is consumed per broker month and either statistical gate may consume a month flat. Q02 must prove at least five completed positions in every full scored year or retire."
expected_trades_per_year_per_symbol: 7
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_GOVERNED_COMPLETE_PARENT_EVIDENCE
r1_reasoning: "Approved complete local ADF and KPSS method records plus a complete peer-reviewed WTI continuation record, exact hashes, adverse interpretation limits, and explicit non-transfer boundaries."
r2_mechanical: PASS
r2_reasoning: "Month clock, sixty endpoints, both locked arithmetic paths, inclusive thresholds, conjunction, twelve-month side, consumed attempt, fixed risk, stop, spread, and lifecycle are deterministic."
r3_data_available: PASS
r3_qualification: CONTINUOUS_CFD_BASIS_RISK
r3_reasoning: "Registered native XTIUSD.DWX D1 history and MT5 state supply every runtime input; continuous-CFD roll, basis, financing, gaps, and broker-month labels remain material risks."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, bounded OLS, partial sums, fixed Bartlett covariance arithmetic, comparisons, ATR risk, quotes, positions, deals, and persistent state are used."
parameters_to_test: "Locked Q02 baseline only: 60 consecutive completed month-end closes; log levels; ADF 58 observations, intercept, one lagged difference, 55 residual degrees of freedom, determinant relative floor 1e-12, inclusive adf_t >= -2.594; KPSS constant-only demeaning, 60 partial sums, four Bartlett covariance lags, inclusive kpss >= 0.347; arithmetic floors 1e-18; both gates required; newest 12-month direction epsilon 1e-12; 1800 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 frozen stop; 40-day stale exit; 1500-point spread ceiling."
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
review_focus: "Falsify a direct-WTI monthly ADF/KPSS agreement-gated trend outside the certified XAU/SP500/NDX/XNG book. Verify shared endpoints, distinct arithmetic paths, both inclusive boundaries, disagreement abstention, twelve-month side, consumed month, fixed risk, frozen stop, and next-month lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_tradable_month_bar, sixty_consecutive_completed_months, no_current_month_price, chronological_log_levels, adf_lag_one_constant_no_time_trend, adf_residual_dof_55, inclusive_adf_boundary, constant_only_kpss, kpss_four_lag_bartlett_variance, inclusive_kpss_boundary, both_gates_required, twelve_month_return_direction, monthly_attempt_state, risk_mode_dual, hard_stop_present, friday_close_disabled, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-09-04 and decisions/2026-09-04_qm5_41336_wti_monthly_adf_kpss_agreement_trend_g0.md: R1-R4 pass within disclosed statistical-synthesis and continuous-CFD risks. Corrected-root dedup found no exact identity across 4,816 registry rows, 1,435 cards, and 45 Wiki nodes; expected ADF and PP fuzzy neighbors were manually resolved with two disagreement fixtures proving the dual-null conjunction differs from either single-test state. This identity decision is not a correlation claim."
---

# QM5_41336 WTI Monthly ADF-KPSS Persistence-Agreement Trend

## Hypothesis

WTI supplies physical energy exposure through production, storage, transport,
refining, producer hedging, geopolitics, and end demand. Those drivers are
absent from the certified XAU/SP500/NDX/XNG book and differ from XNG weather
and storage sensitivity. The hypothesis is that a completed twelve-month WTI
move is suitable for one further broker month of continuation only when a
lag-one ADF state does not show strong error correction and a constant-only
KPSS state rejects the locked level-stationarity boundary.

The tests share the same sixty observations and are not independent votes.
Agreement does not prove a unit root, nonstationarity, persistence,
predictability, profit, or decorrelation. Q02 owns cadence and economics; Q09
alone owns realized book overlap.

## Source Traceability And Claim Boundary

The governed source is
`strategy-seeds/sources/AI-CODEX-WTI-ADF-KPSS-AGREE-TREND-20260904/source.md`,
approved and committed in `3913751920` before this extraction. It binds
previously approved complete ADF, KPSS, and WTI continuation records without
new external retrieval.

The parents define their arithmetic separately. Moskowitz-Ooi-Pedersen supply
monthly own-return continuation and WTI membership. No source tests this
conjunction, sixty continuous-CFD levels, thresholds as trading gates, fixed
risk, costs, activity, or portfolio overlap.

## Non-Duplicate Decision

The corrected-root receipt
`artifacts/qm5_wti_adf_kpss_agree_tr_preallocation_dedup_20260904.json`
found no exact identity and returned the expected ADF and PP fuzzy neighbors.

- `QM5_41319` uses only the lag-one ADF state; this card additionally requires
  a KPSS partial-sum/lag-four long-run-variance rejection.
- `QM5_41317` uses only KPSS; this card additionally requires the ADF
  error-correction regression to qualify.
- `QM5_41320` uses a lag-zero level AR(1) and eleven-lag Phillips-Perron
  correction, not the two-test conjunction.
- The reference fixture pins one ADF-only and one KPSS-only qualifier; both
  are flat under this card.

Manual identity verdict:
`DISTINCT_DUAL_NULL_AGREEMENT_STATE_FROM_EITHER_SINGLE_TEST_OR_PP_STATE`.
Shared WTI continuation may still correlate and receives no Q09 waiver.

## Markets, Timeframe, And Cadence

- Exact host/traded symbol: `XTIUSD.DWX`, D1, slot zero, intended magic
  `413360000` after deterministic allocation.
- Decide once on the first executable tick after a genuine normalized broker-
  month transition, within 180 minutes of the raw host D1 boundary.
- Formation: exactly sixty consecutive completed broker-month-end closes;
  current-month prices are excluded.
- Hold through Friday until the next broker month; forty days is stale repair.
- Planning prior: five to nine completed positions/year. Q02 retires below
  five in any full post-warm-up scored year.

## Exact Formula

For chronological completed-month closes `C[0..59]`, set `x[t]=ln(C[t])`.

ADF, for `t=2..59`:

```text
y[t]=x[t]-x[t-1]
z[t]=x[t-1]
w[t]=x[t-1]-x[t-2]
y=alpha+gamma*z+phi*w+error
```

Fit centered OLS over 58 rows. Require `Szz>1e-18`, `Sww>1e-18`,
`det=Szz*Sww-Szw^2 > 1e-12*Szz*Sww`, `SSE>1e-18`, residual variance
`SSE/55>0`, and `se_gamma>1e-18`. Set `adf_t=gamma/se_gamma`.

KPSS, with `mean_x`, residual `e[t]=x[t]-mean_x`, and cumulative residual
`S[t]`:

```text
eta=sum(S[t]^2)/3600
cross[k]=sum(e[t]*e[t-k]), k=1..4
s_hat=(sum(e[t]^2)+2*sum((1-k/5)*cross[k]))/60
kpss=eta/s_hat
```

Require residual energy and `s_hat` above `1e-18` and finite nonnegative
`eta` and `kpss`.

```text
mom12=x[59]-x[47]
BUY  iff adf_t >= -2.594 and kpss >= 0.347 and mom12 > +1e-12
SELL iff adf_t >= -2.594 and kpss >= 0.347 and mom12 < -1e-12
FLAT otherwise
```

Both comparisons are inclusive. Only momentum sign chooses side. No
statistic magnitude affects size.

## Rules

- Consume and persist the normalized broker month before history, signal,
  news, spread, quote, ATR, sizing, margin, or submission. Never retry.
- Select the latest close in each of the sixty immediately prior consecutive
  broker months from a bounded 1,800-D1 buffer.
- Fail closed on current-month input, missing/duplicate/nonconsecutive keys,
  nonchronological endpoints, nonpositive prices, endpoint staleness, invalid
  arithmetic, either failed state gate, or neutral momentum.
- Reject owned or foreign WTI exposure and an owned same-month entry deal.
- Both news axes, legacy news, Friday close, and stress are off.
- Q02 has one locked baseline and no optimization surface.

## Entry Rules

1. Require exact identity, `XTIUSD.DWX` D1, slot/magic, fixed-risk mode, and
   every locked framework/strategy input.
2. Process malformed-position and later-month/stale exits before entry gates.
3. Require a genuine new broker month inside the entry grace window.
4. Persist the attempt before every fallible gate.
5. Reconstruct sixty completed endpoints once and feed identical log levels
   to both arithmetic paths.
6. Require inclusive ADF and KPSS qualification plus strict twelve-month side.
7. Require spread in `[0,1500]`, executable quotes, completed D1 ATR(20),
   valid metadata, positive fixed-risk sizing, and margin.
8. Open at most one position with a frozen `3.5*ATR` hard stop and no target.

## Exit Rules

1. Framework kill switch and broker hard stop remain authoritative.
2. Close on the first processed tick in a later normalized broker month.
3. Close after forty elapsed calendar days as stale repair.
4. Close duplicate, wrong-symbol/magic/side, invalid-time/volume, missing-stop,
   or inconsistent persisted-state exposure immediately.
5. No intramonth test exit or flip, target, trail, break-even, partial close,
   Friday flatten, retry, scale-in, grid, martingale, or pyramid.

## Filters And Trade Management

Fail closed outside the exact host, identity, risk/news/Friday/stress and
locked-input contract. Lifecycle repair runs before entry-only gates on every
tick. Preserve the original hard stop and one-attempt/one-position state.
Runtime may not read curves, inventory, volume, open interest, files, APIs,
forecasts, optimizer output, portfolio state, or trained artifacts.

## Parameters To Test

Q02 has exactly one baseline: 60 log endpoints; 58-row lag-one intercept ADF,
55 residual degrees of freedom, `1e-12` determinant floor and inclusive
`-2.594`; constant-only KPSS with four Bartlett lags and inclusive `0.347`;
both gates required; 12-month sign with `1e-12` epsilon; 1,800 D1 bars;
180-minute grace; 10-day endpoint staleness; `3.5*ATR(20,D1)` stop; 40-day
stale hold; and 1,500-point spread ceiling. Any change creates a new identity.

## Risk

- Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- The single position has one frozen `3.5*ATR(20,D1)` hard stop and no target.
- Gaps can exceed modeled risk. The continuous CFD adds roll, basis,
  financing, spread, and broker-session risk.
- Small-sample ADF/KPSS size, shared observations, fixed lag choice, and
  overlapping monthly windows can invalidate the state hypothesis.
- No live risk mode or live artifact is authorized.

## Data Requirements

Native `XTIUSD.DWX` D1 timestamps/closes and ATR, broker time/month, quotes,
symbol metadata, margin, positions, deals, and terminal-global state only.

## Framework Alignment

| card rule | module |
|---|---|
| identity, fixed contract, month attempt, endpoint reconstruction, both state tests | `Strategy_NoTradeFilter` and bounded helpers |
| agreement gate, momentum side, spread, ATR, hard stop, one order | `Strategy_EntrySignal` |
| integrity repair, next-month and forty-day closure | `Strategy_ManageOpenPosition` |
| framework reason mapping | `Strategy_ExitSignal` and close helper |
| news disabled on both axes | `Strategy_NewsFilterHook` |

## Validation Plan

1. Match all five independent fixture paths, including both disagreement
   abstentions, additive log-level invariance, and degenerate failure.
2. Verify consecutive endpoints, no current-month leakage, exact row/lag/dof
   counts, inclusive boundaries, attempt ordering, fixed risk, and lifecycle.
3. Run card lint and strict Q01 compile/build checks.
4. Enqueue exactly one fixed-risk Q02 item only below the host CPU ceiling;
   do not launch a tester manually.

## Failure Conditions And Safety Boundary

Retire on zero positions, fewer than five completed positions in any full
post-warm-up year, formula/fixture mismatch, current-month leakage,
nonpositive governed economics, invalid risk, missing stop, lifecycle defect,
nondeterminism, or downstream hard failure. Preserve failures without tuning.

Authorized: deterministic identity/magic allocation, branch-only non-live
build, reference tests, strict Q01, one fixed-risk set, and one paced Q02
enqueue below the CPU ceiling.

Forbidden: optimization, manual backtest/tester launch, live/demo/shadow/
stress sets, portfolio-gate edits, correlation waivers, portfolio admission,
deploy/live manifests, `T_Live`, AutoTrading, terminal control, or live use.

## Revision History

| version | date | reason | gate | verdict |
|---|---|---|---|---|
| v1 | 2026-09-04 | initial WTI ADF-KPSS agreement trend card | G0 | APPROVED; build pending |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Source Approval | 2026-09-04 | APPROVED_SOURCE | `decisions/2026-09-04_wti_monthly_adf_kpss_agreement_trend_source_approval.md` |
| G0 Research Intake | 2026-09-04 | APPROVED | `decisions/2026-09-04_qm5_41336_wti_monthly_adf_kpss_agreement_trend_g0.md` |
| Q01 Build & Spec | TBD | PENDING | TBD |
| Q02 Baseline | TBD | NOT_ENQUEUED | TBD |
