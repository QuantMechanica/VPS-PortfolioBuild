---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-WTI-ADF-VN-AGREE-TREND-20260905_S01
variant_id: AI-CODEX-WTI-ADF-VN-AGREE-TREND-20260905_S01
source_id: AI-CODEX-WTI-ADF-VN-AGREE-TREND-20260905
ea_id: QM5_41338
slug: wti-adf-vn-agree-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41338_wti-adf-vn-agree-tr_card.md
execution_contract_status: APPROVED
created: 2026-09-05
created_by: Research+Development
last_updated: 2026-09-05
g0_status: APPROVED
g0_decision: decisions/2026-09-05_qm5_41338_wti_monthly_adf_von_neumann_agreement_trend_g0.md
source_approval: decisions/2026-09-05_wti_monthly_adf_von_neumann_agreement_trend_source_approval.md
source_author: OpenAI Codex
source_authors: OpenAI Codex; Ernest P. Chan; John von Neumann; R. H. Kent; H. R. Bellinson; B. I. Hart; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen
source_citation: "OpenAI Codex (2026), WTI monthly ADF and raw von Neumann agreement trend; Chan (2013), Algorithmic Trading, Wiley; NIST/SEMATECH Mean Successive Differences Test; von Neumann et al. (1941), Annals of Mathematical Statistics 12(4), DOI 10.1214/aoms/1177731677; Moskowitz, Ooi, and Pedersen (2012), Journal of Financial Economics 104(2), DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: governed_composite_source
    citation: "OpenAI Codex (2026). WTI monthly ADF and raw von Neumann agreement trend."
    location: strategy-seeds/sources/AI-CODEX-WTI-ADF-VN-AGREE-TREND-20260905/source.md
    quality_tier: governed_source
    role: exact_conjunction_sample_threshold_risk_and_lifecycle
  - type: approved_adf_source
    citation: "Chan, E. P. (2013). Algorithmic Trading: Winning Strategies and Their Rationale. Wiley Trading."
    location: strategy-seeds/sources/AI-CODEX-WTI-MADF-PERSIST-TREND-20260903/source.md
    quality_tier: A
    role: lag_one_constant_no_time_trend_adf_arithmetic_and_boundary_orientation
  - type: official_statistical_method
    citation: "NIST/SEMATECH Dataplot. Mean Successive Differences Test."
    location: strategy-seeds/sources/AI-CODEX-WTI-MVNRATIO-TREND-20260902/source.md
    quality_tier: A
    role: raw_successive_difference_ratio_formula_null_mean_and_low_ratio_trend_interpretation
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: strategy-seeds/sources/MOP-TSMOM-2012/source.md
    quality_tier: A
    role: monthly_own_return_continuation_and_explicit_wti_membership
