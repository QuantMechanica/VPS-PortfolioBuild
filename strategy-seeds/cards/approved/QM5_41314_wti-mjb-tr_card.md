---
card_schema_version: 2
type: strategy
strategy_id: JARQUEBERA-MOP-WTI-OMNIBUS-20260902_S01
variant_id: JARQUEBERA-MOP-WTI-OMNIBUS-20260902_S01
source_id: JARQUEBERA-SCIPY-MOP-WTI-OMNIBUS-20260902
ea_id: QM5_41314
slug: wti-mjb-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41314_wti-mjb-tr_card.md
execution_contract_status: APPROVED
created: 2026-09-02
created_by: Research+Development
last_updated: 2026-09-02
g0_status: APPROVED
g0_decision: decisions/2026-09-02_qm5_41314_wti_monthly_jarque_bera_trend_g0.md
source_approval: decisions/2026-09-02_wti_monthly_jarque_bera_trend_source_approval.md
source_author: QuantMechanica governed synthesis
source_authors: Carlos M. Jarque; Anil K. Bera; SciPy contributors; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen
source_citation: "QuantMechanica governed WTI distribution-shape synthesis; Jarque and Bera (1987), International Statistical Review 55(2), DOI 10.2307/1403192; pinned SciPy jarque_bera implementation; Moskowitz, Ooi, and Pedersen (2012), Journal of Financial Economics 104(2), DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: original_peer_reviewed_statistical_method
    citation: "Jarque, C. M. and Bera, A. K. (1987). A Test for Normality of Observations and Regression Residuals. International Statistical Review 55(2), 163-172."
    location: "DOI 10.2307/1403192; bibliographic attribution only"
    quality_tier: A_bibliographic
    role: original_jarque_bera_attribution
  - type: pinned_scientific_computing_implementation
    citation: "SciPy contributors. scipy.stats.jarque_bera, skew, and kurtosis."
    location: "GitHub commit 0f0a3dd37f88ecd8c4d83a5913df56471274fefa; complete bounded implementation and tests read through public API"
    quality_tier: A_method
    role: biased_population_moments_fisher_excess_kurtosis_formula_fixture_and_small_sample_warning
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: monthly_own_return_continuation_and_explicit_wti_membership
  - type: governed_composite_source
    citation: "QuantMechanica (2026). WTI monthly Jarque-Bera shape-gated trend."
    location: strategy-seeds/sources/JARQUEBERA-SCIPY-MOP-WTI-OMNIBUS-20260902/source.md
    quality_tier: governed_source
    role: exact_conjunction_boundary_risk_attempt_and_lifecycle
