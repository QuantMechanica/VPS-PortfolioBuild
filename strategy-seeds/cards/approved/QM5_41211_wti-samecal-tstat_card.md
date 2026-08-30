---
card_schema_version: 2
type: strategy
strategy_id: KELOHARJU-RCORE-WTI-SAMECAL-TSTAT-2026_S01
variant_id: KELOHARJU-RCORE-WTI-SAMECAL-TSTAT-2026_S01
source_id: KELOHARJU-RCORE-WTI-SAMECAL-TSTAT-2026
ea_id: QM5_41211
slug: wti-samecal-tstat
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41211_wti-samecal-tstat_card.md
execution_contract_status: APPROVED
created: 2026-08-30
created_by: Research+Development
last_updated: 2026-08-30
g0_status: APPROVED
g0_decision: decisions/2026-08-30_qm5_41211_wti_same_calendar_tscore_g0.md
source_approval: decisions/2026-08-30_wti_same_calendar_tscore_source_approval.md
source_author: "Matti Keloharju; Juhani T. Linnainmaa; Peter Nyberg; R Core Team"
source_authors: "Matti Keloharju; Juhani T. Linnainmaa; Peter Nyberg; R Core Team"
source_citation: "Keloharju, Linnainmaa, and Nyberg (2016), Return Seasonalities, Journal of Finance 71(4), 1557-1590, DOI 10.1111/jofi.12398; R Core Team stats::t.test implementation pinned at wch/r-source commit bac583951b728e97b9786804d3b4081f0fe18df5."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Keloharju, M., Linnainmaa, J. T., and Nyberg, P. (2016). Return Seasonalities. The Journal of Finance 71(4), 1557-1590."
    location: "DOI 10.1111/jofi.12398; complete-read parent packet strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md"
    quality_tier: A
    role: same_calendar_month_commodity_information_explicit_crude_oil_membership_and_five_year_floor
  - type: primary_statistical_software_source
    citation: "R Core Team, stats::t.test implementation."
    location: "wch/r-source commit bac583951b728e97b9786804d3b4081f0fe18df5; blob 2c1e8d19a3150978e1b56f3ee8985f43a17382f6; complete GitHub-app read"
    quality_tier: A_primary_software
    role: arithmetic_mean_sample_variance_standard_error_and_t_score
  - type: governed_composite_source
    citation: "QuantMechanica bounded WTI same-calendar one-standard-error extraction."
    location: "strategy-seeds/sources/KELOHARJU-RCORE-WTI-SAMECAL-TSTAT-2026/source.md"
    quality_tier: internal_governed
    role: exact_calendar_endpoints_score_threshold_risk_and_lifecycle
strategy_mechanic: exact-up-to-ten-prior-year-same-calendar-month-wti-log-returns-arithmetic-mean-sample-standard-error-strict-absolute-t-score-above-one-monthly-directional-renewal
sources:
  - "[[sources/KELOHARJU-RCORE-WTI-SAMECAL-TSTAT-2026]]"
concepts:
  - "[[concepts/return-seasonality]]"
  - "[[concepts/studentized-mean]]"
  - "[[concepts/calendar-month-renewal]]"
indicators:
  - "[[indicators/completed-log-return]]"
  - "[[indicators/sample-standard-error]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, calendar-seasonality, same-calendar-month, studentized-mean, confidence-gate, monthly-renewal, atr-hard-stop, low-frequency, symmetric-long-short]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
