---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-WTI-MPP-PERSIST-TREND-20260903_S01
variant_id: AI-CODEX-WTI-MPP-PERSIST-TREND-20260903_S01
source_id: AI-CODEX-WTI-MPP-PERSIST-TREND-20260903
ea_id: QM5_41320
slug: wti-mpp-persist-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41320_wti-mpp-persist-tr_card.md
execution_contract_status: APPROVED
created: 2026-09-03
created_by: Research+Development
last_updated: 2026-09-03
g0_status: APPROVED
g0_decision: decisions/2026-09-03_qm5_41320_wti_monthly_pp_persistence_trend_g0.md
source_approval: decisions/2026-09-03_wti_monthly_pp_persistence_trend_source_approval.md
source_author: OpenAI Codex
source_authors: OpenAI Codex; Peter C. B. Phillips; Pierre Perron; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen
source_citation: "OpenAI Codex (2026), WTI monthly Phillips-Perron persistence-gated trend; supporting records Phillips and Perron (1988), Biometrika 75(2), DOI 10.1093/biomet/75.2.335; Moskowitz, Ooi, and Pedersen (2012), Journal of Financial Economics 104(2), DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: ai_originated_governed_source
    citation: "OpenAI Codex (2026). WTI monthly Phillips-Perron persistence-gated trend."
    location: strategy-seeds/sources/AI-CODEX-WTI-MPP-PERSIST-TREND-20260903/source.md
    quality_tier: governed_source
    role: exact_conjunction_sample_threshold_risk_and_lifecycle
  - type: peer_reviewed_econometrics_paper
    citation: "Phillips, P. C. B. and Perron, P. (1988). Testing for a Unit Root in Time Series Regression. Biometrika 75(2), 335-346."
    location: "DOI 10.1093/biomet/75.2.335; complete-read evidence in strategy-seeds/sources/AI-CODEX-WTI-MPP-PERSIST-TREND-20260903/retrieval_route_20260903.json"
    quality_tier: A
    role: lag_zero_ar1_bartlett_long_run_variance_pp_z_tau_and_adverse_finite_sample_warning
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper record strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: monthly_own_return_continuation_and_explicit_wti_membership_only
strategy_mechanic: monthly-wti-sixty-completed-log-price-levels-lag-zero-intercept-ar1-bartlett-eleven-lag-newey-west-phillips-perron-z-tau-at-least-minus2p594-gated-twelve-month-return-sign-continuation
sources:
  - "[[sources/AI-CODEX-WTI-MPP-PERSIST-TREND-20260903]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/nonparametric-persistence-state]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-log-price]]"
  - "[[indicators/phillips-perron-z-tau]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, phillips-perron-state, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
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
magic: 413200000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately 7-11 completed WTI positions per full post-warm-up year is an uncalibrated planning prior; one attempt is consumed per broker month and the PP state gate can consume a month flat. Q02 must prove at least five completed positions in every full scored year or retire."
expected_trades_per_year_per_symbol: 8
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_AI_SYNTHESIS_AND_COMPLETE_PEER_REVIEWED_EVIDENCE
r1_reasoning: "One durable AI lineage binds a complete 12-page peer-reviewed PP article and a complete peer-reviewed WTI trend record, exact retrieval hashes, read scopes, adverse evidence, and explicit non-transfer limits."
r2_mechanical: PASS
r2_reasoning: "Month clock, sixty endpoints, log orientation, 59-row intercept AR(1), 57 residual degrees of freedom, eleven Bartlett lags, covariance divisor, PP Z-tau correction, inclusive state line, twelve-month side, attempt, fixed risk, hard stop, spread, and lifecycle are locked."
r3_data_available: PASS
r3_qualification: CONTINUOUS_CFD_BASIS_RISK
r3_reasoning: "Registered native XTIUSD.DWX D1 history and MT5 state supply every runtime input; continuous-CFD roll, basis, financing, gaps, and broker-month labels remain material risks."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, bounded OLS and Bartlett covariance arithmetic, comparisons, ATR risk controls, quotes, positions, deals, and persistent state; no trained output, prohibited signal indicator, or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: 60 consecutive completed month-end closes; log levels; 59 rows of x[t] on intercept and x[t-1]; 57 residual degrees of freedom; 11 Bartlett/Newey-West residual lags with weight 1-j/12 and divisor 59; energy floors 1e-18; inclusive pp_z_tau >= -2.594; newest 12-month return direction epsilon 1e-12; 1200 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 frozen stop; 40-day stale exit; 1500-point spread ceiling."
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
review_focus: "Falsify a direct-WTI monthly PP-HAC persistence-gated trend outside the certified XAU/SP500/NDX/XNG book. Verify completed endpoints, AR(1) orientation, OLS variance, eleven residual autocovariances, Bartlett weights, PP Z-tau correction, inclusive boundary, twelve-month side, consumed month, fixed risk, hard stop, and next-month lifecycle. The ADF neighbor is an acknowledged fuzzy match; Q09 alone may establish useful realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_tradable_month_bar, sixty_consecutive_completed_months, no_current_month_price, chronological_log_levels, exact_fifty_nine_regression_rows, intercept_no_time_trend, residual_dof_57, eleven_bartlett_lags, covariance_divisor_59, pp_z_tau_formula, inclusive_pp_threshold, twelve_month_return_direction, monthly_attempt_state, risk_mode_dual, hard_stop_present, friday_close_disabled, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-09-03 and decisions/2026-09-03_qm5_41320_wti_monthly_pp_persistence_trend_g0.md: R1-R4 pass within disclosed source-translation and continuous-CFD risks. Corrected-root dedup found no exact identity across 4,805 registry rows, 1,434 cards, and 45 Wiki nodes; the expected ADF fuzzy match was manually resolved because PP uses a lag-zero level AR(1) plus eleven-lag Bartlett residual correction rather than ADF's lagged-difference regression. This identity decision is not a correlation claim."
---

