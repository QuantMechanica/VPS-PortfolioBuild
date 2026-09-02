---
card_schema_version: 2
type: strategy
strategy_id: KWIATKOWSKI-STATSMODELS-MOP-WTI-KPSS-20260902_S01
variant_id: KWIATKOWSKI-STATSMODELS-MOP-WTI-KPSS-20260902_S01
source_id: KWIATKOWSKI-STATSMODELS-MOP-WTI-KPSS-20260902
ea_id: QM5_41317
slug: wti-mkpss-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41317_wti-mkpss-tr_card.md
execution_contract_status: APPROVED
created: 2026-09-02
created_by: Research+Development
last_updated: 2026-09-02
g0_status: APPROVED
g0_decision: decisions/2026-09-02_qm5_41317_wti_monthly_kpss_trend_g0.md
source_approval: decisions/2026-09-02_wti_monthly_kpss_trend_source_approval.md
source_author: QuantMechanica governed synthesis
source_authors: Denis Kwiatkowski; Peter C. B. Phillips; Peter Schmidt; Yongcheol Shin; statsmodels contributors; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen
source_citation: "QuantMechanica governed WTI KPSS synthesis; Kwiatkowski, Phillips, Schmidt, and Shin (1992), Journal of Econometrics 54, DOI 10.1016/0304-4076(92)90104-Y; pinned statsmodels KPSS implementation and tests; Moskowitz, Ooi, and Pedersen (2012), Journal of Financial Economics 104(2), DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: original_peer_reviewed_statistical_method
    citation: "Kwiatkowski, D., Phillips, P. C. B., Schmidt, P., and Shin, Y. (1992). Testing the Null Hypothesis of Stationarity against the Alternative of a Unit Root. Journal of Econometrics 54, 159-178."
    location: "DOI 10.1016/0304-4076(92)90104-Y; attribution, null, equations, and Table-1 critical-value identity through pinned implementation"
    quality_tier: A_bibliographic
    role: original_kpss_attribution
  - type: pinned_scientific_computing_implementation
    citation: "statsmodels contributors. statsmodels.tsa.stattools KPSS implementation and upstream TestKPSS record."
    location: "GitHub commit 2d1115dbd648b1e120a7e7454479d46481a73a9a; complete bounded implementation definitions and complete test module read through public API"
    quality_tier: A_method
    role: exact_residual_partial_sum_long_run_variance_and_critical_value_formula
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: monthly_own_return_continuation_and_explicit_wti_membership
  - type: governed_composite_source
    citation: "QuantMechanica (2026). WTI monthly KPSS nonstationarity-gated trend."
    location: strategy-seeds/sources/KWIATKOWSKI-STATSMODELS-MOP-WTI-KPSS-20260902/source.md
    quality_tier: governed_source
    role: exact_conjunction_boundary_risk_attempt_and_lifecycle
