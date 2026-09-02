---
card_schema_version: 2
type: strategy
strategy_id: BROOCK-STATSMODELS-MOP-WTI-BDS2-20260902_S01
variant_id: BROOCK-STATSMODELS-MOP-WTI-BDS2-20260902_S01
source_id: BROOCK-STATSMODELS-MOP-WTI-BDS2-20260902
ea_id: QM5_41316
slug: wti-bds2-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41316_wti-bds2-tr_card.md
execution_contract_status: APPROVED
created: 2026-09-02
created_by: Research+Development
last_updated: 2026-09-02
g0_status: APPROVED
g0_decision: decisions/2026-09-02_qm5_41316_wti_monthly_bds2_trend_g0.md
source_approval: decisions/2026-09-02_wti_monthly_bds2_trend_source_approval.md
source_author: QuantMechanica governed synthesis
source_authors: William A. Broock; Jose A. Scheinkman; W. Davis Dechert; Blake LeBaron; statsmodels contributors; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen
source_citation: "QuantMechanica governed WTI BDS synthesis; Broock, Scheinkman, Dechert, and LeBaron (1996), Econometric Reviews 15(3), DOI 10.1080/07474939608800353; pinned statsmodels BDS implementation and tests; Moskowitz, Ooi, and Pedersen (2012), Journal of Financial Economics 104(2), DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: original_peer_reviewed_statistical_method
    citation: "Broock, W. A., Scheinkman, J. A., Dechert, W. D., and LeBaron, B. (1996). A Test for Independence Based on the Correlation Dimension. Econometric Reviews 15(3), 197-235."
    location: "DOI 10.1080/07474939608800353; bibliographic attribution"
    quality_tier: A_bibliographic
    role: original_bds_attribution
  - type: pinned_scientific_computing_implementation
    citation: "statsmodels contributors. statsmodels.tsa._bds implementation and upstream Kanzler reference fixtures."
    location: "GitHub commit 2d1115dbd648b1e120a7e7454479d46481a73a9a; complete bounded source, test module, input fixture, and output fixture read through public API"
    quality_tier: A_method
    role: exact_distance_correlation_sum_variance_conditioning_and_bds_formula
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: monthly_own_return_continuation_and_explicit_wti_membership
  - type: governed_composite_source
    citation: "QuantMechanica (2026). WTI monthly BDS nonlinear-dependence-gated trend."
    location: strategy-seeds/sources/BROOCK-STATSMODELS-MOP-WTI-BDS2-20260902/source.md
    quality_tier: governed_source
    role: exact_conjunction_boundary_risk_attempt_and_lifecycle
