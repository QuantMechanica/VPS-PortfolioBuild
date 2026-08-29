---
card_schema_version: 2
type: strategy
strategy_id: KELOHARJU-MISHRA-XNG-SEASSURPRISE-2026_S01
variant_id: KELOHARJU-MISHRA-XNG-SEASSURPRISE-2026_S01
source_id: KELOHARJU-MISHRA-XNG-SEASSURPRISE-2026
ea_id: QM5_41208
slug: xng-seas-surprise-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41208_xng-seas-surprise-rv_card.md
execution_contract_status: APPROVED
created: 2026-08-30
created_by: Research+Development
last_updated: 2026-08-30
g0_status: APPROVED
g0_decision: decisions/2026-08-30_qm5_41208_xng_seasonal_surprise_reversion_g0.md
source_approval: decisions/2026-08-30_xng_seasonal_surprise_reversion_source_approval.md
source_author: "Matti Keloharju; Juhani T. Linnainmaa; Peter Nyberg; Vinod Mishra; Russell Smyth"
source_authors: "Matti Keloharju; Juhani T. Linnainmaa; Peter Nyberg; Vinod Mishra; Russell Smyth"
source_citation: "Keloharju, Linnainmaa, and Nyberg (2016), Return Seasonalities, Journal of Finance 71(4), 1557-1590, DOI 10.1111/jofi.12398; Mishra and Smyth (2016), Are Natural Gas Spot and Futures Prices Predictable?, Economic Modelling 54, 178-186, DOI 10.1016/j.econmod.2015.12.034."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Keloharju, M., Linnainmaa, J. T., and Nyberg, P. (2016). Return Seasonalities. The Journal of Finance 71(4), 1557-1590."
    location: "DOI 10.1111/jofi.12398; complete 57-page governed review strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md"
    quality_tier: A
    role: same_calendar_month_commodity_expectation_and_explicit_natural_gas_membership
  - type: peer_reviewed_trading_paper
    citation: "Mishra, V., and Smyth, R. (2016). Are Natural Gas Spot and Futures Prices Predictable? Economic Modelling 54, 178-186."
    location: "DOI 10.1016/j.econmod.2015.12.034; complete 36-page governed review strategy-seeds/sources/MISHRA-SMYTH-XNG-PRED-2016/source.md"
    quality_tier: A
    role: direct_natural_gas_fixed_frequency_contrarian_evidence_and_adverse_caveat
  - type: governed_composite_source
    citation: "QuantMechanica bounded XNG standardized seasonal-surprise reversion extraction."
    location: "strategy-seeds/sources/KELOHARJU-MISHRA-XNG-SEASSURPRISE-2026/source.md"
    quality_tier: internal_governed
    role: exact_conjunction_calendar_sample_score_risk_and_lifecycle
strategy_mechanic: monthly-xng-just-completed-log-return-minus-up-to-ten-prior-year-same-calendar-mean-divided-by-sample-standard-deviation-strict-half-sigma-contrarian-next-month
sources:
  - "[[sources/KELOHARJU-MISHRA-XNG-SEASSURPRISE-2026]]"
concepts:
  - "[[concepts/return-seasonality]]"
  - "[[concepts/seasonally-adjusted-reversal]]"
  - "[[concepts/calendar-month-renewal]]"
indicators:
  - "[[indicators/completed-month-log-return]]"
  - "[[indicators/sample-standard-deviation]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, natural-gas, calendar-seasonality, standardized-surprise, contrarian, monthly-renewal, atr-hard-stop, low-frequency, symmetric-long-short]