magic: 412110000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: long_short
expected_trade_frequency: "Approximately 6-10 completed WTI monthly positions per full post-warm-up year; months inside the strict one-standard-error band consume flat."
expected_trades_per_year_per_symbol: 7
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_SINGLE_CFD_AND_LOCKED_THRESHOLD_RISK
r1_reasoning: "Peer-reviewed same-calendar commodity evidence explicitly includes crude oil, and complete pinned R Core primary software fixes the statistic; the exact absolute-WTI conjunction and threshold remain untested."
r2_mechanical: PASS
r2_reasoning: "Month clock, uniform normalized endpoints, exact Y-1..Y-10 bound, five-observation floor, arithmetic mean, n-1 sample variance, standard error, strict score band, side, consumed attempt, fixed risk, hard stop, spread, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_qualification: LONG_WARMUP_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK
r3_reasoning: "Registered XTIUSD.DWX D1 history and native MT5 state supply every runtime input; five-year warm-up, session labels, rolls, financing, and futures/CFD basis remain explicit."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, sums, sample variance, square root, comparisons, ATR risk controls, and execution state; no trained signal, banned signal indicator, or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: prior 10-year same-calendar search cap; minimum 5 observations; arithmetic mean; n-1 sample variance; standard error sqrt(variance/n); strict abs(t)>1.0 plus 1e-10 tolerance; 3000 D1 history bars; ATR(20)*3.5 frozen stop; 40-day stale exit; 1500-point spread ceiling."
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
review_focus: "Falsify a confidence-gated direct-WTI same-calendar sleeve outside the directional XAU/SP500/NDX/XNG book. Verify normalized completed endpoints, exact-year bounds, n-1 variance, standard error, strict score band, consumed month, fixed risk, frozen stop, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_tradable_month_bar, uniform_energy_label_normalization, exact_prior_year_same_calendar_months, completed_month_endpoints, no_current_month_price, five_sample_floor, ten_year_cap, arithmetic_mean, sample_variance_n_minus_one, standard_error_sqrt_variance_over_n, strict_absolute_t_band, sign_only_direction, monthly_attempt_state, risk_mode_dual, hard_stop_present, friday_close_disabled, next_month_exit, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-30 and decisions/2026-08-30_qm5_41211_wti_same_calendar_tscore_g0.md: R1 passes with complete peer-reviewed crude-oil seasonality evidence plus commit-pinned primary-software arithmetic and explicit untested-threshold risk; R2 locks calendar, sample, mean, n-1 variance, standard error, band, side, attempt, risk, stop, spread, and lifecycle; R3 uses registered native WTI D1 with warm-up/session/CFD risk; R4 is deterministic native arithmetic only. Corrected-root canonical dedup finds only the expected raw-mean WTI and paired-metals t-score fuzzy neighbors; manual review and a fixed abstention fixture separate raw mean, rank, robust-location, residual-momentum, and paired-metals families."
---

# QM5_41211 WTI Same-Calendar One-Standard-Error Seasonality

## Hypothesis

WTI production, refinery, transport, storage, consumption, hedging, and capital-
allocation pressures can recur in the same calendar month. A raw historical
mean can be driven by unstable dispersion, so this card tests only same-month
WTI means that exceed one estimated standard error from zero.

The rule supplies direct crude-oil exposure outside the stated
XAU/SP500/NDX/XNG directional book. Different underlying economics and a
monthly information clock do not prove low realized correlation. Q02 owns
activity and baseline economics; unchanged Q09 alone owns portfolio overlap.

## Source Traceability And Claim Boundary

The approved bounded packet is
`strategy-seeds/sources/KELOHARJU-RCORE-WTI-SAMECAL-TSTAT-2026/source.md`.
It was committed after the durable source approval
`decisions/2026-08-30_wti_same_calendar_tscore_source_approval.md`.

Keloharju, Linnainmaa, and Nyberg supply recurring same-calendar commodity-
return information, explicit crude-oil membership, monthly renewal, and a
five-year history floor. Commit-pinned R Core source supplies only arithmetic
mean, sample variance, standard error, and one-sample t-score arithmetic.

Neither source tests the exact absolute-WTI CFD rule, `abs(t)>1` gate,
Darwinex history, fixed risk, ATR stop, spread cap, or current book. No source
or sibling return, alpha, significance, profit factor, drawdown, trade count,
cost, CFD equivalence, or correlation statistic transfers. The threshold is a
pre-result QM falsification choice, not a conventional significance claim;
runtime computes no p-value.

## Source-Defined Rules

- Keloharju, Linnainmaa, and Nyberg support recurring same-calendar commodity-
  return information, explicit crude-oil membership, monthly renewal, and at
  least five prior years.
