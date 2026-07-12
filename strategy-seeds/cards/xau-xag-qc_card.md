---
strategy_id: SCHWEIKERT-QC-2018_XAU_XAG_S01
source_id: SCHWEIKERT-QC-2018
ea_id: QM5_13205
slug: xau-xag-qc
status: APPROVED
created: 2026-07-12
created_by: Research
last_updated: 2026-07-12
g0_status: APPROVED
source_citations:
  - type: peer_reviewed_paper
    citation: "Schweikert, Karsten (2018). Are gold and silver cointegrated? New evidence from quantile cointegrating regressions. Journal of Banking & Finance 88, 44-51."
    location: "Complete 32-page author preprint; especially pp. 2-5, 10-25, Equations 3 and 9-12, daily spot/futures Section 4.2, and conclusion; DOI https://doi.org/10.1016/j.jbankfin.2017.11.010; preprint https://karstenschweikert.github.io/qcoint/qcoint_20171121_preprint.pdf"
    quality_tier: A
    role: primary
strategy_type_flags: [symmetric-long-short, atr-hard-stop, signal-reversal-exit, time-stop]
markets: [commodities, precious_metals]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_13205_XAU_XAG_QC_D1
period: D1
expected_trade_frequency: "Weekly D1 conditional-quantile envelope decisions; approximately 6-12 completed XAU/XAG packages/year after 505 synchronized completed bars, before Q02 validation."
expected_trades_per_year_per_symbol: 8
expected_pf: 1.01
expected_dd_pct: 25.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
review_focus: "Strictly falsify a state-dependent XAU/XAG conditional-quantile envelope. Exact constrained check-loss regression, quantile-varying slopes, the beta-asymmetry gate, source adverse evidence, beta-target notional sizing, and one logical basket are load-bearing."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [basket_execution, friday_close, magic_schema, risk_mode_dual, cfd_futures_basis, low_frequency, quantile_solver]
g0_approval_reasoning: "APPROVED under OWNER commodity-sleeve mission: R1 single peer-reviewed JBF source with DOI/full preprint; R2 fixed past-only three-quantile asymmetric check-loss envelope, explicit paired entry/median/time/hard-stop exits; R3 native XAU/XAG D1; R4 deterministic, no ML/banned/external/grid/martingale"
---

# XAU/XAG State-Dependent Quantile Envelope

## Hypothesis

Gold and silver share investment and safe-haven demand, while silver retains
more industrial-demand exposure. The source finds that their long-run response
is state-dependent rather than governed by one constant hedge coefficient.
This card tests whether an out-of-formation silver price beyond a mechanically
estimated conditional-quantile envelope subsequently returns toward its
conditional median in a two-leg relative-value package.

The desired book effect is reduced outright XAU/index direction, not a claimed
correlation result. Opposite legs and a quantile-beta risk ratio do not
guarantee dollar, beta, volatility, or realized market neutrality. Only a
later portfolio gate may measure correlation after this edge survives its own
pipeline.

## Source and evidence boundary

The sole source is Schweikert (2018), *Journal of Banking & Finance* 88,
DOI `10.1016/j.jbankfin.2017.11.010`. The complete author preprint was read.
It models quantile-specific intercepts and slopes with asymmetric check loss
and finds a nonlinear, asymmetric, time- and state-dependent gold/silver
relationship in monthly and daily spot and futures data.

The paper is adverse evidence for easy spread trading. A constant linear
vector fails important tests, some daily upper quantiles reject quantile
cointegration, exact state is not known ex ante, and the conclusion warns that
a constant-coefficient statistical-arbitrage spread is risky. The bounded
author statement that a cointegrated portfolio could be "a suitable long-term
hedge" motivates the paired carrier; no source return, drawdown, correlation,
or forecasting claim is imported.

## Quantile estimator