markets: [commodities, energy, natural_gas]
timeframes: [D1]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
single_symbol_only: true
logical_symbol: XNGUSD.DWX
symbol: XNGUSD.DWX
host_symbol: XNGUSD.DWX
symbol_slot: 0
magic: 412080000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: long_short
expected_trade_frequency: "Approximately 6-9 completed XNG monthly positions per full post-warm-up year at the locked half-standard-deviation band; Q02 must prove at least five in every full scored year or retire."
expected_trades_per_year_per_symbol: 7
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_CROSS_SOURCE_CONJUNCTION_AND_CFD_RISK
r1_reasoning: "Complete peer-reviewed Journal of Finance same-calendar commodity evidence with explicit natural-gas membership plus complete peer-reviewed Economic Modelling natural-gas contrarian evidence; the exact standardized conjunction remains untested."
r2_mechanical: PASS
r2_reasoning: "Month clock, uniform normalized endpoints, realized-sample exclusion, ten-year cap, five-sample floor, arithmetic mean, n-1 sample scale, strict score band, consumed attempt, fixed risk, hard stop, spread, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_qualification: ENERGY_LABEL_AND_CONTINUOUS_CFD_BASIS_RISK
r3_reasoning: "Registered XNGUSD.DWX D1 history and native MT5 state supply every runtime input; warm-up, D1 session labels, rolls, financing, and futures/CFD basis remain explicit."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, sums, sample variance, square root, comparisons, ATR risk controls, and execution state; no trained signal, banned signal indicator, or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: prior 10-year same-calendar search cap; minimum 5 observations; arithmetic mean; n-1 sample standard deviation; strict abs(z)>0.50 plus 1e-10 tolerance; 3000 D1 history bars; ATR(20)*3.5 frozen stop; 40-day stale exit; nonnegative modeled spread capped at 3000 points."
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
review_focus: "Falsify a monthly XNG stream that trades against only the just-completed return unexplained by recurring same-calendar history. Verify the information clock, uniform label convention, endpoint chronology, realized-sample exclusion, exact n-1 scale, strict contrarian band, durable attempt, fixed risk, frozen stop, and next-month close. Q09 alone may establish realized decorrelation from QM5_12567 and the current book."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_xng_carrier, first_month_bar_clock, uniform_energy_label_normalization, just_completed_month_mapping, completed_month_endpoints, no_current_month_price, realized_sample_exclusion, ten_year_search_cap, five_sample_floor, arithmetic_mean, sample_variance_n_minus_one, strict_surprise_band, contrarian_direction, monthly_attempt_state, monthly_renewal, risk_mode_dual, hard_stop_present, nonnegative_modeled_spread, friday_close_disabled, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-30 and decisions/2026-08-30_qm5_41208_xng_seasonal_surprise_reversion_g0.md: R1 passes with two complete peer-reviewed lineages and explicit untested-conjunction risk; R2 locks calendar, endpoints, exclusion, sample, mean, n-1 scale, score, side, attempt, risk, stop, spread, and lifecycle; R3 uses registered native XNG D1 with session/CFD risk; R4 is deterministic native arithmetic only. Corrected-root canonical dedup is CLEAN across 4,707 registry rows, 1,353 cards, and 45 Wiki nodes; manual review separates the incumbent RSI, unconditional monthly contrarian, upcoming-month seasonal-following, Huber, and paired-metals surprise families."
---

# QM5_41208 XNG Monthly Seasonal-Surprise Reversion

## Hypothesis

Natural-gas heating, cooling, storage, maintenance, LNG, and hedging pressures
can recur by calendar month, while gas prices also show fixed-frequency
contrarian behavior in the source literature. When the just-completed XNG
monthly return is unusually large after subtracting its own historical return
for that same calendar month, the unexpected component may reverse during the
following broker month.

This is a second XNG return stream, not a new asset class. Its monthly,
seasonally adjusted, symmetric surprise state is mechanically unrelated to
the incumbent two-day RSI pullback. That distinction does not prove low
realized correlation. Q02 owns density and baseline economics; unchanged Q09
alone owns portfolio overlap.

## Source Traceability And Claim Boundary

The approved bounded packet is
`strategy-seeds/sources/KELOHARJU-MISHRA-XNG-SEASSURPRISE-2026/source.md`,
SHA-256
`DAA4C8C70FCFB330F157AC4AC0CBAA3AD13FDC765D184AFFD80F88C588CF09BC`,
committed as `a6cb76267` after source approval `c69176b43` and before card
approval.

Keloharju, Linnainmaa, and Nyberg supply the same-calendar commodity
information object, explicit natural-gas membership, and a five-year history
floor. Mishra and Smyth supply direct natural-gas fixed-frequency contrarian
evidence and an explicit warning that the strongest source result may be
sample- or strategy-specific.

Neither source tests the exact standardized surprise, Darwinex continuous
CFD, threshold, fixed risk, ATR stop, spread cap, or current book. No source
or sibling return, alpha, significance, profit factor, drawdown, trade count,
cost, CFD equivalence, or portfolio-correlation statistic transfers.

## Non-Duplicate Decision

The corrected-root canonical receipt
`artifacts/qm5_xng_seassurprise_rv_preallocation_dedup_20260830.json`, SHA-256
`368080A3C487F6FE8655177D94C8AB6D61D0BC165FAD25B1BEDD7B945EDB121C`,
found no exact or fuzzy identity across 4,707 registry rows, 1,353 cards, and
45 Strategy Wiki nodes. Manual review fixes the boundary:

- `QM5_12567_cum-rsi2-commodity` is a trend-filtered, long-only cumulative-
  RSI2 pullback with a five-bar maximum hold. This card is symmetric,
  monthly, oscillator-free, and seasonally adjusted.