- Commit-pinned R Core source fixes only the arithmetic mean, sample variance
  with denominator `n-1`, standard error `sqrt(variance/n)`, and one-sample
  score.
- No source defines this one-CFD absolute sign, the `abs(t)>1` threshold,
  spread limit, fixed-risk sizing, ATR stop, or portfolio admission.

## QM Interpretations

- Translate the broad source information to WTI's own earlier same-calendar
  log returns and compare their studentized mean with zero.
- Lock exact years `Y-1..Y-10`, skip missing valid years without substitution,
  and require at least five observations.
- Treat `1.0+1e-10` as a pre-result confidence and abstention gate, not a
  p-value or conventional significance cutoff.
- Use one `RISK_FIXED=1000` budget, frozen ATR stop, durable monthly attempt,
  and next-month renewal as governed execution choices.
- Treat WTI diversification as an objective only; unchanged Q09 remains the
  sole realized-correlation authority.

## Formula

At normalized broker-month decision `(Y,M)`, reconstruct WTI calendar-month
`M` log returns in exact years `Y-1..Y-10`. Let the valid observations be
`r[0]..r[n-1]`, with `5<=n<=10`:

```text
mean     = sum(r[i]) / n
variance = sum((r[i]-mean)^2) / (n-1)
se       = sqrt(variance / n)
t        = mean / se

t > +1.0 + 1e-10 => BUY WTI
t < -1.0 - 1e-10 => SELL WTI
otherwise          => FLAT
```

The current month contributes no price. Require finite mean, strictly positive
finite variance and standard error, and finite score. Population variance,
raw mean alone, trimmed/Winsor/median/Hodges-Lehmann/Huber location, signed
rank, p-value, magnitude sizing, or a fallback estimator is not equivalent.

## Non-Duplicate Decision

The corrected-root canonical receipt
`artifacts/qm5_wti_samecal_tstat_preallocation_dedup_20260830.json`, SHA-256
`DB72E22F089B1BAB6AD22C1C597DC35D4D98AED64E7D8C96DA51550A8D1596BF`,
found no exact identity across 4,710 registry rows, 1,356 cards, and 45
Strategy Wiki nodes. It returned the two expected fuzzy neighbors.

- `QM5_20099_wti-samecal` follows every nonzero raw mean. This card divides
  the mean by its sample standard error and abstains inside a fixed band.
- `QM5_41191`, `QM5_41199`, `QM5_41201`, `QM5_41202`, and `QM5_41204` use
  signed-rank, trimmed-mean, Hodges-Lehmann, Winsorized-mean, and fixed-scale
  Huber states; none has this mean-standard-error gate.
- `QM5_41209_wti-seas-resid-mom` follows the standardized surprise of the
  just-completed month. This card forecasts the upcoming month from earlier
  occurrences of that calendar month.
- `QM5_41210_xauxag-samecal-tstat` applies the statistic to synchronized
  XAU-minus-XAG returns and manages two opposite metals legs. This card reads
  and trades only WTI, with different return orientation, position topology,
  risk, and economic exposure.