strategy_mechanic: monthly-wti-sixty-completed-log-price-levels-lag-one-intercept-adf-t-at-least-minus2p594-and-newest-twenty-log-returns-raw-von-neumann-eta-strictly-below-two-agreement-gated-twelve-month-return-sign-continuation
sources:
  - "[[sources/AI-CODEX-WTI-ADF-VN-AGREE-TREND-20260905]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/dual-domain-persistence-agreement]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-log-price]]"
  - "[[indicators/augmented-dickey-fuller-statistic]]"
  - "[[indicators/raw-von-neumann-ratio]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, dual-diagnostic-agreement, augmented-dickey-fuller, raw-von-neumann-ratio, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
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
magic: 413380000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately five to seven completed WTI positions per full post-warm-up year is an uncalibrated planning prior; one attempt is consumed per broker month and either state gate may consume a month flat. Q02 must prove at least five completed positions in every full scored year or retire."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_GOVERNED_COMPLETE_PARENT_EVIDENCE
r1_reasoning: "Approved complete ADF, official NIST/original peer-reviewed von Neumann, and peer-reviewed WTI continuation records with hashes, read scopes, and non-transfer boundaries."
r2_mechanical: PASS
r2_reasoning: "Month clock, sixty endpoints, ADF path, newest twenty returns, exact raw von Neumann path, inclusive/strict thresholds, conjunction, twelve-month side, consumed attempt, fixed risk, stop, spread, and lifecycle are deterministic."
r3_data_available: PASS
r3_qualification: CONTINUOUS_CFD_BASIS_RISK
r3_reasoning: "Registered native XTIUSD.DWX D1 history and MT5 state supply every runtime input; continuous-CFD roll, basis, financing, gaps, and broker-month labels remain material risks."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, bounded OLS, deterministic finite sums, comparisons, ATR risk, quotes, positions, deals, and persistent state are used."
parameters_to_test: "Locked Q02 baseline only: 60 consecutive completed month-end closes; log levels; ADF 58 observations, intercept, one lagged difference, 55 residual degrees of freedom, determinant relative floor 1e-12, inclusive adf_t >= -2.594; newest 20 adjacent log returns from levels 39..59; raw von Neumann V floor 1e-18 and strict eta<2.0; newest 12-month direction epsilon 1e-12; 1800 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 frozen stop; 40-day stale exit; 1500-point spread ceiling."
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
review_focus: "Falsify a direct-WTI monthly ADF and raw-von-Neumann agreement trend outside the certified XAU/SP500/NDX/XNG book. Verify shared endpoints, ADF arithmetic, return slice, mean/D/V/eta arithmetic, inclusive ADF and strict eta boundaries, disagreement abstention, twelve-month side, consumed month, fixed risk, frozen stop, and next-month lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_tradable_month_bar, sixty_consecutive_completed_months, no_current_month_price, chronological_log_levels, adf_lag_one_constant_no_time_trend, adf_residual_dof_55, inclusive_adf_boundary, newest_twenty_returns, exact_von_neumann_mean_d_v_eta, strict_eta_boundary, both_gates_required, twelve_month_return_direction, monthly_attempt_state, risk_mode_dual, hard_stop_present, friday_close_disabled, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-09-05 and decisions/2026-09-05_qm5_41338_wti_monthly_adf_von_neumann_agreement_trend_g0.md: R1-R4 pass within disclosed statistical-synthesis and continuous-CFD risks. Corrected-root dedup found no exact identity across 4,818 registry rows and 1,437 cards; the external Wiki root was unavailable. Five expected fuzzy neighbors are manually resolved by non-equivalent single-gate, KPSS, spectral, and Phillips-Perron state geometry. Fixed fixtures prove both one-gate disagreement directions and executable up/down agreement paths. This identity decision is not a correlation claim."
---

# QM5_41338 WTI Monthly ADF and Raw von Neumann Agreement Trend

## Hypothesis

WTI supplies physical energy exposure through production, storage, transport,
refining, producer hedging, geopolitics, and end demand. Those drivers are
absent from the certified XAU/SP500/NDX carriers and differ from XNG weather
and storage sensitivity. The hypothesis is that a completed twelve-month WTI
move is suitable for one further broker month only when a lag-one ADF state
does not show strong error correction and the newest twenty monthly returns
show low successive variation relative to their total dispersion.

The tests overlap and are not independent votes. Agreement does not prove a
unit root, smooth trend, persistence, predictability, profit, or decorrelation.
Q02 owns cadence and economics; Q09 alone owns realized book overlap.

## Source Traceability And Claim Boundary

The governed source is
`strategy-seeds/sources/AI-CODEX-WTI-ADF-VN-AGREE-TREND-20260905/source.md`,
approved and committed in `76a71f1c22` before extraction. It binds complete
approved ADF, official/raw von Neumann, and WTI continuation records. The
parents define their methods separately. None validates this exact
conjunction, sample, thresholds, continuous CFD, costs, activity, or
portfolio fit.

## Non-Duplicate Decision