- `QM5_20054_xng-1m-contr` fades every nonzero completed-month sign. This card
  first removes recurring calendar expectation, scales the residual, and
  remains flat inside a strict band.
- `QM5_20100_xng-samecal` and `QM5_41205_xng-samecal-huber10` follow the
  historical location for the upcoming calendar month. This card observes
  the just-completed month and trades against only its unexpected component.
- `QM5_21517_xauxag-seas-rv` owns a two-leg precious-metals package. This card
  owns one natural-gas position and is supported by direct gas evidence.

Verdict:
`CLEAN_XNG_STANDARDIZED_SEASONAL_SURPRISE_REVERSION_AFTER_CANONICAL_AND_MANUAL_REVIEW`.

## Markets, Timeframe, And Formula

- Host and traded symbol: exact `XNGUSD.DWX`, D1, slot 0.
- Magic: `412080000`.
- Decision clock: first executable D1 tick after a genuine normalized broker-
  month transition.
- Formation: just-completed month plus that same calendar month in up to ten
  earlier years, excluding the realized observation and requiring at least
  five historical returns.
- Hold: next broker-month boundary; 40 calendar days is stale repair.

At decision month `M`, let `J=M-1` with exact year rollover:

```text
realized_J    = ln(XNG_end_J / XNG_end_(J-1))
sample_y      = the same XNG calendar-month return in earlier year y
seasonal_mean = sum(sample_y) / n
seasonal_sd   = sqrt(sum((sample_y-seasonal_mean)^2)/(n-1))
surprise_z    = (realized_J-seasonal_mean)/seasonal_sd

SELL iff surprise_z > +0.50 + 1e-10
BUY  iff surprise_z < -0.50 - 1e-10
FLAT otherwise
```

The realized observation is excluded. Population variance, simple returns,
the decision month's historical return forecast, raw prior-month sign, a
Huber/median/MAD location, or a rolling D1 score is not equivalent.

## Rules

The entry, exit, filter, and lifecycle rules below are the complete authorized
baseline. There is no signal-parameter sweep or fallback estimator.

### Entry Rules

1. Require exact EA ID `41208`, `XNGUSD.DWX` D1 host, slot 0, magic
   `412080000`, fixed-risk inputs, both news axes OFF, and Friday close OFF.
2. Process malformed exposure and prior-month liquidation before entry-only
   gates. Evaluate only after a genuine normalized broker-month transition.
3. Accept one uniform native or `+1` energy-D1 label convention. Require the
   normalized current D1 date to equal the broker date and apply the same
   offset to every historical endpoint.
4. Persist current broker `yyyymm` before history, signal, news, spread,
   quote, ATR, sizing, margin, or submission. Never retry after any outcome.
5. Reconstruct the exact just-completed month and immediately preceding
   completed month endpoint from at most 3,000 completed D1 bars. No current-
   month OHLC enters the signal.
6. For that completed calendar month, scan the exact previous ten years,
   excluding the realized year. Skip a missing older year without replacing
   it; require at least five valid observations.
7. Compute finite log returns, arithmetic mean, and sample standard deviation
   with denominator `n-1`. Nonpositive or nonfinite scale consumes flat.
8. Sell beyond `+0.50+1e-10`; buy below `-0.50-1e-10`; equality and the
   interior band consume flat. Signal magnitude never changes risk.
9. Require no owned exposure or same-month entry deal, positive finite Bid
   and Ask, `Ask>=Bid`, spread in `[0,3000]` points, completed ATR(20,D1), a
   valid normalized stop, and valid symbol/volume metadata.
10. Submit one market position with `RISK_FIXED=1000` and a frozen
    `3.5*ATR(20,D1)` hard stop. Use no target or second attempt.

### Exit Rules

1. Close on the first processed D1 bar of the next normalized broker month
   before considering a replacement position.
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

### Filters And Trade Management

- Wrong host, period, EA ID, slot, locked input, mid-month start, duplicate
  state, invalid history, insufficient sample, invalid scale, interior score,
  quote, spread, ATR, sizing, or order state consumes the persisted month.
- Both news axes and legacy news are OFF; no external calendar or feed is
  consulted.
- Malformed, cross-month, and stale repair runs before every entry-only gate
  and remains retryable until owned exposure is flat.
- The entry hard stop is never moved. No signal reversal changes an open
  position inside the month.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| Input | Locked value | Role |