# QM5_41320 WTI Monthly Phillips-Perron Persistence-Gated Trend

## Hypothesis

WTI supplies physical energy exposure through production, storage, transport,
refining, producer hedging, geopolitics, and end demand. Those drivers are
absent from the certified XAU/SP500/NDX/XNG book and differ from XNG's weather
and storage sensitivity. The hypothesis is that a completed twelve-month WTI
move is more suitable for one-month continuation when a lag-zero Phillips-
Perron regression does not show a strongly mean-reverting price-level state.

The PP statistic does not prove a unit root, persistence, predictability, or
portfolio independence. The boundary is a fixed state classifier. Q02 owns
activity and economics; Q09 alone owns realized return-stream overlap.

## Source Traceability And Claim Boundary

The governed source is
`strategy-seeds/sources/AI-CODEX-WTI-MPP-PERSIST-TREND-20260903/source.md`,
approved and committed before this extraction. Its retrieval receipt pins the
complete Phillips-Perron paper, the complete Moskowitz-Ooi-Pedersen WTI
record, and a versioned arithmetic oracle.

Phillips and Perron supply the unit-root regression and non-parametric Z-tau
correction. Moskowitz-Ooi-Pedersen supply monthly own-return continuation and
explicit NYMEX WTI membership. Neither tests this conjunction, sixty CFD
levels, eleven lags, the translated boundary, fixed risk, costs, activity, or
correlation. The PP paper's negative-serial-correlation finite-sample warning
is part of the falsification boundary.

## Non-Duplicate Decision

The corrected-root receipt found no exact duplicate but correctly flagged
`QM5_41319_wti-madf-persist-tr` as a `0.75` fuzzy neighbor.

- `QM5_41319` regresses first differences on a lagged level and one lagged
  difference; it has three coefficients, 55 residual degrees of freedom,
  and an uncorrected coefficient t statistic.
- This card regresses levels on one lag and an intercept; it has two
  coefficients, 57 residual degrees of freedom, then applies eleven residual
  autocovariances and Bartlett weights to transform the raw t ratio.
- KPSS, autocorrelation, ARCH, BDS, entropy, variance-ratio, robust-block,
  calendar, event, channel, and pure momentum cards observe different state
  objects. Certified `QM5_12567` is a two-day long-only XNG pullback.

