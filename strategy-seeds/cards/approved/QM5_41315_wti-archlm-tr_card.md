---
card_schema_version: 2
type: strategy
strategy_id: ENGLE-STATSMODELS-MOP-WTI-ARCHLM-20260902_S01
variant_id: ENGLE-STATSMODELS-MOP-WTI-ARCHLM-20260902_S01
source_id: ENGLE-STATSMODELS-MOP-WTI-ARCHLM-20260902
ea_id: QM5_41315
slug: wti-archlm-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41315_wti-archlm-tr_card.md
execution_contract_status: APPROVED
created: 2026-09-02
created_by: Research+Development
last_updated: 2026-09-02
g0_status: APPROVED
g0_decision: decisions/2026-09-02_qm5_41315_wti_monthly_arch_lm_trend_g0.md
source_approval: decisions/2026-09-02_wti_monthly_arch_lm_trend_source_approval.md
source_author: QuantMechanica governed synthesis
source_authors: Robert F. Engle; statsmodels contributors; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen
source_citation: "QuantMechanica governed WTI conditional-variance-dependence synthesis; Engle (1982), Econometrica 50(4), DOI 10.2307/1912773; pinned statsmodels het_arch/acorr_lm implementation and tests; Moskowitz, Ooi, and Pedersen (2012), Journal of Financial Economics 104(2), DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: original_peer_reviewed_statistical_method
    citation: "Engle, R. F. (1982). Autoregressive Conditional Heteroscedasticity with Estimates of the Variance of United Kingdom Inflation. Econometrica 50(4), 987-1007."
    location: "DOI 10.2307/1912773; bibliographic attribution only"
    quality_tier: A_bibliographic
    role: original_arch_attribution
  - type: pinned_scientific_computing_implementation
    citation: "statsmodels contributors. statsmodels.stats.diagnostic.het_arch and acorr_lm; statsmodels.tsa.tsatools.lagmat."
    location: "GitHub commit 724510a0f1f1ab0ea79ab31e4bdd56df098f4f58; complete bounded functions and relevant verification tests read through public API"
    quality_tier: A_method
    role: residual_squaring_lag_alignment_ols_centered_r_squared_and_lm_formula
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: monthly_own_return_continuation_and_explicit_wti_membership
  - type: governed_composite_source
    citation: "QuantMechanica (2026). WTI monthly ARCH-LM volatility-clustering-gated trend."
    location: strategy-seeds/sources/ENGLE-STATSMODELS-MOP-WTI-ARCHLM-20260902/source.md
    quality_tier: governed_source
    role: exact_conjunction_boundary_risk_attempt_and_lifecycle