The corrected-root receipt
`artifacts/qm5_wti_adf_vn_agree_tr_preallocation_dedup_20260905.json` found no
exact identity and returned five expected fuzzy family neighbors.

- `QM5_41319` admits ADF-qualified high-eta paths.
- `QM5_41310` admits low-eta paths even when ADF strongly rejects.
- `QM5_41336` requires KPSS partial-sum/long-run-variance geometry.
- `QM5_41337` requires spectral-frequency concentration.
- `QM5_41320` uses lag-zero Phillips-Perron correction.

The fixture SHA-256 is recorded by the G0 decision. It pins ADF-only,
von-Neumann-only, agreement-buy, and agreement-sell paths. Manual verdict:
`DISTINCT_PRICE_LEVEL_ERROR_CORRECTION_AND_RETURN_ADJACENCY_CONJUNCTION`.
Shared WTI continuation can still correlate; Q09 receives no waiver.

## Markets, Timeframe, And Cadence

- Exact host/traded symbol: `XTIUSD.DWX`, D1, slot zero, magic `413380000`.
- Decide once on the first executable tick after a genuine broker-month
  transition, within 180 minutes of the raw D1 boundary.
- Formation: sixty consecutive completed broker-month-end closes; current-
  month prices are excluded.
- Hold through Friday until the next broker month; forty days is stale repair.
- Planning prior: five to seven completed positions/year. Q02 retires below
  five in any full post-warm-up scored year.

## Exact Formula

For chronological completed-month closes `C[0..59]`, set `x[t]=ln(C[t])`.
For `t=2..59`, fit:

```text
y[t]=x[t]-x[t-1]
z[t]=x[t-1]
w[t]=x[t-1]-x[t-2]
y=alpha+gamma*z+phi*w+error
adf_t=gamma/se_gamma
```

Use centered OLS over 58 rows with residual variance `SSE/55`. Require the
governed energy and determinant floors. ADF qualifies inclusively at
`adf_t >= -2.594`.

For `i=0..19`, set `r[i]=x[40+i]-x[39+i]`, `mean=sum(r)/20`,
`V=sum((r-mean)^2)`, `D=sum((r[i+1]-r[i])^2)`, and `eta=D/V`. Require
`V>1e-18`, finite nonnegative `D` and `eta`; qualify strictly at `eta<2.0`.

```text
mom12=x[59]-x[47]
BUY  iff both gates qualify and mom12 > +1e-12
SELL iff both gates qualify and mom12 < -1e-12
FLAT otherwise
```

Only momentum sign chooses side. No statistic magnitude affects size.

## Rules

- Consume and persist the normalized broker month before history, signal,
  news, spread, quote, ATR, sizing, margin, or submission. Never retry.
- Select the latest close in each of the sixty immediately prior consecutive
  broker months from a bounded 1,800-D1 buffer.
- Fail closed on invalid endpoints, arithmetic, either state gate, or neutral
  momentum.
- Reject owned or foreign WTI exposure and an owned same-month entry deal.
- Both news axes, legacy news, Friday close, and stress are off.
- Q02 has one locked baseline and no optimization surface.

## Entry Rules

1. Require exact identity, `XTIUSD.DWX` D1, governed slot/magic, fixed-risk
   mode, and every locked input.
2. Process malformed-position and later-month/stale exits before entry gates.
3. Require a genuine new broker month inside the entry grace window.
4. Persist the attempt before every fallible gate.
5. Reconstruct sixty completed endpoints once; feed all levels to ADF and the
   exact newest twenty-return slice to raw von Neumann arithmetic.
6. Require the inclusive ADF gate, strict eta gate, and a strict twelve-month
   side.
7. Require spread in `[0,1500]`, quotes, completed D1 ATR(20), valid metadata,
   positive fixed-risk sizing, and margin.
8. Open at most one position with a frozen `3.5*ATR` hard stop and no target.

## Exit Rules