strategy_mechanic: monthly-wti-forty-eight-completed-log-returns-biased-population-m2-m3-m4-jarque-bera-squared-skew-and-excess-kurtosis-inclusive-104-gated-newest-twelve-month-continuation
sources:
  - "[[sources/JARQUEBERA-SCIPY-MOP-WTI-OMNIBUS-20260902]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/distribution-shape]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-log-return]]"
  - "[[indicators/jarque-bera-statistic]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, distribution-shape, skewness, excess-kurtosis, omnibus-statistic, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
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
magic: 413140000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately six completed WTI positions per full post-warm-up year; one consumed attempt per broker month. A fixed-seed market-free finite-sample null prior qualified 49.981%. Q02 must prove at least five trades in every full scored year or retire."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_SYNTHESIS_BOUNDARY
r1_reasoning: "Peer-reviewed original attribution, complete pinned scientific implementation and tests, complete governed peer-reviewed WTI trading-paper read, and explicit disclosure that applying the statistic to raw WTI returns as a trend gate is untested QM synthesis."
r2_mechanical: PASS
r2_reasoning: "Month clock, 49 endpoints, 48 returns, biased population moments, Fisher excess kurtosis, exact Jarque-Bera formula, inclusive 1.04 pre-data gate, newest-12m direction, consumed attempt, fixed risk, stop, spread, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_reasoning: "Registered native XTIUSD.DWX D1 and MT5 state supply every runtime input; continuous-CFD roll, basis, financing, gap, and broker-month-label risks remain."
r4_ml_forbidden: PASS
r4_reasoning: "Only completed prices, timestamps, logarithms, sums, products, integer powers, square root, ATR risk, quotes, positions, deals, and persistent state; no trained output or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: 49 consecutive completed month-end closes; 48 adjacent log returns; arithmetic mean; biased central moments each divided by 48; skew=m3/m2^1.5; excess=m4/m2^2-3; JB=48/6*(skew^2+excess^2/4); variance floor 1e-18; inclusive JB floor 1.04; newest 12m direction epsilon 1e-12; 1500 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 frozen stop; 40-day stale exit; 1500-point spread ceiling."
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
review_focus: "Falsify a direct-WTI monthly distribution-shape-gated continuation sleeve outside the certified XAU/SP500/NDX/XNG book. Verify endpoints, moment denominators, skew and excess-kurtosis convention, both squared components, inclusive boundary, newest-12m side, consumed month, fixed risk, frozen stop, and next-month lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_tradable_month_bar, forty_nine_consecutive_completed_months, no_current_month_price, forty_eight_adjacent_log_returns, chronological_return_orientation, arithmetic_mean, biased_population_moment_denominator, exact_m2_m3_m4, fisher_excess_kurtosis, squared_skew_component, squared_excess_component, inclusive_jb_104, newest_twelve_month_continuation_side, monthly_attempt_state, fixed_risk, hard_stop_present, nonnegative_spread, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-09-02 and decisions/2026-09-02_qm5_41314_wti_monthly_jarque_bera_trend_g0.md: R1-R4 pass within disclosed raw-return synthesis, small-sample, and continuous-CFD risks. Corrected-root dedup returned CLEAN across 4,799 registry rows, 1,428 cards, and 45 Wiki nodes; manual review separates the joint squared shape statistic from directional skew/kurtosis premiums, serial-dependence statistics, entropy, pure momentum, calendar, event, channel, and certified XNG RSI families."
---

# QM5_41314 WTI Monthly Jarque-Bera Shape-Gated Trend

## Hypothesis

WTI carries physical supply, storage, transport, refining, geopolitical,
hedging, and demand risks absent from the certified XAU, SP500, NDX, and XNG
carrier set. When forty-eight completed monthly WTI returns have a sufficiently
non-normal joint skew/kurtosis shape, the newest twelve-month direction may
persist for one more broker month.

This is a falsifiable direct-crude structural trend sleeve. It is not evidence
of normality rejection, profitability, statistical significance,
independence, or decorrelation. Q02 owns cadence and baseline economics;
unchanged Q09 alone owns portfolio overlap.

## Source Traceability And Claim Boundary

The governed source is
`strategy-seeds/sources/JARQUEBERA-SCIPY-MOP-WTI-OMNIBUS-20260902/source.md`,
SHA-256
`6C50EFC59F3C036C5107BAB15CCCD4804365595E8CC6F774C2ED1AE5BCFAA3AB`,
approved at commit `de179a4236` before card extraction.

Jarque and Bera supply original attribution. The complete pinned SciPy
implementation fixes the exact moment and statistic arithmetic and explicitly
warns against small-sample chi-square inference. Moskowitz, Ooi, and Pedersen
supply only WTI membership and monthly own-return continuation. None tests
this conjunction, window, empirical boundary, CFD, fixed risk, costs,
lifecycle, activity, or portfolio fit.

## Non-Duplicate Decision

The corrected-root fail-closed receipt
`artifacts/qm5_wti_mjb_tr_preallocation_dedup_20260902.json`, SHA-256
`3185D235BA92BA469C33605D2EE4E102644120100106F9152925CE40E61334CC`,
returned `CLEAN` across 4,799 registry rows, 1,428 cards, and all 45 Strategy
Wiki nodes.

- `QM5_20290` uses the sign of Pearson skewness to assign a direct premium;
  this gate squares skewness and never uses it for side.
- `QM5_20295` trades Pearson kurtosis around three; this gate converts it to
  excess kurtosis, squares it, and combines it with squared skewness.
- `QM5_41313` sums squared serial autocorrelations; Jarque-Bera is invariant
  to return order and measures marginal distribution shape instead.
- Entropy, rank, change-point, scale, pure trend, calendar, event, channel,
  and relative-value EAs operate on different state objects.
- Certified `QM5_12567` is a long-only two-day XNG oscillator pullback.