Manual identity verdict:
`DISTINCT_PP_ZTAU_HAC_STATE_FROM_ADF_LAGGED_DIFFERENCE_STATE`. The shared WTI
continuation carrier may still correlate; only Q09 may decide that question.

## Markets, Timeframe, And Cadence

- Host and traded symbol: exact `XTIUSD.DWX`, D1, slot zero, intended magic
  `413200000` after deterministic allocation.
- Decide on the first executable tick after a genuine normalized broker-month
  transition, no later than 180 minutes after the raw host D1 bar open.
- Formation: exactly sixty consecutive completed broker-month-end closes;
  current-month prices are excluded.
- Hold: until the next normalized broker month; forty calendar days is stale
  repair only.
- Planning cadence: seven to eleven completed positions/year, uncalibrated.
  Q02 retires below five in any full post-warm-up year.

## Formula

For chronological completed-month log closes `x[0..59]`, fit 59 rows:

```text
lhs[i] = x[i+1], rhs[i] = x[i], i=0..58
lhs = alpha + rho*rhs + u
```

With `n=59`, `k=2`, and `L=11`:

```text
Sxx    = sum((rhs-mean(rhs))^2)
Sxy    = sum((rhs-mean(rhs))*(lhs-mean(lhs)))
rho    = Sxy/Sxx
alpha  = mean(lhs)-rho*mean(rhs)
u[i]   = lhs[i]-alpha-rho*rhs[i]
SSE    = sum(u[i]^2)
s2     = SSE/57
s      = sqrt(s2)
gamma0 = SSE/59
se_rho = sqrt(s2/Sxx)
gamma[j] = sum(i=j..58, u[i]*u[i-j])/59
weight[j] = 1-j/12
lambda2 = gamma0 + 2*sum(j=1..11, weight[j]*gamma[j])
lambda = sqrt(lambda2)
raw_tau = (rho-1)/se_rho
pp_z_tau = sqrt(gamma0/lambda2)*raw_tau
           - 0.5*((lambda2-gamma0)/lambda)*(59*se_rho/s)
mom12 = x[59]-x[47]
```

Require finite values, `Sxx>1e-18`, `SSE>1e-18`, `s2>0`,
`gamma0>1e-18`, `lambda2>1e-18`, `se_rho>1e-18`, and `s>1e-18`.

```text
pp_z_tau >= -2.594 and mom12 > +1e-12 => BUY
pp_z_tau >= -2.594 and mom12 < -1e-12 => SELL
otherwise                              => consume month flat
```

The PP comparison is inclusive. Statistic and return magnitudes never size
risk. No alternative regression, trend term, lag count, kernel, divisor,
p-value interpolation, fallback, or threshold exists.

## Rules

- Persist the current normalized broker month before history, signal, news,
  spread, quote, ATR, sizing, margin, or submission. Never retry the month.
- Select the latest close in each of the sixty immediately prior consecutive
  broker months from a bounded 1,200-D1 buffer.
- Reject current-month input, missing or duplicate months, nonconsecutive
  keys, nonchronological endpoints, nonpositive closes, a newest endpoint
  more than ten days stale, or invalid arithmetic.
- Reject owned or foreign WTI exposure and an owned same-month entry deal.
- Both news axes, legacy news mode, Friday close, and stress are off.
- Q02 has one locked baseline and no optimization surface.

## 4. Entry Rules

1. Require exact EA ID, symbol, D1 period, slot, registered magic, fixed-risk
   mode, framework settings, and every locked strategy input.
2. Process malformed-position and later-month/stale exits before entry gates.
3. Require a genuine new broker month inside the 180-minute grace window.
4. Persist the month attempt before every fallible gate.
5. Reconstruct sixty consecutive completed endpoints and calculate the exact
   59-row intercept AR(1), eleven-lag Bartlett long-run variance, and PP
   Z-tau correction without current-month data.
6. Enforce every arithmetic floor, inclusive PP state, and strict twelve-
   month return side.
7. Require a nonnegative spread no greater than 1,500 points, quotes,
   completed-D1 ATR(20), valid metadata, fixed-risk sizing, and margin.
8. Open at most one position with the fixed-risk budget, a frozen
   `3.5*ATR(20,D1)` broker hard stop, and no target.