1. Framework kill switch and broker hard stop remain authoritative.
2. Close on the first processed tick in a later normalized broker month.
3. Close after forty elapsed calendar days as stale repair.
4. Close duplicate, wrong-symbol/magic/side, invalid-time/volume,
   missing-stop, or inconsistent persisted-state exposure immediately.
5. No intramonth state exit or flip, target, trail, break-even, partial close,
   retry, scale-in, grid, martingale, or pyramid.

## Filters And Trade Management

Fail closed outside the exact host, identity, risk/news/Friday/stress and
locked-input contract. Lifecycle repair runs before entry-only gates on every
tick. Runtime may not read curves, inventory, volume, open interest, files,
APIs, forecasts, optimizer output, portfolio state, or trained artifacts.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_level_count` | 60 | [60] | completed month-end log levels |
| `strategy_regression_observations` | 58 | [58] | lag-one ADF regression rows |
| `strategy_residual_dof` | 55 | [55] | residual variance divisor |
| `strategy_adf_t_min` | -2.594 | [-2.594] | inclusive ADF state boundary |
| `strategy_vn_return_count` | 20 | [20] | newest monthly return slice |
| `strategy_vn_eta_max` | 2.0 | [2.0] | exclusive raw ratio boundary |
| `strategy_energy_floor` | 1e-18 | [1e-18] | ADF/V energy floor |
| `strategy_determinant_relative_floor` | 1e-12 | [1e-12] | ADF singularity guard |
| `strategy_momentum_months` | 12 | [12] | direction interval |
| `strategy_direction_epsilon` | 1e-12 | [1e-12] | neutral direction band |
| `strategy_history_bars` | 1800 | [1800] | bounded endpoint scan |
| `strategy_entry_grace_minutes` | 180 | [180] | month-entry window |
| `strategy_endpoint_stale_days` | 10 | [10] | newest endpoint ceiling |
| `strategy_atr_period` | 20 | [20] | completed stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen hard-stop multiple |
| `strategy_stale_days` | 40 | [40] | stale repair ceiling |
| `strategy_max_spread_points` | 1500 | [1500] | entry spread ceiling |

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Risk is high: WTI gaps, continuous-CFD roll/basis and
financing, single-carrier concentration, overlapping diagnostic samples,
small-sample ADF size, raw-magnitude outlier sensitivity, stop slippage,
month-label errors, and correlation with XNG or risk assets can dominate the
premise. Neither gate establishes prediction, independence, or profitability.

## Kill Criteria

- Retire at zero positions or fewer than five completed positions in any full
  scored post-warm-up year.
- Fail on wrong endpoint count/order, current-month leakage, ADF or eta
  mismatch, boundary error, wrong momentum slice/side, repeated attempt,
  missing hard stop, hold beyond forty days, invalid risk mode, or
  nondeterminism.
- Retire on nonpositive governed economics or later correlation rejection.
- Do not rescue failure by changing sample, statistic, threshold, direction,
  carrier, stop, hold, spread, or retry policy.

## Framework Alignment

- no_trade: exact WTI/D1/ID/slot/magic/seed, locked inputs, fixed risk, and
  news/Friday/stress guards.
- trade_entry: month persistence, endpoint reconstruction, ADF and eta
  arithmetic, conjunction, momentum side, spread/quote/ATR/stop checks, and
  one fixed-risk order.
- trade_management: malformed-state repair, recovered-direction validation,
  prior-month exit, and forty-day stale exit before entry gates.
- trade_close: framework close helper, broker hard stop, and kill switch.

## Safety Boundary

This card authorizes only deterministic allocation, branch-only non-live V5
build, strict compile/Q01, reference tests, one backtest setfile, and one paced
Q02 enqueue. It does not authorize manual backtests; live/demo/shadow/stress/
optimization setfiles; terminal control; AutoTrading; `T_Live`; deploy/live
manifest changes; portfolio admission; portfolio-gate edits; or correlation
waivers.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-09-05 | initial ADF/raw-von-Neumann agreement card | G0 | APPROVED; build pending |
