---
card_schema_version: 2
type: strategy
strategy_id: KELOHARJU-HARRELL-DAVIS-WTI-SAMECAL-HD5-2026_S01
variant_id: KELOHARJU-HARRELL-DAVIS-WTI-SAMECAL-HD5-2026_S01
source_id: KELOHARJU-HARRELL-DAVIS-WTI-SAMECAL-HD5-2026
ea_id: QM5_41234
slug: wti-samecal-hd5
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41234_wti-samecal-hd5_card.md
execution_contract_status: APPROVED
created: 2026-08-30
created_by: Research+Development
last_updated: 2026-08-30
g0_status: APPROVED
g0_decision: decisions/2026-08-30_qm5_41234_wti_same_calendar_harrell_davis5_g0.md
source_approval: decisions/2026-08-30_wti_same_calendar_harrell_davis5_source_approval.md
source_author: "Matti Keloharju; Juhani T. Linnainmaa; Peter Nyberg; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; Frank E. Harrell; C. E. Davis"
source_authors: "Matti Keloharju; Juhani T. Linnainmaa; Peter Nyberg; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; Frank E. Harrell; C. E. Davis"
source_citation: "Keloharju, Linnainmaa, and Nyberg (2016), Return Seasonalities, Journal of Finance 71(4), DOI 10.1111/jofi.12398; Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104(2), DOI 10.1016/j.jfineco.2011.11.003; Harrell and Davis (1982), A New Distribution-Free Quantile Estimator, Biometrika 69(3), DOI 10.1093/biomet/69.3.635; Frank Harrell's Hmisc hdquantile documentation and source."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Keloharju, M., Linnainmaa, J. T., and Nyberg, P. (2016). Return Seasonalities. The Journal of Finance 71(4), 1557-1590."
    location: "DOI 10.1111/jofi.12398; complete-read parent packet strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md"
    quality_tier: A
    role: same_calendar_month_commodity_information_crude_oil_membership_and_five_year_floor
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-read parent packet strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: explicit_wti_membership_own_return_direction_and_monthly_lifecycle
  - type: peer_reviewed_statistics_paper
    citation: "Harrell, F. E., and Davis, C. E. (1982). A New Distribution-Free Quantile Estimator. Biometrika 69(3), 635-640."
    location: "DOI 10.1093/biomet/69.3.635; publisher record and abstract"
    quality_tier: A
    role: named_distribution_free_order_statistic_quantile_estimator
  - type: author_maintained_numerical_implementation
    citation: "Frank Harrell, Hmisc hdquantile documentation and R/Misc.s implementation."
    location: "https://search.r-project.org/CRAN/refmans/Hmisc/html/hdquantile.html; https://github.com/harrelfe/Hmisc/blob/master/R/Misc.s; relevant implementation read 2026-08-30"
    quality_tier: originating_author_implementation
    role: exact_n_plus_one_beta_parameters_interval_mass_weights_and_weighted_sum
  - type: governed_composite_source
    citation: "QuantMechanica bounded WTI exact-five-year same-calendar Harrell-Davis median extraction."
    location: "strategy-seeds/sources/KELOHARJU-HARRELL-DAVIS-WTI-SAMECAL-HD5-2026/source.md"
    quality_tier: internal_governed_complete
    role: exact_calendar_endpoints_five_sample_weights_risk_claim_and_lifecycle
strategy_mechanic: exact-prior-five-year-same-calendar-month-wti-log-returns-harrell-davis-median-beta-three-three-order-statistic-weighted-location-sign-monthly-renewal
sources:
  - "[[sources/KELOHARJU-HARRELL-DAVIS-WTI-SAMECAL-HD5-2026]]"
concepts:
  - "[[concepts/return-seasonality]]"
  - "[[concepts/distribution-free-quantile-location]]"
  - "[[concepts/calendar-month-renewal]]"