strategy_mechanic: monthly-wti-forty-eight-completed-log-returns-sample-sd-epsilon-1p5-strict-pairwise-correlation-integral-embedding-dimension-two-bds-absolute-normal-median-gated-newest-twelve-month-continuation
sources:
  - "[[sources/BROOCK-STATSMODELS-MOP-WTI-BDS2-20260902]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/nonlinear-dependence]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-log-return]]"
  - "[[indicators/bds-statistic]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, nonlinear-dependence, correlation-integral, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
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
magic: 413160000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately six completed WTI positions per full post-warm-up year under an explicitly asymptotic cadence prior; one consumed attempt per broker month. Q02 must prove at least five trades in every full scored year or retire."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_SYNTHESIS_BOUNDARY
r1_reasoning: "Peer-reviewed original attribution, complete pinned scientific implementation and upstream fixtures, complete governed peer-reviewed WTI trading-paper read, and explicit disclosure that applying BDS to raw WTI monthly returns as a trend gate is untested QM synthesis."
r2_mechanical: PASS
r2_reasoning: "Month clock, 49 endpoints, 48 returns, sample ddof one, epsilon multiplier, strict pair indicators, correlation sums, k, BDS variance/statistic, inclusive absolute gate, newest-12m direction, consumed attempt, fixed risk, stop, spread, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_reasoning: "Registered native XTIUSD.DWX D1 and MT5 state supply every runtime input; continuous-CFD roll, basis, financing, gap, and broker-month-label risks remain."
r4_ml_forbidden: PASS
r4_reasoning: "Only completed prices, timestamps, logarithms, sums, products, comparisons, bounded pair loops, square roots, ATR risk, quotes, positions, deals, and persistent state; no trained output or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: 49 consecutive completed month-end closes; 48 adjacent log returns; sample variance ddof 1; epsilon=1.5*sample_sd; strict abs distance below epsilon; embedding dimension 2; full-sample C1 and k; first-observation-conditioned C1; adjacent-pair C2; variance2=4*(k-C1^2)^2; BDS2=sqrt(47)*(C2-C1_truncated^2)/sqrt(variance2); floors 1e-18/1e-12/1e-18; inclusive abs-BDS floor 0.6744897501960817; newest 12m direction epsilon 1e-12; 1500 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 frozen stop; 40-day stale exit; 1500-point spread ceiling."
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
review_focus: "Falsify a direct-WTI monthly correlation-integral-dependence continuation sleeve outside the certified XAU/SP500/NDX/XNG book. Verify endpoint/return orientation, ddof one, strict epsilon, full versus conditioned sums, joint-delay orientation, k, variance, inclusive absolute boundary, newest-12m side, consumed month, fixed risk, frozen stop, and next-month lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_tradable_month_bar, forty_nine_consecutive_completed_months, no_current_month_price, forty_eight_adjacent_log_returns, chronological_return_orientation, sample_ddof_one, epsilon_1p5_sample_sd, strict_distance_indicator, full_sample_c1_and_k, conditioned_c1, adjacent_pair_c2, stable_dimension_two_variance, bds_statistic, inclusive_absolute_boundary, newest_twelve_month_continuation_side, monthly_attempt_state, fixed_risk, hard_stop_present, nonnegative_spread, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-09-02 and decisions/2026-09-02_qm5_41316_wti_monthly_bds2_trend_g0.md: R1-R4 pass within disclosed raw-return synthesis, small-sample/asymptotic, and continuous-CFD risks. Corrected-root dedup returned CLEAN across 4,801 registry rows, 1,430 cards, and 45 Wiki nodes; manual review separates delay-vector pair geometry from linear portmanteau, squared-return ARCH-LM, marginal shape, entropy, variance ratio, pure momentum, calendar, event, channel, and certified XNG RSI families."
---

# QM5_41316 WTI Monthly BDS Nonlinear-Dependence-Gated Trend

## Hypothesis

WTI carries physical supply, storage, transport, refining, geopolitical,
hedging, and demand risks absent from the certified XAU, SP500, NDX, and XNG
carrier set. When forty-eight completed monthly WTI returns depart sufficiently
from i.i.d. structure under a dimension-two BDS statistic, the newest twelve-
month direction may persist for one more broker month.

This is a falsifiable direct-crude structural trend sleeve. BDS is an omnibus
dependence diagnostic, not proof of chaos, nonlinear causation,
predictability, profitability, independence, or decorrelation. Q02 owns
cadence and baseline economics; unchanged Q09 alone owns portfolio overlap.

## Source Traceability And Claim Boundary

The governed source is
`strategy-seeds/sources/BROOCK-STATSMODELS-MOP-WTI-BDS2-20260902/source.md`,
SHA-256
`AF16FC65A4E3AA9DEF87B3DE9BFBB6DDB04D98373A04A6E093C3EF616E6A87E1`,
approved in commit `b4eb1ece13` before card extraction.

Broock et al. supply original attribution. The complete pinned statsmodels
implementation and fixtures fix the arithmetic. Moskowitz, Ooi, and Pedersen
supply only WTI membership and monthly own-return continuation. None tests
this conjunction, window, boundary, CFD, fixed risk, costs, lifecycle,
activity, or portfolio fit.

## Non-Duplicate Decision

The corrected-root fail-closed receipt
`artifacts/qm5_wti_bds2_tr_preallocation_dedup_20260902.json`, SHA-256
`CFC997B7033FE3C36863B8837D47881493965254AF25DD22EB5E6DDE783F3F40`,
returned `CLEAN` across 4,801 registry rows, 1,430 cards, and all 45 Strategy
Wiki nodes.

- Ljung-Box measures linear autocorrelation; BDS counts close delay vectors.
- ARCH-LM measures lag dependence of squared returns; BDS uses raw-return
  pair geometry without a regression.