## 5. Exit Rules

1. Framework kill switch and broker hard stop remain authoritative.
2. Close on the first processed tick in a normalized broker month later than
   the entry month, before considering replacement risk.
3. Close after forty elapsed calendar days as stale repair.
4. Close malformed owned exposure immediately: duplicate, wrong symbol or
   magic, invalid volume/open time, missing hard stop, or inconsistent
   persisted entry-month state.
5. No intramonth statistic exit or flip, target, trail, break-even move,
   partial close, Friday flatten, retry, scale-in, grid, or pyramid.

## 6. Filters (No-Trade Module)

Fail closed outside the exact host, period, identity, slot, magic, fixed-risk,
news, Friday, stress, and locked-input contract. Reject a consumed attempt,
exposure/deal, malformed endpoints, invalid regression/covariance, PP state
below threshold, neutral momentum, excessive spread, invalid quote, missing
ATR, invalid stop/volume, or insufficient margin. Runtime may not read
futures curves, inventory, volume, open interest, files, APIs, forecasts,
optimizer results, portfolio state, or trained artifacts.

## 7. Trade Management Rules

Maintain zero or one valid stop-protected WTI position and one consumed
attempt per broker month. Preserve the original hard stop; close before
monthly renewal or at the stale ceiling. Restart recovery combines the
terminal-persistent attempt marker with owned position and deal history.

## Parameters To Test

Q02 has exactly one locked baseline:

| input | value |
|---|---:|
| completed month endpoints | 60 |
| AR(1) regression observations | 59 |
| regression coefficients | 2 |
| deterministic time trend | disabled |
| residual degrees of freedom | 57 |
| Bartlett/Newey-West residual lags | 11 |
| Bartlett weight | `1-j/12` |
| covariance divisor | 59 |
| energy floors | `1e-18` |
| PP Z-tau state floor | `-2.594` inclusive |
| momentum horizon | 12 completed months |
| direction epsilon | `1e-12` |
| D1 history buffer | 1,200 bars |
| entry grace | 180 minutes |
| endpoint gap ceiling | 10 days |
| ATR stop | `3.5*ATR(20,D1)` |
| stale hold ceiling | 40 days |
| spread ceiling | 1,500 points |

Changing any value creates a new identity and requires new source, card,
binary, and evidence. No failed baseline may be rescued inside this card.

## Risk

- Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- The single position receives one frozen `3.5*ATR(20,D1)` broker hard stop
  and no target.
- Signal magnitudes never affect volume; at most one position exists.
- Gaps, continuous-CFD roll/basis/financing, spread, month labels, overlapping
  windows, long-run-variance cancellation, and negative serial correlation
  can invalidate the state gate or exceed modeled risk.
- No live risk mode or live artifact is authorized.

## Source-Defined Rules

Phillips and Perron define the level autoregression, residual long-run-
variance correction, Bartlett-compatible estimator, Z-tau transformation,
and shared Dickey-Fuller limiting distribution. Moskowitz-Ooi-Pedersen
document monthly own-return continuation and WTI membership.

No source defines this conjunction, sixty-month sample, eleven-lag freeze,
threshold use, continuous CFD, risk, stop, spread, density, performance, or
correlation.

## QM Interpretations

The state boundary, sample, fixed lag count, continuation conjunction,
consumed attempt, hard stop, spread, and lifecycle are transparent pre-result
choices. A value above the boundary is not represented as a valid p-value,
proof of a unit root, or forecast.

## Framework Execution Overrides

- `qm_news_temporal=QM_NEWS_TEMPORAL_OFF`.
- `qm_news_compliance=QM_NEWS_COMPLIANCE_NONE`.
- `qm_news_mode_legacy=QM_NEWS_OFF`.
- `qm_friday_close_enabled=false`.
- `qm_stress_reject_probability=0` in the canonical baseline.
- Kill switch, weekend, disconnect, sizing, magic resolution, order service,
  MAE tracking, and hard-stop coverage remain active.

## Exit Precedence