strategy_mechanic: monthly-wti-sixty-completed-log-price-levels-constant-only-kpss-fixed-four-lag-bartlett-newey-west-inclusive-ten-percent-critical-gated-newest-twelve-month-continuation
sources:
  - "[[sources/KWIATKOWSKI-STATSMODELS-MOP-WTI-KPSS-20260902]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/level-stationarity]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-log-price]]"
  - "[[indicators/kpss-statistic]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, stationarity-test, long-run-variance, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
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
magic: 413170000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "At most twelve completed WTI positions per full post-warm-up year; planning prior approximately six to ten because KPSS qualification is uncalibrated. One consumed attempt per broker month. Q02 must prove at least five trades in every full scored year or retire."
expected_trades_per_year_per_symbol: 8
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_SYNTHESIS_BOUNDARY
r1_reasoning: "Peer-reviewed original attribution, complete pinned scientific implementation and upstream tests, complete governed peer-reviewed WTI trading-paper read, and explicit disclosure that applying constant-only KPSS to monthly WTI log levels as a trend gate is untested QuantMechanica synthesis."
r2_mechanical: PASS
r2_reasoning: "Month clock, 60 endpoints, log orientation, demeaning, partial sums, fixed four lags, Bartlett weights, long-run variance, inclusive source critical value, newest-12m direction, consumed attempt, fixed risk, stop, spread, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_reasoning: "Registered native XTIUSD.DWX D1 and MT5 state supply every runtime input; continuous-CFD roll, basis, financing, gap, and broker-month-label risks remain."
r4_ml_forbidden: PASS
r4_reasoning: "Only completed prices, timestamps, logarithms, sums, products, comparisons, bounded loops, ATR risk, quotes, positions, deals, and persistent state; no trained output, banned signal indicator, or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: 60 consecutive completed month-end closes; natural-log levels; constant-only mean residuals; 60 partial sums; eta=sum(partial_sum^2)/3600; fixed covariance lags=4; Bartlett weights 0.8/0.6/0.4/0.2; Newey-West long-run variance; residual-energy and long-run-variance floors 1e-18; inclusive KPSS floor 0.347; newest 12m direction epsilon 1e-12; 1800 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 frozen stop; 40-day stale exit; 1500-point spread ceiling."
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
review_focus: "Falsify a direct-WTI monthly log-level nonstationarity-gated continuation sleeve outside the certified XAU/SP500/NDX/XNG book. Verify endpoint/log orientation, constant-only residuals, partial sums, eta, fixed lag-four Bartlett/Newey-West denominator, inclusive boundary, newest-12m side, consumed month, fixed risk, frozen stop, and next-month lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_tradable_month_bar, sixty_consecutive_completed_months, no_current_month_price, chronological_log_level_orientation, constant_only_kpss, partial_sum_eta, fixed_four_lag_bartlett_newey_west_variance, positive_long_run_variance, inclusive_critical_boundary, newest_twelve_month_continuation_side, monthly_attempt_state, fixed_risk, hard_stop_present, nonnegative_spread, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-09-02 and decisions/2026-09-02_qm5_41317_wti_monthly_kpss_trend_g0.md: R1-R4 pass within disclosed statistical-test synthesis, finite-sample/lag-choice, and continuous-CFD risks. Corrected-root dedup returned CLEAN across 4,802 registry rows, 1,431 cards, and 45 Wiki nodes; manual review separates cumulative log-level residual geometry from return autocorrelation, squared-return ARCH-LM, delay-vector BDS, marginal shape, entropy, variance ratio, pure momentum, calendar, event, channel, and certified XNG RSI families."
---

# QM5_41317 WTI Monthly KPSS Nonstationarity-Gated Trend

## Hypothesis

WTI carries physical supply, storage, transport, refining, geopolitical,
hedging, and demand risks absent from the certified XAU, SP500, NDX, and XNG
carrier set. When sixty completed monthly WTI log-price levels reject a
constant level-stationarity null under the locked KPSS statistic, the newest
twelve-month direction may persist for one more broker month.

This is a falsifiable direct-crude structural trend sleeve. A KPSS rejection
does not prove a unit root, integration order, trend, predictability,
profitability, or decorrelation. Q02 owns cadence and baseline economics;
unchanged Q09 alone owns portfolio overlap.

## Source Traceability And Claim Boundary

The governed source is
`strategy-seeds/sources/KWIATKOWSKI-STATSMODELS-MOP-WTI-KPSS-20260902/source.md`,
SHA-256
`484F927088FCA0A01E4332B289A6A195A29152FDDE3BF08D7FD47CD8D86BEAD9`,
approved in commit `c427499127` before card extraction.

Kwiatkowski et al. supply original attribution. The complete bounded pinned
statsmodels implementation and complete test module fix the arithmetic and
critical-value record. Moskowitz, Ooi, and Pedersen supply only WTI membership
and monthly own-return continuation. None tests this conjunction, window, lag,
CFD, fixed risk, costs, lifecycle, activity, or portfolio fit.

## Non-Duplicate Decision

The corrected-root fail-closed receipt
`artifacts/qm5_wti_mkpss_tr_preallocation_dedup_20260902.json`, SHA-256
`1DF4B584404A2CA3DE33B7D4812119DE7CB74248774FEFDD6A8AEB88D564AD69`,
returned `CLEAN` across 4,802 registry rows, 1,431 cards, and all 45 Strategy
Wiki nodes.

- Ljung-Box measures return autocorrelation; KPSS accumulates demeaned
  log-price-level residuals and normalizes by long-run variance.
- ARCH-LM measures lag dependence of squared returns; KPSS does neither.
- BDS counts close delay vectors; KPSS has no distance matrix or embedding.
- entropy and Jarque-Bera systems measure complexity or marginal shape;
  robust-block, variance-ratio, calendar, event, channel, and pure momentum
  families use different state objects.