- entropy systems count patterns, words, templates, or spectral power; BDS
  uses correlation sums and a source-specific variance normalization.
- Jarque-Bera measures unordered marginal shape; BDS depends on sequence.
- variance-ratio, robust-location, calendar, event, channel, and pure momentum
  families use different state objects.
- Certified `QM5_12567` is a long-only two-day XNG oscillator pullback.

Verdict:
`CLEAN_WTI_MONTHLY_48_RETURN_BDS_EMBED2_ABS_GE_NORMAL_MEDIAN_GATED_12M_CONTINUATION`.

## Markets, Timeframe, And Cadence

- Exact host and slot zero: `XTIUSD.DWX`, D1, governed magic `413160000`.
- Decision clock: first executable tick after a genuine broker-month change,
  within 180 elapsed minutes of the host D1 boundary.
- Formation: forty-nine consecutive completed broker-month-end closes;
  current-month prices are excluded.
- Hold: next broker month, with forty-calendar-day stale repair.
- Expected cadence: approximately six completed positions/year under an
  asymptotic prior. Q02 retires any full scored post-warm-up year below five.

## Exact Formula

For chronological completed-month closes `C[0..48]`, form
`r[i]=ln(C[i+1]/C[i])`, `i=0..47`. Let `n=48`, sample standard deviation use
`ddof=1`, and `epsilon=1.5*s`. Set `I[a,b]=1` only when the strict inequality
`abs(r[a]-r[b])<epsilon` holds.

```text
C1 = upper-pair mean of I over indices 0..47
k = (sum(row_sum(I)^2)-3*sum(I)+2*48)/(48*47*46)
C1T = upper-pair mean of I over indices 1..47
J[a,b] = I[a,b]*I[a+1,b+1], a,b=0..46
C2 = upper-pair mean of J
variance2 = 4*(k-C1^2)^2
BDS2 = sqrt(47)*(C2-C1T^2)/sqrt(variance2)
mom12 = sum(r[36..47])

BUY  iff abs(BDS2) >= 0.6744897501960817 and mom12 > +1e-12
SELL iff abs(BDS2) >= 0.6744897501960817 and mom12 < -1e-12
FLAT otherwise
```

All indicator diagonals are one because epsilon must be positive. Require
finite arithmetic plus sample-variance, epsilon, and BDS-variance floors. The
gate is sign agnostic; only `mom12` assigns side. Statistic and momentum
magnitude never alter risk.

## Rules

- Consume the normalized broker month before history, signal, news, spread,
  quote, ATR, sizing, margin, or order gates. Never retry that month.
- Select the latest close in each immediately prior consecutive broker month
  from a bounded 1,500-D1 buffer.
- Reject current-month input, missing/duplicate/nonconsecutive month keys,
  nonchronological endpoints, nonpositive closes, a stale newest endpoint,
  invalid arithmetic, a degenerate BDS denominator, low absolute BDS, or
  neutral momentum.
- Permit neither foreign `XTIUSD.DWX` exposure nor existing owned exposure.
- Both news axes, legacy news, Friday close, and stress rejection are OFF.
- Q02 has one locked baseline and no optimization surface.

## Entry Rules

1. Require EA ID 41316, exact `XTIUSD.DWX` D1, slot zero, magic 413160000,
   fixed-risk mode, framework defaults, and every strategy input locked.
2. Run lifecycle repair before entry-only gates.
3. Require a genuine new broker month inside the 180-minute entry window.
4. Persist the month attempt before every fallible gate.
5. Reconstruct the exact endpoints and chronological log returns.
6. Apply exact sample variance, epsilon, strict indicators, correlation sums,
   `k`, BDS variance/statistic, inclusive gate, and newest twelve-month side.
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
5. There is no target, statistic exit, intramonth flip, Friday flatten,
   trail, break-even move, partial close, scale-in, grid, martingale, or
   pyramid.

## Filters And Management

Fail closed on wrong identity, symbol, period, slot, magic, risk/news/Friday/
stress contract, stale/nonconsecutive history, any invalid BDS component,
prior attempt/deal, spread, quote, ATR, sizing, or margin. Lifecycle handling
precedes entry-only gates. Preserve the frozen broker stop and entry-month
state; never resize or retry.