|---|---:|---|
| `strategy_history_years` | 10 | maximum earlier same-calendar years |
| `strategy_min_observations` | 5 | minimum valid historical returns |
| `strategy_entry_z` | 0.50 | strict standardized-surprise band |
| `strategy_signal_tolerance` | 1e-10 | strict equality buffer |
| `strategy_history_bars_d1` | 3000 | bounded endpoint scan |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | stale repair only |
| `strategy_max_spread_points` | 3000 | nonnegative XNG entry-cost guard |
| `qm_friday_close_enabled` | false | preserve monthly hold |

No sample, estimator, threshold, month selection, direction, stop, hold,
spread, or lifecycle sweep is authorized.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Frozen hard stop: `3.5*ATR(20,D1)` from completed data.
- No target, signal-magnitude sizing, risk renewal, or compounding override.
- Invalid price, stop distance, tick value, tick size, volume step, minimum
  volume, lot, margin, or position composition consumes the month.
- This card creates no live, demo, shadow, stress, or optimization preset.

The cross-source conjunction and single continuous CFD are untested. History
warm-up, unstable sample dispersion, natural-gas gaps, roll/financing, label
mapping, threshold sparsity, and stop slippage can erase the premise. Q09
alone may measure correlation with the incumbent XNG sleeve or wider book.

## Data Requirements

Native `XNGUSD.DWX` D1 OHLC/timestamps, broker clock, symbol quotes and
properties, positions, deal history, and terminal-global attempt state only.
No curve, inventory, storage surprise, weather, volume, open interest, event
feed, API, CSV, optimizer artifact, trained output, or manual signal input.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact host/period/identity, locked risk/news/Friday inputs | No Trade | `Strategy_NoTradeFilter` |
| month clock, consumed attempt, endpoints, sample, mean/scale, score, side, spread, ATR | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers |
| malformed, later-month, and stale repair | Trade Management | `Strategy_ManageOpenPosition` plus lifecycle helper |
| monthly renewal and broker hard stop | Trade Close | lifecycle helper; `Strategy_ExitSignal` has no discretionary signal |
| news OFF | News hook | `Strategy_NewsFilterHook` returns false; both framework axes OFF |

## Kill Criteria

Retire rather than tune on zero trades; fewer than five completed positions in
any full post-warm-up year; nonpositive governed economics; wrong normalized
month, endpoint, exclusion, sample membership, mean, denominator, scale,
score, side, attempt, risk, stop, spread, lifecycle, or determinism; current-
month leakage; retry; missing stop; or registry mismatch.

No weak result may be rescued by adopting unconditional one-month reversal,
forecasting the upcoming calendar month, selecting months, moving the band,
changing estimator, adding trend, storage, weather, volume, event, curve, or
price-action filters, changing the carrier, or extending the hold.

## Validation Plan

Q01 must prove:

1. native and uniform `+1` labels select the genuine broker-month boundary,
   just-completed month, preceding endpoint, and December/January rollover;
2. the realized observation never enters the earlier-year sample and a
   missing older year is skipped without neighboring-year substitution;
3. five through ten observations produce the exact arithmetic mean, `n-1`
   sample standard deviation, strict score boundaries, and contrarian side;
4. fixtures distinguish unconditional one-month contrarian, upcoming-month
   raw-mean and Huber seasonal following, and paired-metals surprise logic;
5. no current-month OHLC, tick path, volume, or external value enters signal;
6. durable `yyyymm` state prevents same-month retry after downstream failure
   and restart;
7. zero modeled spread remains reachable while crossed or excessive spread
   is rejected;
8. fixed-risk sizing uses one valid frozen completed-bar ATR stop; and
9. next-month close, malformed repair, stale guard, disabled Friday close,
   strict compile, schema lint, magic resolver, setfile, and build checks pass.

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-30 | APPROVED; R1-R4 PASS | `decisions/2026-08-30_qm5_41208_xng_seasonal_surprise_reversion_g0.md`; approved source packet |
| Q01 Build Validation | 2026-08-30 | NOT_BUILT | deterministic magic allocation and build pending |
| Q02 Baseline Screening | 2026-08-30 | NOT_ENQUEUED_Q01_PENDING | no work item before compile/review PASS |

## Safety Boundary

This card authorizes one branch-only non-live build, deterministic slot-0
magic allocation, strict Q01 validation, one `RISK_FIXED` D1 backtest setfile,
and one paced Q02 enqueue only after prerequisites and a non-binding CPU check.
It does not authorize a manual backtest, live/demo/shadow/stress/optimization
preset, terminal control, AutoTrading, `T_Live`, deploy or live manifest,
portfolio-gate change, portfolio admission, correlation waiver, or queue
deletion.

## Version History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-30 | initial XNG standardized seasonal-surprise reversion card | G0 | APPROVED; build pending |