Verdict:
`CLEAN_WTI_MONTHLY_48_RETURN_JARQUE_BERA_JB_GE1P04_GATED_12M_CONTINUATION`.

## Markets, Timeframe, And Cadence

- Exact host and slot zero: `XTIUSD.DWX`, D1, governed magic `413140000`.
- Decision clock: first executable tick after a genuine broker-month change,
  within 180 elapsed minutes of the host D1 boundary.
- Formation: forty-nine consecutive completed broker-month-end closes;
  current-month prices are excluded.
- Hold: next broker month, with forty-calendar-day stale repair.
- Expected cadence: approximately six completed positions/year. Q02 retires
  any full scored post-warm-up year below five.

## Exact Formula

For chronological completed-month closes `C[0..48]`:

```text
x[i] = ln(C[i+1]/C[i]), i=0..47
mean = sum(x[i])/48
d[i] = x[i]-mean
m2 = sum(d[i]^2)/48
m3 = sum(d[i]^3)/48
m4 = sum(d[i]^4)/48
skew = m3/(m2^1.5)
excess = m4/(m2^2)-3
JB = 48/6 * (skew^2 + excess^2/4)
mom12 = sum(x[i], i=36..47)

BUY  iff JB >= 1.04 and mom12 > +1e-12
SELL iff JB >= 1.04 and mom12 < -1e-12
FLAT otherwise
```

Require positive finite closes, finite intermediate arithmetic, and
`m2>1e-18`. The gate is directionless by construction; only `mom12` assigns
side. Statistic and momentum magnitude never alter risk. The inclusive `1.04`
boundary is the two-decimal empirical median of a fixed-seed, market-free,
48-observation Gaussian simulation. It is not a critical value or p-value.

## Rules

- Consume the normalized broker month before history, signal, news, spread,
  quote, ATR, sizing, margin, or order gates. Never retry that month.
- Select the latest close in each immediately prior consecutive broker month
  from a bounded 1,500-D1 buffer.
- Reject current-month input, missing/duplicate/nonconsecutive month keys,
  nonchronological endpoints, nonpositive closes, a stale newest endpoint,
  invalid arithmetic, low variance, low `JB`, or neutral momentum.
- Permit neither foreign `XTIUSD.DWX` exposure nor existing owned exposure.
- Both news axes, legacy news, Friday close, and stress rejection are OFF.
- Q02 has one locked baseline and no optimization surface.

## 4. Entry Rules

1. Require EA ID 41314, exact `XTIUSD.DWX` D1, slot zero, magic 413140000,
   fixed-risk mode, framework defaults, and every strategy input locked.
2. Run lifecycle repair before entry-only gates.
3. Require a genuine new broker month inside the 180-minute entry window.
4. Persist the month attempt before every fallible gate.
5. Reconstruct the exact endpoints and chronological log returns.
6. Apply exact biased moments, standardized shape measures, both squared
   components, inclusive `1.04` gate, and newest twelve-month side.
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
- Fail closed on stale/nonconsecutive history, invalid closes/returns/moments,
  low shape statistic, neutral momentum, prior attempt/deal, spread, quote,
  ATR, sizing, or margin.
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
| completed month-end closes / returns | 49 / 48 |
| central-moment convention | biased population, divide each by 48 |
| skewness | `m3/m2^1.5` |
| excess kurtosis | `m4/m2^2-3` |
| Jarque-Bera statistic | `48/6*(skew^2+excess^2/4)` |
| variance floor | `m2>1e-18` |
| qualification boundary | inclusive `JB>=1.04` |
| direction | newest 12-month log-return sign |
| direction epsilon | `1e-12` |
| D1 history buffer | 1,500 bars |
| entry grace / endpoint staleness | 180 minutes / 10 days |
| ATR stop / stale hold | `3.5*ATR(20,D1)` / 40 days |
| spread ceiling | 1,500 points |

Changing any value creates a new variant and requires fresh evidence.

## Expected Behavior And Frequency

