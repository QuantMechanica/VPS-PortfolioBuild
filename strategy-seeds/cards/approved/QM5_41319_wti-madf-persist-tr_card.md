---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-WTI-MADF-PERSIST-TREND-20260903_S01
variant_id: AI-CODEX-WTI-MADF-PERSIST-TREND-20260903_S01
source_id: AI-CODEX-WTI-MADF-PERSIST-TREND-20260903
ea_id: QM5_41319
slug: wti-madf-persist-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41319_wti-madf-persist-tr_card.md
execution_contract_status: APPROVED
created: 2026-09-03
created_by: Research+Development
last_updated: 2026-09-03
g0_status: APPROVED
g0_decision: decisions/2026-09-03_qm5_41319_wti_monthly_adf_persistence_trend_g0.md
source_approval: decisions/2026-09-03_wti_monthly_adf_persistence_trend_source_approval.md
source_author: OpenAI Codex
source_authors: OpenAI Codex; Ernest P. Chan; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen
source_citation: "OpenAI Codex (2026), WTI monthly lag-one ADF persistence-gated trend; supporting records Chan (2013), Algorithmic Trading, Wiley, ISBN 978-1-118-46014-6, pp. 41-44; Moskowitz, Ooi, and Pedersen (2012), Journal of Financial Economics 104(2), DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: ai_originated_governed_source
    citation: "OpenAI Codex (2026). WTI monthly lag-one ADF persistence-gated trend."
    location: strategy-seeds/sources/AI-CODEX-WTI-MADF-PERSIST-TREND-20260903/source.md
    quality_tier: governed_source
    role: exact_conjunction_sample_threshold_risk_and_lifecycle
  - type: book
    citation: "Chan, E. P. (2013). Algorithmic Trading: Winning Strategies and Their Rationale. Wiley Trading."
    location: "ISBN 978-1-118-46014-6; complete extraction strategy-seeds/sources/SRC05/raw/full_text.txt, bounded ADF read lines 2290-2416"
    quality_tier: A
    role: lag_one_constant_no_drift_adf_regression_and_displayed_threshold_only
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper record strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: monthly_own_return_continuation_and_explicit_wti_membership_only
strategy_mechanic: monthly-wti-sixty-completed-log-price-levels-lag1-constant-no-trend-augmented-dickey-fuller-regression-tstat-at-least-minus2p594-gated-twelve-month-return-sign-continuation
sources:
  - "[[sources/AI-CODEX-WTI-MADF-PERSIST-TREND-20260903]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/error-correction-persistence-state]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-log-price]]"
  - "[[indicators/lag-one-adf-regression-t-statistic]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, adf-persistence-state, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
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
magic: 413190000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately 7-11 completed WTI positions per full post-warm-up year is an uncalibrated planning prior; one attempt is consumed per broker month, and the ADF gate may consume a month flat. Q02 must prove at least five completed positions in every full scored year or retire."
expected_trades_per_year_per_symbol: 8
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_AI_SYNTHESIS_AND_COMPLETE_BOOK_PAPER_EVIDENCE
r1_reasoning: "One durable AI lineage binds a complete governed Wiley extraction and complete peer-reviewed WTI paper record, exact local bounds and hashes, adverse interpretation limits, and an explicit no-performance boundary."
r2_mechanical: PASS
r2_reasoning: "Month clock, sixty endpoints, logarithm orientation, 58-row lag-one intercept regression, centered OLS, 55 residual degrees of freedom, inclusive threshold, twelve-month side, attempt, fixed risk, hard stop, spread, and lifecycle are locked."
r3_data_available: PASS
r3_qualification: CONTINUOUS_CFD_BASIS_RISK
r3_reasoning: "Registered native XTIUSD.DWX D1 history and MT5 state supply every runtime input; continuous-CFD roll, basis, financing, gaps, and broker-month labels remain material risks."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, bounded OLS arithmetic, comparisons, ATR risk controls, quotes, positions, deals, and persistent state; no trained output, prohibited signal indicator, or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: 60 consecutive completed month-end closes; log levels; 58 observations of first difference on intercept, lagged level, and one lagged first difference; centered cross-product OLS; 55 residual degrees of freedom; determinant relative floor 1e-12; arithmetic energy floors 1e-18; inclusive adf_t >= -2.594; newest 12-month return direction epsilon 1e-12; 1200 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 frozen stop; 40-day stale exit; 1500-point spread ceiling."
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
review_focus: "Falsify a direct-WTI monthly lag-one error-correction persistence-gated trend outside the certified XAU/SP500/NDX/XNG book. Verify completed endpoints, chronological differences, intercept OLS arithmetic, coefficient standard error and degrees of freedom, inclusive threshold, twelve-month side, consumed month, fixed risk, hard stop, and next-month lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_tradable_month_bar, sixty_consecutive_completed_months, no_current_month_price, chronological_log_levels, exact_fifty_eight_regression_rows, constant_no_deterministic_trend, lag_one_first_difference, centered_ols_cross_products, residual_dof_55, lagged_level_standard_error, inclusive_adf_threshold, twelve_month_return_direction, monthly_attempt_state, risk_mode_dual, hard_stop_present, friday_close_disabled, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-09-03 and decisions/2026-09-03_qm5_41319_wti_monthly_adf_persistence_trend_g0.md: R1-R4 pass within disclosed source-translation and continuous-CFD risks. Corrected-root dedup returned CLEAN across 4,804 registry rows, 1,433 cards, and 45 Wiki nodes; manual review separates lagged-level error-correction OLS from KPSS partial sums, return autocorrelation, squared-return ARCH, delay-vector BDS, entropy, variance-ratio, robust-block, pure momentum, calendar, event, channel, and certified XNG RSI families."
---