indicators:
  - "[[indicators/completed-log-return]]"
  - "[[indicators/harrell-davis-median]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, calendar-seasonality, same-calendar-month, harrell-davis-median, order-statistic-location, monthly-renewal, atr-hard-stop, low-frequency, symmetric-long-short]
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
magic: 412340000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: long_short
expected_trade_frequency: "Approximately 10-12 completed WTI positions per full post-warm-up year; Q02 must prove at least five in every full scored year or retire."
expected_trades_per_year_per_symbol: 10
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_QUANTILE_ESTIMATOR_AND_SINGLE_CFD_TRANSLATION_RISK
r1_reasoning: "Two complete-read peer-reviewed trading papers support recurring same-calendar commodity information, explicit WTI membership, own-return direction, and monthly renewal. A peer-reviewed Biometrika citation plus the originating author's maintained implementation fix the distribution-free quantile estimator. The exact five-sample WTI conjunction is an untested QM translation."
r2_mechanical: PASS
r2_reasoning: "Month clock, uniform D1-label normalization, exact Y-5..Y-1 endpoints, five-return requirement, ascending sort, beta(3,3) interval weights, rational and decimal invariant, epsilon side map, consumed attempt, fixed risk, hard stop, spread, and lifecycle are deterministic and locked."
r3_data_available: PASS_WITH_FIVE_YEAR_WARMUP_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK
r3_reasoning: "Registered XTIUSD.DWX D1 history covers the required five-year warm-up and native MT5 state supplies every runtime input. Session labels, rolls, financing, gaps, and futures/CFD basis remain binding."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, finite arithmetic, sorting, fixed weighted sums, comparisons, ATR risk controls, quotes, and execution state; no trained signal, banned signal indicator, or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: exact prior five matching-calendar years; all five mandatory; ascending sort; Harrell-Davis p=0.5 beta(3,3) weights [181,811,1141,811,181]/3125; decimal invariant within 1e-12; strict absolute location above 1e-12; 3000 D1 history bars; ATR(20)*3.5 frozen stop; 40-day stale repair; 1500-point spread ceiling."
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
review_focus: "Falsify a direct-WTI recurring-calendar sleeve outside the certified XAU/SP500/NDX/XNG book. Verify normalized completed endpoints, exact five-year membership, ascending order, beta(3,3) interval-mass weights, rational/decimal invariant, sign, consumed month, fixed risk, frozen stop, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_tradable_month_bar, uniform_energy_label_normalization, exact_prior_five_year_same_calendar_months, completed_month_endpoints, no_current_month_price, five_of_five_sample, chronological_return_orientation, ascending_sort, harrell_davis_median, beta_three_three_interval_weights, rational_decimal_invariant, strict_sign_epsilon, monthly_attempt_state, risk_mode_dual, hard_stop_present, friday_close_disabled, next_month_exit, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-30 and decisions/2026-08-30_qm5_41234_wti_same_calendar_harrell_davis5_g0.md: R1 passes with two complete peer-reviewed WTI/commodity lineages, a peer-reviewed distribution-free quantile citation, the originating author's maintained implementation, and explicit estimator/CFD translation risk; R2 locks calendar, endpoints, exact sample, sort, weights, invariant, side, attempt, risk, stop, spread, and lifecycle; R3 binds the five-year rule to registered WTI D1 history; R4 uses deterministic native arithmetic only. Corrected-root canonical dedup found no exact identity, and fixed disagreement fixtures prove semantic non-equivalence to mean, median, trim, Winsor, trimean, midhinge, Gastwirth, and other same-calendar siblings."
---

# QM5_41234 WTI Same-Calendar Five-Sample Harrell-Davis Median

## Hypothesis

WTI production, storage, transport, refining, hedging, and demand pressures can
recur in the same named calendar month. A raw cross-year mean can be controlled
by one oil-shock year, while an ordinary median discards every spacing outside
the single middle observation. This card tests whether an exact five-year
same-calendar signal is more useful when represented by the fixed
Harrell-Davis estimate of the median, which assigns deterministic beta(3,3)
interval mass to all five ordered returns.

The direct WTI carrier and recurring monthly clock target exposure outside the
certified XAU/SP500/NDX/XNG set. That construction does not prove low
correlation, profitability, or CFD/futures equivalence. Q02 owns activity and
baseline economics; unchanged Q09 alone owns realized portfolio overlap.

## Source Traceability And Claim Boundary

The approved bounded packet is
`strategy-seeds/sources/KELOHARJU-HARRELL-DAVIS-WTI-SAMECAL-HD5-2026/source.md`,
SHA-256
`EA3913CA0FBD8EAFCC167615EEBD27ADC652F03292DC5BB1A2F87329B7C5B200`,
committed as `061a204d3`. The durable source approval is
`decisions/2026-08-30_wti_same_calendar_harrell_davis5_source_approval.md`,
committed as `3c278ece5`.