strategy_mechanic: monthly-wti-sixty-completed-log-returns-demeaned-normalized-squared-residuals-six-lag-intercept-ols-arch-lm-inclusive-473-gated-newest-twelve-month-continuation
sources:
  - "[[sources/ENGLE-STATSMODELS-MOP-WTI-ARCHLM-20260902]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/conditional-variance-dependence]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-log-return]]"
  - "[[indicators/arch-lm-statistic]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, conditional-variance-dependence, volatility-clustering, auxiliary-regression, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
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
magic: 413150000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately six completed WTI positions per full post-warm-up year; one consumed attempt per broker month. A fixed-seed market-free finite-sample null prior qualified 50.0665%. Q02 must prove at least five trades in every full scored year or retire."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_SYNTHESIS_BOUNDARY
r1_reasoning: "Peer-reviewed original attribution, complete pinned scientific implementation/lag alignment/tests, complete governed peer-reviewed WTI trading-paper read, and explicit disclosure that applying ARCH-LM to raw WTI monthly returns as a trend gate is untested QM synthesis."
r2_mechanical: PASS
r2_reasoning: "Month clock, 61 endpoints, 60 returns, demeaning, positive common squared-residual normalization, exact six-lag auxiliary OLS, centered R-squared, LM=54*R2, inclusive 4.73 pre-data gate, newest-12m direction, consumed attempt, fixed risk, stop, spread, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_reasoning: "Registered native XTIUSD.DWX D1 and MT5 state supply every runtime input; continuous-CFD roll, basis, financing, gap, and broker-month-label risks remain."
r4_ml_forbidden: PASS
r4_reasoning: "Only completed prices, timestamps, logarithms, sums, products, a fixed 7x7 linear solve, ATR risk, quotes, positions, deals, and persistent state; no trained output or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: 61 consecutive completed month-end closes; 60 adjacent log returns; arithmetic-mean residuals; residual-energy floor 1e-18; common positive square normalization; current rows t=6..59; intercept plus exact squared-residual lags 1..6; ordinary centered OLS R-squared; ddof zero; ARCH_LM=54*R2; inclusive LM floor 4.73; newest 12m direction epsilon 1e-12; 1800 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 frozen stop; 40-day stale exit; 1500-point spread ceiling."
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
review_focus: "Falsify a direct-WTI monthly squared-residual-dependence-gated continuation sleeve outside the certified XAU/SP500/NDX/XNG book. Verify endpoints, demeaning, common normalization, lag orientation, intercept-bearing OLS, centered R-squared, LM multiplier and inclusive boundary, newest-12m side, consumed month, fixed risk, frozen stop, and next-month lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_tradable_month_bar, sixty_one_consecutive_completed_months, no_current_month_price, sixty_adjacent_log_returns, chronological_return_orientation, arithmetic_mean_residuals, squared_residuals, common_positive_normalization, exact_current_rows_six_through_fifty_nine, exact_lags_one_through_six, intercept_bearing_ols, centered_r_squared, ddof_zero, lm_multiplier_fifty_four, inclusive_arch_lm_473, newest_twelve_month_continuation_side, monthly_attempt_state, fixed_risk, hard_stop_present, nonnegative_spread, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-09-02 and decisions/2026-09-02_qm5_41315_wti_monthly_arch_lm_trend_g0.md: R1-R4 pass within disclosed raw-return synthesis, auxiliary-regression, small-sample, and continuous-CFD risks. Corrected-root dedup returned CLEAN across 4,800 registry rows, 1,429 cards, and 45 Wiki nodes; manual review separates lag dependence in squared returns from daily GARCH forecasting, linear return portmanteau statistics, marginal distribution shape, volatility-of-volatility, scale shifts, pure momentum, calendar, event, channel, and certified XNG RSI families."
---

# QM5_41315 WTI Monthly ARCH-LM Volatility-Clustering-Gated Trend

## Hypothesis

WTI carries physical supply, storage, transport, refining, geopolitical,
hedging, and demand risks absent from the certified XAU, SP500, NDX, and XNG
carrier set. When sixty completed monthly WTI returns exhibit sufficiently
strong serial dependence in squared demeaned returns, the newest twelve-month
direction may persist for one more broker month.

This is a falsifiable direct-crude structural trend sleeve. It is not evidence
of a statistically significant ARCH effect, profitability, independence, or
decorrelation. Q02 owns cadence and baseline economics; unchanged Q09 alone
owns portfolio overlap.

## Source Traceability And Claim Boundary

The governed source is
`strategy-seeds/sources/ENGLE-STATSMODELS-MOP-WTI-ARCHLM-20260902/source.md`,
SHA-256
`910C3D4900A9732810C5A8799F60196F6AF869F29BF4315029FC63F26BBB923C`,
approved in commit `a122eb2029` before card extraction.

Engle supplies original attribution. The complete pinned statsmodels
implementation, lag constructor, and relevant verification tests fix the
exact method arithmetic. Moskowitz, Ooi, and Pedersen supply only WTI
membership and monthly own-return continuation. None tests this conjunction,
window, empirical boundary, CFD, fixed risk, costs, lifecycle, activity, or
portfolio fit. The blocked third-party Engle PDF mirror is excluded.

## Non-Duplicate Decision

The corrected-root fail-closed receipt
`artifacts/qm5_wti_archlm_tr_preallocation_dedup_20260902.json`, SHA-256
`40BBE77CFD0663E737FD81EDD50284933DAEFDFE5CABF6B5C3586AE251DE682A`,
returned `CLEAN` across 4,800 registry rows, 1,429 cards, and all 45 Strategy
Wiki nodes.