On the first tradable `XAUUSD.DWX` D1 bar of broker month `m`, load exactly 505
synchronized completed positive XAU/XAG D1 closes. The newest pair is the
out-of-formation signal observation; the older 504 pairs form the estimator
sample. Current forming bars are excluded. Freeze the fitted lines for that
broker month and evaluate their predictions on the newest completed pair at
the first tradable D1 bar of each broker week. After a mid-month
reinitialization, reconstruct the same frozen model by anchoring the history
window at the first host D1 bar of that month; never slide the formation
endpoint to the restart date.

Define `x_i = ln(XAU_i)` and `y_i = ln(XAG_i)`. For each locked
`tau in {0.10, 0.50, 0.90}`, estimate:

```text
y_i = alpha_tau + beta_tau * x_i + u_i
rho_tau(u) = tau * u             when u >= 0
             (tau - 1) * u       when u < 0
(alpha_tau, beta_tau) = argmin sum_i rho_tau(u_i)
```

For a candidate beta, the minimizing alpha is the empirical tau-quantile of
`y_i - beta*x_i`. For a linear quantile regression with intercept and slope,
a constrained optimum occurs at a pairwise observation slope or a beta bound.
Build the sorted unique candidates `(y_i-y_j)/(x_i-x_j)` inside
`[0.25, 3.00]`, add both bounds, and binary-search the convex profiled
check-loss sequence. Ties choose the smaller beta. This is an exact
constrained native-MQL two-parameter quantile-regression solve to double
precision under general position, not OLS, an OLS-residual percentile, Kalman
filtering, ML, or adaptive PnL fitting.

At signal `x_0`, compute `q_tau = alpha_tau + beta_tau*x_0` and require:

- all coefficients and predictions finite;
- all three betas strictly inside the locked beta bounds;
- `q_10 < q_50 < q_90` at the signal XAU price and at the minimum and maximum
  formation XAU log prices, preventing conditional-line crossings inside the
  observed domain;
- `tail_width = q_90 - q_10 >= 0.010` log-price units;
- source-consistent but QM-defined asymmetry
  `beta_90 > beta_10 + 0.05`.

Any failed estimator, boundary solution, unordered envelope, narrow IQR, or
missing asymmetry is a no-trade state. It is not repaired with a fixed ratio.

## 4. Entry Rules

- Evaluate entries only on the first new host D1 bar of each broker week.
- Require exact host `XAUUSD.DWX`, D1, magic slot 0, and a signal endpoint no
  more than ten calendar days before the decision bar.
- Upper-envelope signal: if
  `ln(XAG_signal) > q_90 + 0.00 * tail_width`, SELL XAG and BUY XAU. Target
  XAU:XAG dollar notionals of `beta_90:1`.
- Lower-envelope signal: if
  `ln(XAG_signal) < q_10 - 0.00 * tail_width`, BUY XAG and SELL XAU. Target
  XAU:XAG dollar notionals of `beta_10:1`.
- Do not trade inside the envelope, on exact thresholds, after an invalid
  solve, with an existing package, or after an entry attempt in the same
  broker week.
- Persist the attempted broker-week key before submitting either leg. Position
  and deal history are secondary recovery evidence, so a restart cannot retry
  a package whose orders were both rejected.
- Require valid ATR, spread, tick/lot metadata, two active magic mappings, and
  sufficient per-leg volume after rounding.
- Convert the target notional ratio to a lot ratio with current positive
  prices and contract sizes. Scale both lots against their framework
  full-budget ATR-stop capacities so the combined frozen-stop loss is no more
  than one `RISK_FIXED` package; round both down to broker volume steps.
- Attach a frozen `ATR(20) * 4.0` hard stop to each leg. If the second order
  fails, flatten the first immediately.

## 5. Exit Rules

- Refit the three quantile lines on each first tradable D1 bar of a new broker
  month using only prior completed data; use the frozen monthly lines for each
  weekly median-cross evaluation.
- For long residual (BUY XAG / SELL XAU), close both legs when the newest
  completed `ln(XAG)` is at or above the fitted conditional median `q_50`.