Keloharju, Linnainmaa, and Nyberg support recurring same-calendar commodity
information, explicit crude-oil membership, monthly renewal, and a five-year
history floor. Moskowitz, Ooi, and Pedersen support WTI own-return direction
and monthly renewal. Harrell and Davis supply the named distribution-free
quantile lineage, while the originating author's `Hmisc` implementation fixes
the beta interval-weight convention. No source tests this exact five-return
single-CFD conjunction.

The five-year sample, single-WTI zero comparison, median target, continuous
CFD, fixed risk, ATR stop, spread ceiling, and lifecycle are pre-result QM
mechanizations. No source performance, WTI-only alpha, cost, drawdown,
correlation, or CFD-equivalence result transfers.

## Formula

At a genuine normalized broker-calendar transition to year `Y`, month `M`,
load the completed WTI log return for calendar month `M` in each exact year
`Y-5..Y-1`. Sort only a copy as `s[0] <= ... <= s[4]`.

For `n=5`, target quantile `p=0.5`, and `m=n+1=6`, the Harrell-Davis beta
parameters are `a=b=3`. Differencing regularized beta CDF values at fifths
gives exact fixed weights:

```text
weights = [181, 811, 1141, 811, 181] / 3125
        = [0.05792, 0.25952, 0.36512, 0.25952, 0.05792]

hd = (181*s[0] + 811*s[1] + 1141*s[2]
      + 811*s[3] + 181*s[4]) / 3125

hd > +1e-12 => BUY XTIUSD.DWX
hd < -1e-12 => SELL XTIUSD.DWX
otherwise    => consume the month flat
```

All five returns are mandatory and every intermediate must be finite. The
rational computation and independent decimal-weight computation must agree
within `1e-12`. No runtime beta function, alternate quantile, endpoint
fallback, shorter sample, refit, iteration, magnitude sizing, or adaptive
runtime parameter is authorized.

## Non-Duplicate Decision

The canonical receipt
`artifacts/qm5_wti_samecal_hd5_preallocation_dedup_20260830.json`, SHA-256
`08046E588E84E3AE010A4C3CA5F32F68CA1097D961731C5AD5401366D81E35A9`,
found no exact identity across 4,733 registry rows, 1,371 cards, and 45 wiki
nodes. Its 13 fuzzy matches are expected same-calendar family neighbors.

- `[-0.30,-0.30,+0.05,+0.25,+0.25]` gives this rule `+0.002384` and BUY.
  Raw mean and endpoint Winsor SELL; middle-three trim is FLAT; midhinge
  SELLs.
- `[-0.30,-0.20,-0.05,+0.30,+0.30]` gives this rule `+0.007696` and BUY.
  Ordinary median and Gastwirth SELL; trimean is FLAT.
- `[-0.30,-0.30,+0.05,+0.20,+0.20]` gives this rule `-0.013488` and SELL.
  Ordinary median and Gastwirth BUY. Sign reflection reverses each strict
  mapping.
- Existing same-calendar mean, median, trim, endpoint Winsor, block median,
  shortest-half, trimean, midhinge, pseudomedian, Huber, bisquare, MAD-cap,
  t-score, sign-score, recency-weighted, and Gastwirth EAs do not assign the
  fixed beta(3,3) interval mass to all five order statistics.

Verdict:
`SEMANTICALLY_DISTINCT_WTI_EXACT_FIVE_YEAR_SAME_CALENDAR_HARRELL_DAVIS_MEDIAN_SIGN_MONTHLY_SLEEVE`.

## Markets, Timeframe, And Cadence

- Target symbol and host: exact `XTIUSD.DWX` only, D1, symbol slot 0.
- Decision cadence: first executable D1 tick after a genuine normalized broker
  month transition.
- Formation: exact completed matching calendar month in `Y-5..Y-1`.
- Hold: until the next normalized broker-month boundary; 40 elapsed calendar
  days is survivor repair only.
- Expected frequency: approximately 10-12 completed positions per full
  post-warm-up year; fewer than five in any full scored year is a Q02 kill.

## Rules

### Entry Rules

1. Require exact EA ID `41234`, exact `XTIUSD.DWX` D1 host, slot 0, fixed-risk
   inputs, both news axes OFF, legacy news OFF, and Friday close OFF.