1. Framework kill switch and broker hard stop.
2. Malformed-position integrity repair.
3. New-broker-month close.
4. Forty-day stale close.
5. Entry-only history, statistic, direction, spread, quote, ATR, sizing, and
   margin gates.

## Runtime Data Dependencies

Exact native `XTIUSD.DWX` D1 timestamps and closes, broker time/month, quotes,
symbol metadata, completed-bar ATR, positions, deals, and terminal-global
attempt/entry-month state. No external runtime data or trained artifact.

## Execution Assumptions

Q02 runs exact `XTIUSD.DWX` D1 with registered slot-zero magic, native quotes,
canonical tester deposit/currency defaults, and real ticks. The continuous
CFD is not the papers' futures series and may invalidate the edge through
roll, basis, financing, spread, gaps, or timestamp conventions.

## Falsification And Requalification

Retire on zero positions, fewer than five completed positions in any full
post-warm-up year, nonpositive governed economics, nondeterminism, formula or
oracle mismatch, current-month leakage, wrong regression orientation,
incorrect covariance weights/divisor, invalid fixed risk, missing stop, or
malformed lifecycle. Preserve negative evidence and do not tune this identity.

## Expected Behavior

The EA checks once per genuine broker month, usually follows the completed
twelve-month direction when the PP state permits, and can consume a month
flat. It never retries within a month, holds past the next month except for
repair latency, or scales exposure with statistic magnitude.

## Logging

Log normalized month key, endpoint keys/timestamps, OLS sums and coefficients,
residual energy, eleven autocovariances, `gamma0`, `lambda2`, `se_rho`, raw
tau, `pp_z_tau`, `mom12`, direction, ATR/stop, volume, magic, order result,
repair action, and exit reason. Never log credentials or external account
data.

## Framework Alignment

| card rule | module / implementation target |
|---|---|
| identity, risk/news/Friday/stress contract, month attempt, endpoints, and PP state | `Strategy_NoTradeFilter` plus bounded helpers |
| PP gate, momentum side, quote, spread, ATR, sizing, margin, order | `Strategy_EntrySignal` |
| malformed exposure, new-month, and forty-day repair | `Strategy_ManageOpenPosition` |
| lifecycle reason mapping | `Strategy_ExitSignal` plus framework close helper |
| both news axes off | `Strategy_NewsFilterHook` and framework initialization |

## Validation Plan

1. Match persistent-up, persistent-down, and mean-reverting independent
   vectors against the pinned oracle; prove additive-level invariance and
   inclusive boundary behavior.
2. Verify sixty endpoints, chronological orientation, 59 rows, intercept OLS,
   57 degrees of freedom, eleven Bartlett autocovariances, covariance divisor,
   PP correction, and all invalid/degenerate paths.
3. Verify attempt-before-fallible-gate semantics, fixed risk, hard stop,
   monthly exit, restart prevention, and malformed-position repair.
4. Lint the card, allocate registries, regenerate the resolver, compile under
   strict Q01 checks, and create exactly one fixed-risk preset.
5. Enqueue exactly one paced Q02 item only under a fresh below-ceiling CPU
   sample; do not dispatch or launch a tester manually.

## Safety Boundary

Authorized: deterministic identity/magic allocation, branch-only non-live
build, reference tests, strict Q01, one fixed-risk backtest set, and one paced
Q02 enqueue while capacity permits.

Forbidden: optimization, manual tester launch, live/demo/shadow/stress sets,
portfolio-gate edit, correlation waiver, portfolio admission, deploy/live
manifest, `T_Live`, AutoTrading, terminal control, or live use.

## Revision History

| version | date | reason | gate | verdict |
|---|---|---|---|---|
| v1 | 2026-09-03 | initial PP-HAC persistence-gated WTI trend card | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Source Approval | 2026-09-03 | APPROVED_SOURCE | `decisions/2026-09-03_wti_monthly_pp_persistence_trend_source_approval.md` |
| G0 Research Intake | 2026-09-03 | APPROVED | `decisions/2026-09-03_qm5_41320_wti_monthly_pp_persistence_trend_g0.md` |
| Q01 Build & Spec | TBD | PENDING | TBD |
| Q02 Baseline | TBD | NOT_ENQUEUED | TBD |