The fixed-seed market-free receipt, SHA-256
`A150F770B1BCB0C52C578C3C7456238EDB0092B14509B47E62C8F83196A6459C`,
qualifies `49.981%` of 200,000 independent standard-normal paths, or `5.99772`
states per twelve clocks. This is a cadence sanity check only, not WTI
evidence or a calibrated test size. Direction ties are probability zero in
that continuous null but still fail closed in runtime.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The broker stop is frozen at `3.5*ATR(20,D1)` and no
take-profit is attached. Gaps can exceed modeled stop risk. WTI's continuous
CFD adds roll, basis, financing, and broker-session risks. A 48-observation
shape statistic is noisy and roll discontinuities or isolated shocks can
dominate fourth moments. Overlapping rolling windows can keep the gate active
for long clusters. The continuation conjunction is untested. Live risk is not
authorized.

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
- Kill-switch, weekend, broker-disconnect, and hard-stop coverage remain active.

## Exit Precedence

1. Kill switch / broker hard stop.
2. Malformed position or missing entry-month state repair.
3. Next genuine broker-month exit.
4. Forty-day stale exit.
5. No other strategy or framework calendar exit.

## Runtime Data Dependencies

- Tester host `XTIUSD.DWX`, D1, account currency USD, deposit 100,000.
- Q02 window `2018.07.02` through `2024.12.31`; pre-window history supplies
  the forty-nine-month formation where the custom archive permits it.
- MT5-native history/execution state only; no external API, file, future bar,
  trained artifact, inventory series, or curve data.

## Reputable-Source Gate Findings

- R1: PASS with disclosed synthesis and small-sample boundaries.
- R2: PASS with exact deterministic signal, risk, and lifecycle rules.
- R3: PASS on registered native WTI D1, with explicit CFD transport risks.
- R4: PASS with bounded deterministic native arithmetic.

## Failure Modes And Kill Criteria

Retire or fail closed on formula/fixture mismatch, wrong return orientation,
wrong moment denominator, Pearson/Fisher convention error, missing squared
term, boundary or direction error, zero positions, fewer than five positions
in any full post-warm-up year, nonpositive governed economics, missing stop,
invalid fixed-risk mode, nondeterminism, lifecycle deviation, or any
downstream gate failure. No post-result parameter repair is authorized.

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
carrier. The distribution-shape gate is mechanically distinct from existing
WTI gates. This is a diversification hypothesis only. Q09 must measure
realized correlation and may reject it without a waiver.

## Validation Plan

1. Reference-test endpoint/return orientation, each moment, standardized
   skew/excess, both statistic terms, boundary, and direction against the
   pinned SciPy fixture and independent vectors.
2. Run card schema lint and strict Q01 compile/build checks.
3. Enqueue one canonical `RISK_FIXED` Q02 item only if CPU admission is clear.
4. Preserve any zero-trade, activity, or economic failure without changing
   the locked rule.

## Framework Alignment

| card rule | module |
|---|---|
| identity, risk/news/Friday contract, month attempt, endpoints and shape state | `Strategy_NoTradeFilter` and bounded helpers |
| quote, spread, ATR, fixed-risk size, one WTI order | `Strategy_EntrySignal` |
| restart recovery, side validation, next-month and forty-day repair | `Strategy_ManageOpenPosition` |
| broker/framework reason mapping | `Strategy_ExitSignal` and V5 close helper |

## Safety Boundary

Authorized: deterministic identity/magic allocation, branch-only non-live
build, reference tests, strict Q01, one fixed-risk backtest set, and one paced
Q02 enqueue below the whole-host CPU ceiling.

Forbidden: optimization, manual tester launch, live/demo/shadow/stress sets,
portfolio-gate edit, correlation waiver, portfolio admission, deploy/live
manifest, `T_Live`, AutoTrading, terminal control, or live use.

## Revision History

| version | date | reason | gate | verdict |
|---|---|---|---|---|
| v1 | 2026-09-02 | initial WTI Jarque-Bera trend card | G0 | APPROVED; build pending |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Source Approval | 2026-09-02 | APPROVED_SOURCE | `decisions/2026-09-02_wti_monthly_jarque_bera_trend_source_approval.md` |
| G0 Research Intake | 2026-09-02 | APPROVED | `decisions/2026-09-02_qm5_41314_wti_monthly_jarque_bera_trend_g0.md` |
| Q01 Build & Spec | TBD | PENDING | TBD |
| Q02 Baseline | TBD | NOT_ENQUEUED | TBD |