On `[0.020,0.015,0.010,0.005,0.001,-0.040]`, the raw mean is positive while
the one-sample score lies inside `[-1,+1]`. `QM5_20099` buys WTI; this card
stays flat. Dispersion and the abstention band are load bearing.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_WTI_SAMECAL_MEAN_STANDARD_ERROR_GATE_MONTHLY_DIRECTIONAL_CARRIER`.

## Markets, Timeframe, And Cadence

- Host and traded symbol: exact `XTIUSD.DWX`, D1, slot 0.
- Magic: `412110000`.
- Decision clock: first executable D1 tick after a genuine normalized broker-
  month transition.
- Formation: exact same calendar month in up to ten earlier years; at least
  five valid observations.
- Hold: next broker-month boundary; 40 elapsed days is stale repair.
- Expected pre-result cadence: approximately six to ten positions per full
  post-warm-up year; Q02 retires below five.

## Rules

The entry, exit, filter, and lifecycle rules below are the complete authorized
baseline. There is no signal-parameter sweep or fallback estimator.

## 4. Entry Rules

1. Require exact EA ID `41211`, `XTIUSD.DWX` D1 host, slot 0, magic
   `412110000`, fixed-risk inputs, both news axes OFF, and Friday close OFF.
2. Process malformed exposure and prior-month liquidation before entry-only
   gates. Evaluate only after a genuine normalized broker-month transition.
3. Accept one uniform native or `+1` energy-D1 label convention. Require the
   normalized current D1 date to equal broker date and use that same offset
   for every historical endpoint.
4. Persist current broker `yyyymm` before history, signal, news, spread,
   quote, ATR, sizing, margin, or submission. Never retry after any outcome.
5. From at most 3,000 completed D1 bars, reconstruct exact calendar-month `M`
   endpoints in years `Y-1..Y-10`. Each return needs the immediately preceding
   month endpoint and a confirming following bar. No current-month OHLC enters.
6. Skip a missing older year without replacing it; require at least five valid
   observations. Compute finite log returns, arithmetic mean, sample variance
   with `n-1`, standard error, and score. Invalid or nonpositive scale consumes
   flat.
7. Buy beyond `+1.0+1e-10`; sell below `-1.0-1e-10`; equality and the
   inclusive interior band consume flat. Magnitude never changes risk.
8. Require no owned exposure or same-month entry deal, positive finite Bid and
   Ask, `Ask>=Bid`, spread in `[0,1500]` points, completed ATR(20,D1), valid
   stop normalization, and valid symbol/volume metadata.
9. Submit one market position with `RISK_FIXED=1000` and a frozen
   `3.5*ATR(20,D1)` hard stop. Use no target or second attempt.

## 5. Exit Rules

1. Close on the first processed D1 bar of the next normalized broker month
   before considering a replacement position.
2. Close after 40 elapsed calendar days as final stale repair.
3. Immediately flatten duplicate, wrong-symbol, wrong-magic, invalid-side,
   missing-stop, invalid-volume, or invalid-open-time owned exposure.
4. The broker hard stop, framework kill switch, and framework close helper
   remain authoritative.
5. Friday close is disabled because the structural monthly hold spans
   weekends.
6. There is no intramonth signal exit, target, trail, break-even, partial
   close, scale-in, grid, martingale, pyramid, stop-and-reverse, or
   discretionary exit.

## 6. Filters (No-Trade Module)

- Wrong host, period, EA ID, slot, locked input, mid-month start, duplicate
  state, invalid label convention, endpoint, insufficient sample, invalid
  variance/standard error, interior score, quote, spread, ATR, sizing, or
  order state consumes the persisted month.
- Both news axes and legacy news are OFF; no external calendar or feed is
  consulted.
- No mean-only, rank, robust-location, recent-momentum, selected-month,
  inventory, storage, weather, curve, volume, event, or price-action fallback
  is allowed.
- Signal magnitude never changes fixed risk and equality stays flat.

## 7. Trade Management Rules

- Every tick begins with framework MAE tracking before any guard can return.
- Malformed, cross-month, and stale repair runs before every entry-only gate
  and remains retryable until owned exposure is flat.
- Own at most one position by exact EA ID, magic, and WTI symbol; never manage
  another EA's or manual trade.
- The entry hard stop is never moved. No score change alters an open position
  inside the month.
- Persist the consumed-month ledger in a terminal global variable so restart
  cannot generate a second attempt.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| Input | Locked value | Role |
|---|---:|---|
| `strategy_history_years` | 10 | maximum exact earlier years |
| `strategy_min_observations` | 5 | minimum valid same-calendar returns |
| `strategy_t_threshold` | 1.0 | strict absolute score band |
| `strategy_signal_tolerance` | 1e-10 | equality buffer |
| `strategy_history_bars_d1` | 3000 | bounded endpoint scan |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | stale repair only |
| `strategy_max_spread_points` | 1500 | nonnegative WTI entry-cost guard |
| `qm_friday_close_enabled` | false | preserve monthly hold |

No sample, estimator, threshold, month selection, direction, stop, hold,
spread, or lifecycle sweep is authorized.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Frozen hard stop: `3.5*ATR(20,D1)` from completed data.
- No target, signal-magnitude sizing, risk renewal, or compounding override.
- Invalid price, stop distance, tick value, tick size, volume step, minimum
  volume, lot, margin, or owned-position state consumes the month.
- This card creates no live, demo, shadow, stress, or optimization preset.

The single-CFD translation, small sample, unstable standard error, WTI gaps,
roll/financing, label mapping, threshold sparsity, and stop slippage can erase
the premise. Q09 alone may measure correlation with the certified book.

## Runtime Data Dependencies

Native `XTIUSD.DWX` D1 OHLC/timestamps, broker clock, symbol quotes and
properties, positions, deal history, and terminal-global attempt state only.
No curve, inventory, storage data, weather, volume, open interest, event feed,
API, CSV, optimizer artifact, trained output, or manual signal input.

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
6. New entry only when flat and current broker month is not consumed.

## Reputable-Source Gate Findings

- R1: `PASS_WITH_SINGLE_CFD_AND_LOCKED_THRESHOLD_RISK`.
- R2: `PASS` for the exact locked mechanical contract.
- R3: `PASS_WITH_LONG_WARMUP_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`.
- R4: `PASS`; structural arithmetic only, with no prohibited trained signal
  or external runtime feed.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact host/period/identity, locked risk/news/Friday inputs | No Trade | `Strategy_NoTradeFilter` |
| month clock, consumed attempt, endpoints, mean/variance/SE/score, side, spread, ATR | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers |
| malformed, later-month, and stale repair | Trade Management | `Strategy_ManageOpenPosition` plus lifecycle helper |
| monthly renewal and broker hard stop | Trade Close | lifecycle helper; `Strategy_ExitSignal` has no discretionary signal |
| news OFF | News hook | `Strategy_NewsFilterHook` returns false; both framework axes OFF |

## Kill Criteria

Retire rather than tune on zero positions; fewer than five completed positions
in any full post-warm-up year; nonpositive governed economics; wrong normalized
month, endpoint, sample membership, mean, denominator, standard error, score,
side, attempt, risk, stop, spread, lifecycle, or determinism; current-month
leakage; retry; missing stop; or registry mismatch.

No weak result may be rescued by lowering or moving the band, adopting raw
mean, rank, robust location, recent momentum, selected months, storage,
weather, volume, event, curve, or price-action filters, changing carrier, or
extending hold.

## Falsification And Requalification

A failure is evidence against this exact identity. A mechanically different
sample, estimator, threshold, direction, carrier, stop, spread, or lifecycle
requires a new card, dedup decision, and identity; it is not a patch.

## Validation Plan

Q01 must prove:

1. native and uniform `+1` labels select the genuine broker-month boundary,
   exact historical calendar month, preceding endpoint, and year rollover;
2. a missing older year is skipped without neighboring-year substitution and
   no current-month price enters;
3. five through ten observations produce exact mean, `n-1` sample variance,
   `sqrt(variance/n)`, score, strict thresholds, and side;
4. a fixed vector makes raw mean positive while this score remains flat,
   separating `QM5_20099`; fixtures also distinguish rank, robust-location,
   residual-momentum, and paired-metals logic;
5. durable `yyyymm` state prevents same-month retry after downstream failure
   and restart;
6. zero modeled spread remains reachable while crossed or excessive spread is
   rejected;
7. fixed-risk sizing uses one valid frozen completed-bar ATR stop; and
8. next-month close, malformed repair, stale guard, disabled Friday close,
   strict compile, schema lint, magic resolver, and setfile checks pass.

## Card History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-30 | initial WTI same-calendar one-standard-error card | G0 | APPROVED; build pending |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-30 | APPROVED; R1-R4 PASS | `decisions/2026-08-30_qm5_41211_wti_same_calendar_tscore_g0.md`; approved source packet |
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