- Certified `QM5_12567` is a long-only two-day XNG oscillator pullback.

Verdict:
`CLEAN_WTI_MONTHLY_60_LOG_LEVEL_KPSS_C_LAG4_GE_0P347_GATED_12M_CONTINUATION`.

## Markets, Timeframe, And Cadence

- Exact host and slot zero: `XTIUSD.DWX`, D1, governed magic `413170000`.
- Decision clock: first executable tick after a genuine broker-month change,
  within 180 elapsed minutes of the host D1 boundary.
- Formation: sixty consecutive completed broker-month-end closes; no
  current-month price.
- Hold: next broker month, with forty-calendar-day stale repair.
- Expected cadence: at most twelve and planning-prior six to ten completed
  positions/year. Q02 retires any full scored post-warm-up year below five.

## Exact Formula

For chronological completed-month closes `C[0..59]`, form `x[t]=ln(C[t])`.
Let `n=60`, `L=4`, `mean_x=sum(x)/60`, residual `e[t]=x[t]-mean_x`, and
cumulative residual `S[t]=sum(e[j],j=0..t)`.

```text
eta = sum(S[t]^2, t=0..59) / 3600
cross[k] = sum(e[t]*e[t-k], t=k..59), k=1..4
weight[k] = 1-k/5
s_hat = (sum(e[t]^2)+2*sum(weight[k]*cross[k],k=1..4))/60
KPSS = eta/s_hat
mom12 = x[59]-x[47]

BUY  iff KPSS >= 0.347 and mom12 > +1e-12
SELL iff KPSS >= 0.347 and mom12 < -1e-12
FLAT otherwise
```

Require finite positive closes, finite levels/residuals/partial sums, residual
energy above `1e-18`, `eta>=0`, and `s_hat>1e-18`. The statistic sign and
magnitude never assign side or alter risk. No p-value is interpolated.

## Rules

- Consume the normalized broker month before history, signal, news, spread,
  quote, ATR, sizing, margin, or order gates. Never retry that month.
- Select the latest close in each immediately prior consecutive broker month
  from a bounded 1,800-D1 buffer.
- Reject current-month input, missing/duplicate/nonconsecutive month keys,
  nonchronological endpoints, nonpositive closes, stale newest endpoint,
  invalid arithmetic, nonpositive long-run variance, low KPSS, or neutral
  momentum.
- Permit neither foreign `XTIUSD.DWX` exposure nor existing owned exposure.
- Both news axes, legacy news, Friday close, and stress rejection are OFF.
- Q02 has one locked baseline and no optimization surface.

## Entry Rules

1. Require EA ID 41317, exact `XTIUSD.DWX` D1, slot zero, magic 413170000,
   fixed-risk mode, framework defaults, and every strategy input locked.
2. Run lifecycle repair before entry-only gates.
3. Require a genuine new broker month inside the 180-minute entry window.
4. Persist the month attempt before every fallible gate.
5. Reconstruct the exact sixty endpoints and chronological log levels.
6. Apply exact constant-only KPSS arithmetic, inclusive gate, and newest
   twelve-month continuation side.
7. Require spread in `[0,1500]`, valid quote/contract/tick/volume/margin
   metadata, and completed D1 ATR(20).
8. Open at most one position with a frozen `3.5*ATR` hard stop and no target,
   sized to the one fixed-dollar risk budget.

## Exit Rules

1. Framework kill switch and broker hard stop remain authoritative.
2. Close on the first processed tick in a later broker month.
3. Close after forty elapsed calendar days as stale repair.
4. Close duplicate, wrong-symbol, invalid-type, wrong-side, missing-stop, or
   malformed entry-month exposure defensively.
5. There is no target, statistic exit, intramonth flip, Friday flatten, trail,
   break-even move, partial close, scale-in, grid, martingale, or pyramid.

## Filters And Trade Management Rules

Fail closed on wrong identity, symbol, period, slot, magic, risk/news/Friday/
stress contract, stale/nonconsecutive history, any invalid KPSS component,
prior attempt/deal, spread, quote, ATR, sizing, or margin. Lifecycle handling
precedes entry-only gates. Preserve the frozen broker stop and entry-month
state; never resize or retry.

## Parameters To Test