# QM5_41319 WTI Monthly ADF Persistence-Gated Trend

## Hypothesis

WTI carries physical supply, storage, transport, refining, producer-hedging,
geopolitical, and end-demand exposures absent from the certified index/metal
book and materially different from natural-gas weather/storage exposure. The
hypothesis is that a completed twelve-month WTI move is more suitable for
one-month continuation when a lag-one ADF regression does not show strong
negative error correction.

The ADF state does not prove a unit root, persistence, trend, predictability,
or decorrelation. The displayed source threshold is deliberately frozen as a
translation boundary, not asserted to be a valid p-value for this continuous-
CFD sample. Q02 owns activity and economics; later gates own robustness; Q09
alone owns realized portfolio overlap.

## Source Traceability And Claim Boundary

The single governed source is
`strategy-seeds/sources/AI-CODEX-WTI-MADF-PERSIST-TREND-20260903/source.md`,
SHA-256
`576505363DE9DCA4F8E0CB4047D30DE630FB76CBC754F3F9FE3805CDA33507EC`,
approved and committed in `d486b131e7` before card extraction.

Chan supplies chronological constant/no-drift lag-one ADF mechanics, the
lagged-level coefficient-standard-error statistic, negative rejection
orientation, and the displayed `-2.594` example threshold. Moskowitz,
Ooi, and Pedersen supply monthly own-return continuation and explicit NYMEX
WTI membership. Neither source tests this conjunction, sixty monthly CFD
levels, the threshold's translated use, fixed risk, costs, activity,
performance, or portfolio correlation.

## Non-Duplicate Decision

The corrected-root checker receipt
`artifacts/qm5_wti_madf_persist_tr_preallocation_dedup_20260903.json`, SHA-256
`30321D2047DC7B44683A913BAC2B10AD7B258059D49FDDDAEA341324B7643468`,
returned `CLEAN` across 4,804 registry identities, 1,433 cards, and 45 Wiki
nodes.

- `QM5_41317` uses KPSS partial demeaned-level sums divided by a fixed-lag
  Newey-West denominator. This card estimates a lagged-level error-correction
  coefficient and its OLS standard error in a first-difference regression.
- Ljung-Box, ARCH-LM, BDS, Jarque-Bera, entropy, von Neumann, variance-ratio,
  rank, and robust-block cards observe different path or distribution states.
- Pure WTI momentum has no ADF-state gate; calendar, event, seasonality,
  channel, and relative-value cards have different clocks and triggers.
- Certified `QM5_12567` is a long-only two-day XNG oscillator pullback.

The non-market fixture pins qualifying up/down paths and a strongly mean-
reverting flat path. Verdict:
`CLEAN_WTI_MONTHLY_LAG1_CONSTANT_NO_TREND_ADF_T_GE_MINUS2P594_GATED_12M_CONTINUATION`.

## Markets, Timeframe, And Cadence

- Host and traded symbol: exact `XTIUSD.DWX`, D1, slot zero, intended magic
  `413190000` after deterministic allocation.
- Decide on the first executable tick after a genuine normalized broker-month
  transition, no later than 180 minutes after the raw host D1 bar open.
- Formation: exactly sixty consecutive completed broker-month-end closes;
  current-month prices are excluded.
- Hold: until the next normalized broker month; forty calendar days is stale
  repair only.
- Planning cadence: seven to eleven completed positions/year, uncalibrated.
  Q02 retires below five in any full post-warm-up year.

## Formula

For chronological completed-month closes `C[0..59]`, set `x[t]=ln(C[t])`.
For `t=2..59` form 58 observations:

```text
y[t] = x[t]-x[t-1]
z[t] = x[t-1]
w[t] = x[t-1]-x[t-2]
y[t] = alpha + gamma*z[t] + phi*w[t] + error[t]
```

Let bars denote 58-observation means. Compute:

```text
Szz = sum((z-zbar)^2)
Sww = sum((w-wbar)^2)
Szw = sum((z-zbar)*(w-wbar))
Szy = sum((z-zbar)*(y-ybar))
Swy = sum((w-wbar)*(y-ybar))
det = Szz*Sww-Szw^2

gamma = (Szy*Sww-Swy*Szw)/det
phi   = (Swy*Szz-Szy*Szw)/det
alpha = ybar-gamma*zbar-phi*wbar
SSE   = sum((y-alpha-gamma*z-phi*w)^2)
s2    = SSE/55
se_gamma = sqrt(s2*Sww/det)
adf_t = gamma/se_gamma
mom12 = x[59]-x[47]
```

Require all inputs and outputs finite, `Szz>1e-18`, `Sww>1e-18`,
`det>1e-12*Szz*Sww`, `SSE>1e-18`, `s2>0`, and `se_gamma>1e-18`.

```text
adf_t >= -2.594 and mom12 > +1e-12 => BUY
adf_t >= -2.594 and mom12 < -1e-12 => SELL
otherwise                            => consume month flat
```

The ADF comparison is inclusive. Statistic and return magnitudes never scale
risk. No alternative lag, deterministic trend, autolag, p-value interpolation,
fallback regression, or threshold exists.

## Rules

- Persist the current normalized broker month before history, signal, news,
  spread, quote, ATR, sizing, margin, or submission. Never retry the month.
- Select the latest close in each of the sixty immediately prior consecutive
  broker months from a bounded 1,200-D1 buffer.
- Reject current-month input, missing or duplicate months, nonconsecutive keys,
  nonchronological endpoints, nonpositive closes, a newest endpoint more than
  ten calendar days stale, or invalid arithmetic.
- Reject owned or foreign WTI exposure and an owned same-month entry deal.
- Both news axes, legacy news mode, Friday close, and stress rejection are off.
- Q02 has one locked baseline and no optimization surface.

## 4. Entry Rules

1. Require exact EA ID, symbol, D1 period, slot, registered magic, fixed-risk
   mode, framework settings, and every locked strategy input.
2. Process malformed-position and later-month/stale exits before entry gates.
3. Require a genuine new broker month inside the 180-minute grace window.
4. Persist the month attempt before every fallible gate.
5. Reconstruct sixty consecutive completed endpoints and compute the exact
   58-row lag-one intercept OLS without current-month data.
6. Enforce all arithmetic floors, the inclusive ADF threshold, and the strict
   twelve-month return side.
7. Require nonnegative modeled spread at most 1,500 points, executable quotes,
   completed-D1 ATR(20), valid metadata, positive fixed-risk sizing, and margin.
8. Open at most one position with `RISK_FIXED=1000`, `RISK_PERCENT=0`,
   `PORTFOLIO_WEIGHT=1`, a frozen `3.5*ATR(20,D1)` broker hard stop, and no
   target.

## 5. Exit Rules

1. Framework kill switch and broker hard stop remain authoritative.
2. Close on the first processed tick in a normalized broker month later than
   the entry month, before considering replacement risk.
3. Close after forty elapsed calendar days as stale repair.
4. Close malformed owned exposure immediately: duplicate, wrong symbol/magic,
   invalid volume/open time, missing hard stop, or inconsistent persisted
   entry-month state.
5. No intramonth statistic exit or flip, target, trail, break-even, partial
   close, Friday flatten, retry, scale-in, grid, martingale, or pyramid.

## 6. Filters (No-Trade Module)

- Fail closed outside the exact host, period, EA ID, slot, magic, fixed-risk,
  news, Friday, stress, and locked-input contract.
- Reject a consumed attempt, existing exposure/deal, malformed endpoint
  sequence, invalid regression, ADF state below threshold, neutral momentum,
  excessive spread, invalid quote, unavailable ATR, invalid stop/volume, or
  insufficient margin.
- Terminal-persistent month state plus deal history prevents restart retries.
- Runtime may not read futures curves, inventory, volume, open interest,
  files, APIs, forecasts, optimizer results, portfolio state, or trained
  artifacts.

## 7. Trade Management Rules

- Maintain either zero exposure or exactly one valid stop-protected WTI
  position and one consumed attempt per broker month.
- Preserve the original hard stop; close before monthly renewal or after the
  stale ceiling.
- Run malformed-position repair before entry-only gates on every tick.
- Restart recovery combines the terminal-persistent month marker with owned
  position and same-month deal history; no restart creates another attempt.

## Parameters To Test

Q02 has exactly one locked baseline:

| input | value |
|---|---:|
| completed month endpoints | 60 |
| regression observations | 58 |
| lagged first differences | 1 |
| intercept | enabled |
| deterministic time trend | disabled |
| residual degrees of freedom | 55 |
| determinant relative floor | `1e-12` |
| energy floors | `1e-18` |
| ADF state floor | `-2.594` inclusive |
| momentum horizon | 12 completed months |
| direction epsilon | `1e-12` |
| D1 history buffer | 1,200 bars |
| entry grace | 180 minutes |
| endpoint gap ceiling | 10 days |
| ATR stop | `3.5*ATR(20,D1)` |
| stale hold ceiling | 40 days |
| spread ceiling | 1,500 points |

Changing any value creates a new identity and requires new source, card,
binary, and full evidence. No failed baseline may be rescued inside this card.

## Risk

- Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- The single position receives one frozen `3.5*ATR(20,D1)` broker hard stop
  and no target.
- Signal magnitudes never affect volume; at most one position exists for the
  registered magic.
- Gaps, continuous-CFD roll/basis, financing, slippage, small-sample
  regression instability, and month labels can exceed modeled assumptions.
- No live risk mode or live artifact is authorized.

## Source-Defined Rules

- Chan describes the constant/no-drift lag-one ADF regression, coefficient
  standard-error statistic, negative rejection direction, chronological input,
  and displayed `-2.594` 10% example critical value.
- Moskowitz-Ooi-Pedersen document monthly own-return continuation and include
  NYMEX WTI in their commodity universe.

No source defines this conjunction, 60-month sample, inclusive trading gate,
continuous CFD, risk, stop, spread, density, performance, or correlation.

## QM Interpretations

- The displayed `-2.594` threshold is frozen as a non-rejection-like state
  boundary and is not represented as a valid p-value for this sample.
- Sixty completed endpoints, one lagged difference, centered OLS arithmetic,
  twelve-month side, consumed attempt, hard stop, spread, and lifecycle are
  transparent pre-result choices.

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

## Data Requirements

Exact native `XTIUSD.DWX` D1 timestamps and closes, broker time/month, quotes,
symbol metadata, completed-bar ATR, positions, deals, and one terminal-global
attempt/entry-month state. No external runtime data or trained artifact exists.

## Execution Assumptions

Q02 runs exact `XTIUSD.DWX` D1 with registered slot-zero magic, native quotes,
canonical tester deposit/currency defaults, and real-tick execution. The
continuous CFD is not the paper's rolling futures return and may invalidate
the edge through roll, basis, financing, spread, or gaps.

## Failure Conditions And Falsification

Retire on zero positions, fewer than five completed positions in any full
post-warm-up year, a failed formula/fixture, current-month leakage, wrong
degrees of freedom or threshold comparison, nondeterministic behavior,
malformed position handling, invalid fixed risk, missing stop, nonpositive
governed economics, or any downstream hard failure. Preserve negative and
zero-trade evidence; do not tune this identity after observing it.

## Expected Behavior

The EA checks once per genuine broker month, often enters in the completed
twelve-month direction, and may consume flat when the regression indicates
strong negative error correction or the direction is neutral. It must never
retry within a month, hold beyond the next month except for repair latency, or
scale exposure with statistic magnitude.

## Logging

Log normalized month key, endpoint keys/timestamps, OLS cross-products,
coefficients, residual energy, `se_gamma`, `adf_t`, `mom12`, direction,
ATR/stop, volume, magic, order result, repair action, and exit reason. Never
log credentials or external account data.

## Framework Alignment

| card rule | module / implementation target |
|---|---|
| identity, risk/news/Friday/stress contract, month attempt, endpoint and OLS state | `Strategy_NoTradeFilter` plus bounded helpers |
| ADF gate, momentum side, quote, spread, ATR, sizing, margin, order | `Strategy_EntrySignal` |
| malformed exposure, new-month, and forty-day repair | `Strategy_ManageOpenPosition` |
| lifecycle reason mapping | `Strategy_ExitSignal` plus framework close helper |
| both news axes off | `Strategy_NewsFilterHook` and framework initialization |

## Validation Plan

1. Match the independent upward, downward, and mean-reverting fixtures; prove
   additive log-level invariance and inclusive boundary behavior.
2. Verify sixty endpoint keys, chronological orientation, 58 rows, centered
   cross-products, coefficients, 55 residual degrees of freedom, standard
   error, and all invalid/degenerate paths.
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
| v1 | 2026-09-03 | initial WTI lag-one ADF persistence-gated trend | G0 | APPROVED; build pending |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Source Approval | 2026-09-03 | APPROVED_SOURCE | `decisions/2026-09-03_wti_monthly_adf_persistence_trend_source_approval.md` |
| G0 Research Intake | 2026-09-03 | APPROVED | `decisions/2026-09-03_qm5_41319_wti_monthly_adf_persistence_trend_g0.md` |
| Q01 Build & Spec | TBD | PENDING | TBD |
| Q02 Baseline | TBD | NOT_ENQUEUED | TBD |