- `QM5_37008` forecasts daily GARCH variance recursively and trades a
  volatility cone breakout. This card fits no GARCH forecast and uses a
  monthly omnibus diagnostic only as a directionless gate.
- `QM5_41313` aggregates ordinary serial autocorrelations of return levels;
  this card uses an auxiliary regression of squared demeaned returns.
- `QM5_41314` measures marginal skewness/kurtosis and is invariant to return
  order; this card is explicitly order-dependent.
- `QM5_20298` measures volatility of volatility rather than lag dependence in
  squared monthly return residuals.
- Change-point, scale-shift, rank, entropy, pure trend, calendar, event,
  channel, and relative-value EAs operate on different state objects.
- Certified `QM5_12567` is a long-only two-day XNG oscillator pullback.

Verdict:
`CLEAN_WTI_MONTHLY_60_RETURN_ARCH_LM6_GE4P73_GATED_12M_CONTINUATION`.

## Markets, Timeframe, And Cadence

- Exact host and slot zero: `XTIUSD.DWX`, D1, governed magic `413150000`.
- Decision clock: first executable tick after a genuine broker-month change,
  within 180 elapsed minutes of the host D1 boundary.
- Formation: sixty-one consecutive completed broker-month-end closes;
  current-month prices are excluded.
- Hold: next broker month, with forty-calendar-day stale repair.
- Expected cadence: approximately six completed positions/year. Q02 retires
  any full scored post-warm-up year below five.

## Exact Formula

For chronological completed-month closes `C[0..60]`:

```text
r[i] = ln(C[i+1]/C[i]), i=0..59
mean = sum(r[i])/60
e[i] = r[i]-mean
energy = sum(e[i]^2)/60
v[i] = e[i]^2/energy

For t=6..59:
  y[t] = v[t]
  X[t] = [1, v[t-1], v[t-2], v[t-3], v[t-4], v[t-5], v[t-6]]

beta = argmin sum((y-X*beta)^2)
ybar = sum(y)/54
SST = sum((y-ybar)^2)
SSE = sum((y-X*beta)^2)
R2 = 1-SSE/SST
ARCH_LM = 54*R2
mom12 = sum(r[i], i=48..59)

BUY  iff ARCH_LM >= 4.73 and mom12 > +1e-12
SELL iff ARCH_LM >= 4.73 and mom12 < -1e-12
FLAT otherwise
```

Require positive finite closes, finite intermediate arithmetic,
`energy>1e-18`, a full-rank seven-column solve, `SST>1e-18`, and finite R2.
Only R2 roundoff inside `[-1e-10,1+1e-10]` may be clamped to `[0,1]`.
The common normalization improves numerical conditioning without changing
R2 in exact arithmetic. The gate is directionless; only `mom12` assigns side.

The inclusive `4.73` boundary is the rounded empirical median of a fixed-seed,
market-free sixty-observation Gaussian simulation. It is not a critical value
or p-value.

## Rules

- Consume the normalized broker month before history, signal, news, spread,
  quote, ATR, sizing, margin, or order gates. Never retry that month.
- Select the latest close in each immediately prior consecutive broker month
  from a bounded 1,800-D1 buffer.
- Reject current-month input, missing/duplicate/nonconsecutive month keys,
  nonchronological endpoints, nonpositive closes, a stale newest endpoint,
  invalid arithmetic, low residual energy, singular OLS state, low ARCH-LM,
  or neutral momentum.
- Permit neither foreign `XTIUSD.DWX` exposure nor existing owned exposure.
- Both news axes, legacy news, Friday close, and stress rejection are OFF.
- Q02 has one locked baseline and no optimization surface.

## 4. Entry Rules

1. Require EA ID 41315, exact `XTIUSD.DWX` D1, slot zero, magic 413150000,
   fixed-risk mode, framework defaults, and every strategy input locked.
2. Run lifecycle repair before entry-only gates.
3. Require a genuine new broker month inside the 180-minute entry window.
4. Persist the month attempt before every fallible gate.
5. Reconstruct exact endpoints and chronological log returns.
6. Apply exact demeaning, square normalization, lag alignment, intercept OLS,
   centered R-squared, `54*R2`, inclusive `4.73` gate, and newest-12m side.