- For short residual (SELL XAG / BUY XAU), close both legs when the newest
  completed `ln(XAG)` is at or below `q_50`.
- Close both legs after `strategy_max_hold_days=70` even if no median cross.
- If either hard stop removes one leg, flatten the orphan immediately.
- Flatten duplicate, same-side, wrong-symbol, or wrong-magic compositions.
- Friday close is disabled only to preserve the multiweek structural hold.

## 6. Filters (No-Trade Module)

- Framework kill switch remains first and authoritative.
- Exact host/slot, bounded synchronized completed history, endpoint freshness,
  beta bounds, candidate-slope solver, quantile set, coefficient finiteness,
  boundary solution, envelope ordering, minimum tail width, beta asymmetry, spread, ATR, lot,
  weekly attempt, magic, and package checks fail closed.
- News compliance gates new entries for both legs; lifecycle management,
  median/time exits, and orphan cleanup remain active. Q02 disables both news
  axes.
- Unauthorized inputs block model work and new risk but do not bypass orphan,
  composition, or time-stop management of an existing package.

## 7. Trade Management Rules

- One two-leg package at a time. No TP, trail, break-even, partial close,
  scale-in, grid, martingale, pyramiding, external feed, banned indicator, ML,
  or PnL-adaptive parameter.

## Parameters to test

| parameter | default | authorized range | role |
|---|---:|---|---|
| `strategy_formation_bars` | 504 | [504] | locked prior completed formation pairs |
| `strategy_history_bars` | 700 | [650, 700, 800] | bounded synchronization buffer only |
| `strategy_beta_min` | 0.25 | [0.25] | locked QR slope lower bound |
| `strategy_beta_max` | 3.00 | [3.00] | locked QR slope upper bound |
| `strategy_slope_unique_epsilon` | 1e-10 | [1e-10] | pairwise-slope de-duplication tolerance |
| `strategy_min_beta_span` | 0.05 | [0.05] | QM-defined source-consistent asymmetry floor |
| `strategy_min_band_width` | 0.010 | [0.010] | degenerate 10%-90% envelope guard |
| `strategy_entry_band_mult` | 0.00 | [0.00, 0.10, 0.25] | distance beyond conditional tail boundary |
| `strategy_max_endpoint_gap_days` | 10 | [7, 10] | completed endpoint freshness |
| `strategy_atr_period_d1` | 20 | [14, 20, 30] | hard-stop volatility estimate |
| `strategy_atr_sl_mult` | 4.0 | [3.0, 4.0, 5.0] | frozen per-leg stop distance |
| `strategy_max_hold_days` | 70 | [42, 70] | stale structural hold guard |
| `strategy_xau_max_spread_pts` | 1500 | [1000, 1500, 2500] | XAU entry spread cap |
| `strategy_xag_max_spread_pts` | 500 | [300, 500, 800] | XAG entry spread cap |
| `strategy_max_hedge_error_pct` | 20.0 | [10.0, 20.0, 30.0] | post-rounding beta-notional error cap |
| `strategy_deviation_points` | 20 | [10, 20, 50] | basket order deviation |

The 504-pair formation, out-of-formation signal, 10/50/90 taus, asymmetric
check-loss objective, exact constrained pairwise-slope solve, conditional envelope,
positive beta-span gate, beta-target notional ratio, paired directions, monthly refit,
weekly cadence, and median exit
are locked. Replacing them with OLS, a fixed beta, z-score, raw ratio,
correlation, channel, stochastic, Kalman, or return-spread rule creates a
duplicate or a new strategy and requires a new card.

## Initial risk profile and kill criteria

- `expected_pf: 1.01` is a near-null queue-ordering prior, not evidence.
- `expected_dd_pct: 25.0` reflects source non-forecastability, unstable state,
  XAG gaps, two-CFD basis, financing, legging, and narrow-pair risk.