2. Process malformed exposure and prior-month liquidation before entry-only
   gates. Evaluate only after a genuine normalized broker-month transition.
3. Accept one uniform native or `+1` energy D1-label convention. Require the
   normalized current host D1 date to equal broker date and apply the same
   offset to every historical endpoint.
4. Persist current broker `yyyymm` before history, signal, news, spread,
   quote, ATR, sizing, margin, or submission. Never retry after any outcome.
5. Scan exact years `Y-5..Y-1` for calendar month `M`. Require strict
   adjacent-month completed endpoints, a confirming following bar, positive
   prices, and all five valid returns. No missing-year substitution or shorter
   sample is allowed.
6. Sort a copy ascending, verify order, compute the locked rational and
   decimal-weight Harrell-Davis representations, and require finite equality
   within `1e-12`.
7. Buy above `+1e-12`; sell below `-1e-12`; equality inside the inclusive
   band consumes flat. Magnitude never changes risk.
8. Require no owned exposure or same-month entry deal, positive finite Bid
   and Ask, `Ask>=Bid`, spread in `[0,1500]` points, completed ATR(20,D1), a
   normalized stop, valid volume metadata, and sufficient margin.
9. Submit one market position using `RISK_FIXED=1000` with a frozen
   `3.5*ATR(20,D1)` hard stop and no target. There is no second attempt.

### Exit Rules

1. At the first processed host D1 bar of the next normalized broker month,
   close the old position before evaluating a replacement.
2. Close after 40 elapsed calendar days as a final stale guard.
3. Immediately flatten duplicate, wrong-symbol, wrong-magic, invalid-side,
   missing-stop, invalid-volume, or invalid-open-time owned exposure.
4. The broker hard stop, framework kill switch, and framework close helper
   remain authoritative.
5. Friday close is disabled because the structural monthly hold spans
   weekends.
6. There is no intramonth signal exit, target, trail, break-even, partial
   close, scale-in, grid, martingale, pyramid, stop-and-reverse, or
   discretionary exit.

### Filters And No-Trade Rules

- Wrong host, period, EA ID, slot, locked input, mid-month start, duplicate
  state, invalid label convention, endpoint failure, incomplete sample,
  invalid order, weight/invariant failure, epsilon tie, quote, spread, ATR,
  sizing, or order state consumes the persisted month.
- Both news axes and legacy news are OFF; no external calendar or feed is
  consulted. Lifecycle and malformed-position repair are never delayed by
  entry gates.
- No raw mean, median, trim, Winsor, pseudomedian, shortest interval, block
  statistic, Huber, trimean, midhinge, bisquare, MAD-cap, Gastwirth, t-score,
  sign-score, trend, oscillator, event, volume, curve, inventory, or
  current-month fallback is allowed.

### Trade Management Rules

- Every tick begins with framework MAE tracking before any guard can return.
- Malformed, cross-month, and stale repair runs before every entry-only gate
  and remains retryable until owned exposure is flat.
- Maintain at most one exact WTI position under the registered magic; never
  manage another EA's or manual trade.
- The entry hard stop never moves. Signal changes do not alter an open
  position inside the month.
- Persist the consumed-month ledger in a terminal global variable so restart
  cannot generate a second attempt.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| Input | Locked value | Role |
|---|---:|---|
| `strategy_history_years` | 5 | exact matching-calendar years |
| `strategy_history_bars_d1` | 3000 | bounded endpoint scan |
| `strategy_signal_epsilon` | 1e-12 | inclusive flat band around zero |
| `strategy_invariant_tolerance` | 1e-12 | rational/decimal equality |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | stale repair only |
| `strategy_max_spread_points` | 1500 | nonnegative WTI entry-cost guard |
| `strategy_deviation_points` | 20 | market-order deviation |
| `qm_friday_close_enabled` | false | preserve monthly hold |

No sample, estimator, weight, epsilon, direction, stop, hold, spread, or
lifecycle sweep is authorized.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Frozen hard stop: `3.5*ATR(20,D1)` from completed data.
- No target, signal-magnitude sizing, risk renewal, compounding override, or
  rescue entry.
- Invalid price, stop distance, tick value, tick size, volume step, minimum
  volume, lot, margin, or position composition consumes the month.