7. Require spread in `[0,1500]`, valid quote/contract/tick/volume/margin
   metadata, and completed D1 ATR(20).
8. Open at most one position with a frozen `3.5*ATR` hard stop and no target,
   sized to the one fixed-dollar risk budget.

## 5. Exit Rules

1. Framework kill switch and broker hard stop remain authoritative.
2. Close on the first processed tick in a later broker month.
3. Close after forty elapsed calendar days as stale repair.
4. Close duplicate, wrong-symbol, invalid-type, wrong-side, missing-stop, or
   malformed entry-month exposure defensively.
5. There is no target, statistic exit, intramonth flip, Friday flatten,
   trail, break-even move, partial close, scale-in, grid, martingale, or
   pyramid.

## 6. Filters (No-Trade Module)

- Fail closed on wrong identity, symbol, period, slot, magic, seed, risk,
  news, Friday, stress, or locked strategy input.
- Fail closed on stale/nonconsecutive history, invalid closes/returns,
  residual energy, OLS rank/arithmetic, statistic, direction, prior attempt,
  spread, quote, ATR, sizing, or margin.
- Lifecycle handling precedes entry-only gates and does not depend on a new
  signal.
- Runtime may not use a futures curve, inventory, file, API, forecast,
  optimizer output, portfolio state, randomness, or trained artifact.

## 7. Trade Management Rules

- Exactly zero or one owned slot-zero WTI position is valid.
- Preserve the frozen broker hard stop and persisted entry-month state.
- Recompute the identical signal after restart when verifying expected side.
- Close at the next month, forty days, or malformed state. Do not resize,
  retry, partially close, scale in, or move the stop.

## Parameters To Test

Q02 has one locked baseline:

| parameter | value |
|---|---:|
| completed month-end closes / returns | 61 / 60 |
| residual center | arithmetic mean of all 60 returns |
| squared-residual conditioning | divide by positive mean square |
| auxiliary current rows | `t=6..59` (54 observations) |
| regressors | intercept plus lags 1..6 |
| fit | ordinary least squares, centered R-squared |
| degrees-of-freedom correction | zero |
| statistic | `ARCH_LM=54*R2` |
| qualification boundary | inclusive `ARCH_LM>=4.73` |
| direction | newest 12-month log-return sign |
| direction epsilon | `1e-12` |
| D1 history buffer | 1,800 bars |
| entry grace / endpoint staleness | 180 minutes / 10 days |
| ATR stop / stale hold | `3.5*ATR(20,D1)` / 40 days |
| spread ceiling | 1,500 points |

Changing any value creates a new variant and requires fresh evidence.

## Expected Behavior And Frequency

The fixed-seed market-free receipt, SHA-256
`277F824BDAAEEA5900A0C4F831A19AD9127FF765904EA47C4916CBE681E4BF0C`,
qualifies `50.0665%` of 200,000 independent standard-normal paths, or
`6.00798` states per twelve clocks. This is a cadence sanity check only, not
WTI evidence or a calibrated test size. Direction ties are probability zero
in that continuous null but still fail closed in runtime.

## Risk

Q02-Q08 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The broker stop is frozen at `3.5*ATR(20,D1)` and no
take-profit is attached. Gaps can exceed modeled stop risk. WTI's continuous
CFD adds roll, basis, financing, and broker-session risks.

The statistic uses only 54 auxiliary-regression rows against seven columns.
It can be noisy, ill-conditioned, dominated by roll discontinuities, or
persistently active because adjacent monthly windows overlap. Volatility
clustering need not imply return continuation, and the exact conjunction is
untested. Live risk is not authorized.

## Data Requirements

- Native `XTIUSD.DWX` D1 time/close history and closed D1 ATR values.
- Broker time/month, quotes, spread, symbol metadata, margin, position/deal
  state, and terminal globals for attempt and entry-state persistence.
- No external runtime source.

## Framework Execution Overrides

- `qm_news_temporal=QM_NEWS_TEMPORAL_OFF`.
- `qm_news_compliance=QM_NEWS_COMPLIANCE_NONE`.
- `qm_news_mode_legacy=QM_NEWS_OFF`.
- `qm_friday_close_enabled=false`.
- `qm_stress_reject_probability=0` in the canonical baseline.
- Kill-switch, weekend, broker-disconnect, and hard-stop coverage remain
  active.