- Expected density is 6-12 completed packages/year after warm-up. Retire below
  five completed packages/year under the binding Q02 floor.
- Fail Q02 on zero trades, logical-basket accounting errors,
  nondeterministic reruns, invalid check-loss state, persistent orphans, risk
  mismatch, or any standalone-leg evaluation.
- Do not reduce the check-loss estimator to OLS, invert the QM-defined
  beta-span gate, loosen bounds after seeing results, add an outright XAU/XAG
  trend filter, or change direction to rescue a weak baseline.

## Strategy allowability check

- [x] Mechanical, structural conditional-quantile relative-value hypothesis.
- [x] Exactly one Tier-A peer-reviewed primary source with DOI and full text.
- [x] No banned indicator, ML, external runtime feed, adaptive PnL fit, grid,
      martingale, or pyramiding.
- [x] D1/weekly expected density exceeds the five-package/year Q02 floor.
- [x] Backtest uses RISK_FIXED only; no live setfile is authorized.
- [x] Source adverse findings and QM-mechanization boundary are explicit.
- [x] Exact/current/all-history dedup is clean for check-loss conditional
      quantile regression.

## Non-duplicate decision

- `QM5_12577`: fixed-beta log-ratio z-score fade.
- `QM5_12862`: fixed-beta return-spread z-score fade.
- `QM5_12724`: fixed-beta log-ratio channel continuation.
- `QM5_1083` / `QM5_11241`: rolling OLS residual, z-score, and half-life.
- `QM5_11246`: dynamic Kalman beta and forecast-error bands.
- `QM5_1256`: ratio stochastic plus correlation.
- `QM5_1334`: fixed-beta mean/max-deviation envelope.
- `QM5_12019`: registry-only unrelated GARCH-quantile reservation; no build.

No existing or historical code/card/source uses tau-specific alpha/beta from
asymmetric check loss. Verdict: `CLEAN_PRE_ALLOCATION`, conditional on that
mechanic remaining load-bearing.

## Framework alignment

- no_trade: exact host/slot, bounded synchronized history, endpoint freshness,
  solver domain, finite coefficients, interior optima, ordered envelope, tail width,
  beta-span, spread, ATR, lot, weekly-attempt, magic, and package guards.
- trade_entry: weekly upper/lower conditional-quantile envelope breach,
  opposite XAU/XAG orders, beta-target notionals jointly scaled to one fixed-risk package, frozen ATR stops,
  and immediate legging repair.
- trade_management: weekly conditional-median exit, 70-day time stop,
  composition validation, restart-safe deal guard, and orphan cleanup.
- trade_close: framework close helper plus broker hard stops.

No T_Live, AutoTrading setting, live setfile, deploy manifest, T_Live
manifest, portfolio gate, portfolio admission, or portfolio KPI path is
authorized.

## QM Mechanization Versus Source

Schweikert estimates price levels over long/full samples with lead/lag
augmentation or fully-modified corrections and applies Xiao CUSUM tests. This
EA instead uses log prices, a rolling 504-pair window, fixed 10/50/90
quantiles, a constrained pairwise-slope solver, a monthly refit, weekly signal
evaluation, the QM-defined 0.05 beta-span guard, tail entries, and a median
exit. The paper reports stronger responses in upper quantiles above 80%; it
does not supply the 0.05 threshold. These substitutions are predeclared
falsification risks, not claims of replication.

## Pipeline history

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-12 | initial state-dependent XAU/XAG quantile envelope | Q01 | PASS |

## Pipeline phase status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-12 | APPROVED | this card |
| Q01 Build Validation | 2026-07-12 | PASS | strict compile/build-check evidence pending Q02 handoff record |
| Q02 Baseline Screening | TBD | TBD | TBD |

## Lessons captured

- 2026-07-12: The strategy remains distinct only while asymmetric check-loss
  quantile coefficients and the source-direction slope-span gate are binding.