Q02 has exactly one locked baseline: sixty month-end closes, natural-log
levels, constant-only demeaning, fixed lag four, Bartlett weights, two numeric
floors, inclusive critical value `0.347`, newest twelve-month direction, 1,800
D1 history bars, 180-minute grace, ten-day endpoint staleness,
`3.5*ATR(20)` stop, forty-day stale hold, and 1,500-point spread ceiling.
Changing any value creates a new variant and needs fresh evidence.

## Expected Behavior And Frequency

The non-market arithmetic fixture, SHA-256
`F8A08B4B4777676EAA59D173F0579CC38D4C131BB7781C1AF4F2042F3EDF9411`,
proves the implemented state divider can both abstain and qualify. It is not a
frequency estimate. The planning prior is six to ten positions per year, with
twelve attempts. Q02 must measure actual completed positions and retire below
five in any full scored post-warm-up year.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The broker stop is frozen at `3.5*ATR(20,D1)` and no
take-profit is attached. Gaps can exceed modeled stop risk. WTI's continuous
CFD adds roll, basis, financing, and broker-session risks. KPSS finite-sample
size depends on serial structure and lag choice; overlapping monthly windows
are dependent. The continuation conjunction is untested. Live risk is not
authorized.

## Data Requirements

Native `XTIUSD.DWX` D1 time/close history and closed D1 ATR values; broker
time/month, quotes, spread, symbol metadata, margin, position/deal state, and
terminal globals. No external runtime source, file, forecast, curve, inventory
series, optimizer output, or trained artifact is allowed.

## Framework Execution Overrides

- `qm_news_temporal=QM_NEWS_TEMPORAL_OFF`.
- `qm_news_compliance=QM_NEWS_COMPLIANCE_NONE`.
- `qm_news_mode_legacy=QM_NEWS_OFF`.
- `qm_friday_close_enabled=false`.
- `qm_stress_reject_probability=0` in the canonical baseline.
- Kill-switch, weekend, broker-disconnect, and hard-stop coverage stay active.

## Failure Modes And Kill Criteria

Retire or fail closed on formula/fixture mismatch, wrong endpoint or log-level
orientation, wrong demeaning, partial-sum or long-run-variance error, any lag
other than four, boundary/direction error, zero positions, fewer than five
positions in any full post-warm-up year, nonpositive governed economics,
missing stop, invalid fixed-risk mode, nondeterminism, lifecycle deviation, or
any downstream gate failure. No post-result parameter repair is authorized.

## Framework Alignment

| card rule | module |
|---|---|
| identity, risk/news/Friday contract, month attempt, endpoints and KPSS state | `Strategy_NoTradeFilter` and bounded helpers |
| quote, spread, ATR, fixed-risk size, one WTI order | `Strategy_EntrySignal` |
| restart recovery, side validation, next-month and forty-day repair | `Strategy_ManageOpenPosition` |
| broker/framework reason mapping | `Strategy_ExitSignal` and V5 close helper |

## Validation Plan

1. Match independent fixture arithmetic; prove additive log-level invariance,
   fixed lag/weights, partial sums, denominator, boundary, direction, and
   degenerate failure.
2. Run card schema lint and strict Q01 compile/build checks.
3. Enqueue one canonical `RISK_FIXED` Q02 item only if CPU admission is clear.
4. Preserve any zero-trade, activity, or economic failure without changing the
   locked rule.

## Safety Boundary

Authorized: deterministic magic allocation, branch-only non-live build,
reference tests, strict Q01, one fixed-risk backtest set, and one paced Q02
enqueue below the whole-host CPU ceiling.

Forbidden: optimization, manual tester launch, live/demo/shadow/stress sets,
portfolio-gate edit, correlation waiver, portfolio admission, deploy/live
manifest, `T_Live`, AutoTrading, terminal control, or live use.

## Revision History

| version | date | reason | gate | verdict |
|---|---|---|---|---|
| v1 | 2026-09-02 | initial WTI KPSS trend card | G0 | APPROVED; build pending |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Source Approval | 2026-09-02 | APPROVED_SOURCE | `decisions/2026-09-02_wti_monthly_kpss_trend_source_approval.md` |
| G0 Research Intake | 2026-09-02 | APPROVED | `decisions/2026-09-02_qm5_41317_wti_monthly_kpss_trend_g0.md` |
| Q01 Build & Spec | TBD | PENDING | TBD |
| Q02 Baseline | TBD | NOT_ENQUEUED | TBD |