## Exit Precedence

1. Kill switch / broker hard stop.
2. Malformed position or missing entry-month state repair.
3. Next genuine broker-month exit.
4. Forty-day stale exit.
5. No other strategy or framework calendar exit.

## Runtime Data Dependencies

- Tester host `XTIUSD.DWX`, D1, account currency USD, deposit 100,000.
- Q02 uses the active governed IS window and Model 4; pre-window history must
  supply the sixty-one-month formation where the custom archive permits it.
- MT5-native history/execution state only; no external API, file, future bar,
  trained artifact, inventory series, or curve data.

## Reputable-Source Gate Findings

- R1: PASS with disclosed synthesis and inaccessible-body boundaries.
- R2: PASS with exact deterministic signal, risk, and lifecycle rules.
- R3: PASS on registered native WTI D1, with explicit CFD transport risks.
- R4: PASS with bounded deterministic native arithmetic.

## Failure Modes And Kill Criteria

Retire or fail closed on formula/reference mismatch, wrong return or lag
orientation, omitted intercept, uncentered R-squared, wrong LM multiplier,
boundary or direction error, zero positions, fewer than five positions in any
full post-warm-up year, nonpositive governed economics, missing stop, invalid
fixed-risk mode, nondeterminism, lifecycle deviation, or any downstream gate
failure. No post-result parameter repair is authorized.

## Execution And State Contract

- Persist one normalized month attempt before all fallible entry gates.
- Persist entry month only after confirmed fill and recover it from owned
  position/deal history if terminal state is lost.
- Use framework checked-magic, risk sizing, price/volume normalization, and
  governed order helpers. Never compute a runtime magic value by hand.
- Emit structured signal and lifecycle diagnostics without credentials.

## Portfolio Interaction

Direct WTI introduces crude-oil exposure absent from the certified carrier
set and uses neither the incumbent XNG cumulative-RSI logic nor a metal/index
carrier. The conditional-variance-dependence gate is mechanically distinct
from existing WTI gates. This is a diversification hypothesis only. Q09 must
measure realized correlation and may reject it without a waiver.

## Validation Plan

1. Reference-test endpoint/return orientation, demeaning, normalization, lag
   rows, normal equations, centered R-squared, LM value, and direction.
2. Prove scale invariance and that return permutation can change ARCH-LM while
   leaving the marginal distribution unchanged.
3. Prove inclusive `4.73`, neutral direction, low energy, singular OLS, stale
   endpoint, and nonconsecutive month behavior.
4. Prove attempt persistence occurs before every fallible entry gate.
5. Prove fixed-dollar risk, hard stop, next-month close, stale repair, and
   malformed-position repair.
6. Compile strictly, pass the deterministic build checker, then enqueue one
   append-only Q02 row without manually launching a tester.

## Framework Alignment

- `Strategy_NoTradeFilter`: exact identity, slot, registered magic, fixed
  risk, news/Friday/stress contract, host symbol/timeframe, and parameter
  locks.
- bounded helpers: month clock, attempt persistence, endpoint reconstruction,
  demeaning, squared normalization, OLS/LM computation, direction, and
  restart recovery.
- `Strategy_EntrySignal`: exposure, spread, quote, ATR, fixed-risk sizing,
  frozen stop, and one market request.
- `Strategy_ManageOpenPosition`: malformed-state repair, side verification,
  next-month close, and forty-day stale close.
- `Strategy_ExitSignal`: no discretionary signal; management owns card exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-09-02 | initial WTI ARCH-LM trend card | Q00 | APPROVED; build pending |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| Q00 Source Approval | 2026-09-02 | APPROVED_SOURCE | `decisions/2026-09-02_wti_monthly_arch_lm_trend_source_approval.md` |
| Q00 Research Intake | 2026-09-02 | APPROVED | `decisions/2026-09-02_qm5_41315_wti_monthly_arch_lm_trend_g0.md` |
| Q01 Build & Spec | pending | NOT_BUILT | branch-only build required |
| Q02 Baseline | pending | NOT_ENQUEUED | Q01 PASS required |