- This card creates no live, demo, shadow, stress, or optimization preset.

The exact conjunction and single continuous CFD are untested. Five-year
warm-up, small-sample instability, positive tail weights, rolls, financing,
gaps, label mapping, and stop slippage can erase the premise. Q09 alone may
measure correlation with the incumbent book.

## Runtime Data Dependencies

Native `XTIUSD.DWX` D1 OHLC/timestamps, broker clock, symbol quotes and
properties, positions, deals, and terminal-global attempt state only. No
curve, contract chain, inventory, storage data, weather, volume, open
interest, event feed, API, CSV, optimizer artifact, trained output, or manual
signal input.

## Framework Execution Overrides

- `qm_news_temporal=QM_NEWS_TEMPORAL_OFF`.
- `qm_news_compliance=QM_NEWS_COMPLIANCE_NONE`.
- `qm_news_mode_legacy=QM_NEWS_OFF`.
- `qm_friday_close_enabled=false`.
- Framework kill switch, fixed-risk sizing, magic resolution, order services,
  MAE tracking, and exact owned-position isolation remain mandatory.

## Exit Precedence

1. Framework kill switch or close-only instruction.
2. Malformed, duplicate, invalid-side, stopless, or invalid-metadata repair.
3. Broker hard stop.
4. New normalized broker-month exit.
5. Forty-day stale repair.
6. New entry only when flat and the current month is not already consumed.

## Framework Alignment

| Card rule | V5 module | Required implementation |
|---|---|---|
| exact host, D1, EA, slot, locked contract | no_trade | fail closed before signal entry |
| normalized month clock and persistent attempt | no_trade / trade_entry | consume once before fallible gates |
| exact-year endpoint reconstruction | trade_entry | bounded completed D1 history |
| ascending sort, fixed weights, invariant, epsilon side map | trade_entry | deterministic native arithmetic only |
| fixed risk and frozen stop | trade_entry | framework sizing and market order |
| malformed-position repair | trade_entry / management | flatten only exact owned exposure |
| month and stale exits | management / close | close exact owned position only |
| no target, trail, partial, or intramonth signal exit | management | no optional management path |
| news and Friday overrides | no_trade / close | both news axes OFF; Friday close OFF |

## Reputable-Source Gate Findings

- R1: `PASS_WITH_QUANTILE_ESTIMATOR_AND_SINGLE_CFD_TRANSLATION_RISK`.
- R2: `PASS` for the exact locked mechanical contract.
- R3:
  `PASS_WITH_FIVE_YEAR_WARMUP_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`.
- R4: `PASS`; structural arithmetic only, with no prohibited trained signal
  or external runtime feed.

## Falsification And Requalification

Retire or fail on wrong calendar endpoints, missing exact years, wrong return
orientation, sort or weight defect, invariant mismatch, wrong side, same-month
retry, missing stop, invalid fixed-risk mode, wrong lifecycle,
nondeterminism, fewer than five completed positions in any full post-warm-up
year, zero positions, nonpositive governed economics, or downstream
correlation rejection. No result may be rescued by changing the sample,
weights, estimator, carrier, direction, risk, hold, spread cap, retry policy,
or by adding a filter.

## Card History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-30 | initial WTI exact-five same-calendar Harrell-Davis median card | G0 | APPROVED; build pending |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| Source Approval | 2026-08-30 | APPROVED_SOURCE | `decisions/2026-08-30_wti_same_calendar_harrell_davis5_source_approval.md` |
| G0 Research Intake | 2026-08-30 | APPROVED | `decisions/2026-08-30_qm5_41234_wti_same_calendar_harrell_davis5_g0.md` |
| Q01 Build Validation | 2026-08-30 | NOT_BUILT | pending |
| Q02 Baseline Screening | 2026-08-30 | NOT_ENQUEUED_Q01_PENDING | pending |

## Safety Boundary

This card authorizes one branch-only non-live EA build, exact slot-0 magic
allocation, strict compile/Q01 validation, one `RISK_FIXED` D1 backtest
setfile, and one paced Q02 enqueue if capacity permits.

It authorizes no manual backtest, live/demo/shadow/stress/optimization
setfile, terminal control, AutoTrading, `T_Live`, deploy or live manifest,
portfolio-gate mutation, portfolio admission, correlation waiver, or
certification claim.