## Parameters To Test

Q02 has exactly one locked baseline: 49 month-end closes, 48 returns, sample
`ddof=1`, epsilon multiplier `1.5`, embedding dimension `2`, strict distance,
three numeric floors, absolute boundary `0.6744897501960817`, newest twelve-
month direction, 1,500 D1 history bars, 180-minute grace, ten-day endpoint
staleness, `3.5*ATR(20)` stop, forty-day stale hold, and 1,500-point spread
ceiling. Changing any value creates a new variant and needs fresh evidence.

## Expected Behavior And Frequency

The asymptotic-null receipt, SHA-256
`596589494498C313E9F814B60ADEFCAE70FA73331FEAC2D9A9855E607952780F`,
uses the standard-normal 75th percentile as a symmetric median-absolute state
divider, giving six theoretical qualifying clocks per year. Forty-eight
observations are a small sample and rolling windows overlap, so this is not a
realized density estimate. Q02 must measure actual completed positions.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The broker stop is frozen at `3.5*ATR(20,D1)` and no
take-profit is attached. Gaps can exceed modeled stop risk. WTI's continuous
CFD adds roll, basis, financing, and broker-session risks. BDS can react to
linear dependence, nonlinear dependence, heteroskedasticity, outliers, or
roll artifacts; it does not identify a profitable cause. The continuation
conjunction and small-sample state divider are untested. Live risk is not
authorized.

## Data Requirements

Native `XTIUSD.DWX` D1 time/close history and closed D1 ATR values; broker
time/month, quotes, spread, symbol metadata, margin, position/deal state, and
terminal globals. No external runtime source, file, forecast, curve,
inventory series, optimizer output, or trained artifact is allowed.

## Framework Execution Overrides

- `qm_news_temporal=QM_NEWS_TEMPORAL_OFF`.
- `qm_news_compliance=QM_NEWS_COMPLIANCE_NONE`.
- `qm_news_mode_legacy=QM_NEWS_OFF`.
- `qm_friday_close_enabled=false`.
- `qm_stress_reject_probability=0` in the canonical baseline.
- Kill-switch, weekend, broker-disconnect, and hard-stop coverage stay active.

## Failure Modes And Kill Criteria

Retire or fail closed on formula/fixture mismatch, wrong return or delay-vector
orientation, wrong `ddof`, non-strict epsilon, full/conditioned sum mix-up,
`k` or variance error, boundary or direction error, zero positions, fewer
than five positions in any full post-warm-up year, nonpositive governed
economics, missing stop, invalid fixed-risk mode, nondeterminism, lifecycle
deviation, or any downstream gate failure. No post-result parameter repair is
authorized.

## Framework Alignment

| card rule | module |
|---|---|
| identity, risk/news/Friday contract, month attempt, endpoints and BDS state | `Strategy_NoTradeFilter` and bounded helpers |
| quote, spread, ATR, fixed-risk size, one WTI order | `Strategy_EntrySignal` |
| restart recovery, side validation, next-month and forty-day repair | `Strategy_ManageOpenPosition` |
| broker/framework reason mapping | `Strategy_ExitSignal` and V5 close helper |

## Validation Plan

1. Match pinned statsmodels dimension-two output on upstream fixtures and
   independent local vectors; prove strict epsilon, conditioning, joint-pair
   orientation, `k`, variance, boundary symmetry, and degenerate failure.
2. Run card schema lint and strict Q01 compile/build checks.
3. Enqueue one canonical `RISK_FIXED` Q02 item only if CPU admission is clear.
4. Preserve any zero-trade, activity, or economic failure without changing
   the locked rule.

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
| v1 | 2026-09-02 | initial WTI BDS2 trend card | G0 | APPROVED; build pending |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Source Approval | 2026-09-02 | APPROVED_SOURCE | `decisions/2026-09-02_wti_monthly_bds2_trend_source_approval.md` |
| G0 Research Intake | 2026-09-02 | APPROVED | `decisions/2026-09-02_qm5_41316_wti_monthly_bds2_trend_g0.md` |
| Q01 Build & Spec | TBD | PENDING | TBD |
| Q02 Baseline | TBD | NOT_ENQUEUED | TBD |
