---
card_schema_version: 2
type: strategy
strategy_id: KELOHARJU-WTI-MEDCAL-2026_S01
variant_id: KELOHARJU-WTI-MEDCAL-2026_S01
source_id: KELOHARJU-WTI-MEDCAL-2026
ea_id: QM5_41055
slug: wti-medcal
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41055_wti-medcal_card.md
execution_contract_status: APPROVED
created: 2026-08-18
created_by: Research+Development
last_updated: 2026-08-18
g0_status: APPROVED
g0_decision: decisions/2026-08-18_wti_median_same_calendar_g0.md
source_approval: decisions/2026-08-18_wti_median_same_calendar_source_approval.md
source_author: "Matti Keloharju; Juhani T. Linnainmaa; Peter Nyberg"
source_authors: "Matti Keloharju; Juhani T. Linnainmaa; Peter Nyberg"
source_citation: "Keloharju, M., Linnainmaa, J. T., and Nyberg, P. (2016). Return Seasonalities. The Journal of Finance 71(4), 1557-1590. DOI 10.1111/jofi.12398; NBER Working Paper 20815."
source_citations:
  - type: peer_reviewed_paper
    citation: "Keloharju, M., Linnainmaa, J. T., and Nyberg, P. (2016). Return Seasonalities. The Journal of Finance 71(4), 1557-1590."
    location: "DOI 10.1111/jofi.12398; complete-read record strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md"
    quality_tier: A
    role: same_calendar_month_return_seasonality_and_crude_oil_universe_lineage
strategy_mechanic: prior-ten-year-same-calendar-month-log-return-median-sign-monthly-wti-renewal
sources:
  - "[[sources/KELOHARJU-WTI-MEDCAL-2026]]"
concepts:
  - "[[concepts/return-seasonality]]"
  - "[[concepts/robust-order-statistic]]"
  - "[[concepts/calendar-month-renewal]]"
indicators:
  - "[[indicators/completed-log-return]]"
  - "[[indicators/sample-median]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, calendar-seasonality, same-calendar-month, robust-median, monthly-renewal, atr-hard-stop, low-frequency, symmetric-long-short]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
magic: 410550000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 10-12 completed XTI monthly positions per full post-warm-up year; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 11
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_HISTORY_AND_SESSION_LABEL_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PASS
q02_status: NOT_ENQUEUED_CPU_CEILING
review_focus: "Falsify a direct-WTI robust same-calendar-month sleeve outside the certified XAU/SP500/NDX/XNG book. Verify uniform D1-label normalization, exact historical month endpoints, five-to-ten observation sample, even/odd median arithmetic, sign-only direction, durable monthly attempt, monthly renewal, and absence of current-month leakage. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_month_bar_clock, uniform_energy_label_normalization, exact_prior_year_same_calendar_months, completed_month_endpoints, no_current_month_price, five_sample_floor, ten_year_cap, even_odd_median, sign_only_direction, monthly_attempt_state, monthly_renewal, risk_mode_dual, hard_stop_present, friday_close_disabled, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 uses a named-author peer-reviewed Journal of Finance paper with DOI, complete-read evidence, explicit crude-oil inclusion, and explicit disclosure that the sample median is a QM robustness translation; R2 locks every endpoint, sample bound, median convention, direction, attempt, risk, and lifecycle; R3 uses registered native XTI D1 with the binding 2017-start warm-up and D1 session-label risks explicit; R4 is deterministic calendar, sorting, logarithm, and execution arithmetic without trained logic, banned signal indicators, or an external feed; canonical dedup returned CLEAN and manual family review separated the order-statistic median from all mean-based, paired-rank, and fixed-month systems."
---

# QM5_41055 WTI Median Same-Calendar Seasonality

## Hypothesis

WTI calendar-month returns may contain recurring information associated with
the same calendar month in prior years. A bounded sample median should retain
the recurring sign when it is supported by the central historical
observations while preventing one isolated oil-shock year from determining
the signal. At the first executable D1 bar of each broker month, the candidate
trades the median sign of up to ten completed returns for that same calendar
month and renews at the next month boundary.

This is a falsifiable, direct-WTI calendar-seasonality robustness translation.
It is not a replication of the paper's diversified futures portfolio or
arithmetic-mean ranking, and it is not evidence of standalone profitability,
CFD/futures equivalence, or low correlation with the certified book.

## Source Traceability And Claim Boundary

The governed packet is
`strategy-seeds/sources/KELOHARJU-WTI-MEDCAL-2026/source.md`, approved before
card extraction in
`decisions/2026-08-18_wti_median_same_calendar_source_approval.md` at commit
`5c51e1248`.

Keloharju, Linnainmaa, and Nyberg supply the same-calendar-month return
seasonality construction, a five-year history floor, and crude oil inside the
paper's 24-futures commodity panel. The source uses an arithmetic mean and a
cross-sectional portfolio. The bounded ten-year sample, sample median,
absolute-sign single-WTI position, CFD carrier, fixed risk, stop, spread cap,
attempt ledger, and monthly lifecycle are QM choices. No source performance,
significance, cost, drawdown, density, or correlation result transfers.

## Non-Duplicate Decision

The canonical pre-allocation checker scanned 4,542 EA-registry rows and 625
root-card files and returned `CLEAN` with no exact or fuzzy identity. Manual
family review fixes the material boundaries:

- `QM5_20099_wti-samecal` uses the arithmetic mean of prior same-calendar
  returns. This card uses the bounded sample median and forbids mean fallback;
  an isolated extreme observation can therefore change 20099's sign without
  changing this card's sign.
- `QM5_20136`, `QM5_20205`, `QM5_20251`, and `QM5_20137` retain a historical
  mean and add trend, prior-month, sign-breadth, or pullback conjunctions that
  are absent here.
- `QM5_13115` and `QM5_20190` rank two synchronized energy legs and require a
  paired basket; this card is one absolute-sign WTI position.
- Fixed favorable-month WTI systems do not recompute a prior-year order
  statistic.
- `QM5_12567_cum-rsi2-commodity` is a daily long-only cumulative-RSI
  pullback, not monthly calendar seasonality.

Verdict:
`CLEAN_WTI_PRIOR_TEN_YEAR_SAME_CALENDAR_RETURN_MEDIAN_SIGN_MONTHLY_RENEWAL_AFTER_CANONICAL_AND_FAMILY_REVIEW`.

## Markets, Clock, And Formula

- Host and target: exact `XTIUSD.DWX`, D1, slot 0, magic `410550000`.
- Decision clock: first executable tick of the first available D1 bar in a new
  broker calendar month.
- Session labels: accept only native same-day D1 labels or one uniform `+1`
  calendar-day energy offset. The normalized current D1 date must equal the
  current broker date; apply that one offset to every historical endpoint.
- Formation: exact same calendar month in years `Y-1` through `Y-10` only.
- Minimum sample: five valid completed monthly observations; maximum ten.
- Ordinary exit and renewal: the first executable tick in the next broker
  calendar month.
- Repair exit: 35 elapsed calendar days.
- Expected cadence: approximately 10-12 completed positions/year after
  warm-up.

For target calendar month `M` in historical year `H`:

```text
pre_close(H,M) = close of the immediately preceding D1 bar, whose broker date
                 must be in the immediately preceding calendar month
end_close(H,M) = close of the final D1 bar in (H,M), confirmed by a following
                 D1 bar in the immediately following calendar month
r(H,M)         = ln(end_close(H,M) / pre_close(H,M))

collect valid r(Y-k,M), k = 1..10
require 5 <= n <= 10
sort ascending

odd n:  seasonal_state = r[n/2]
even n: seasonal_state = (r[n/2-1] + r[n/2]) / 2

seasonal_state > +1e-12 => BUY XTIUSD.DWX
seasonal_state < -1e-12 => SELL XTIUSD.DWX
otherwise                => consume month flat
```

The immediately preceding/following calendar-month checks wrap December and
January exactly. A missing, duplicated, out-of-order, nonpositive, nonfinite,
partial, or nonadjacent endpoint invalidates that historical observation; it
may not be replaced by a different year.

## Rules

These rules are the complete baseline. No arithmetic-mean fallback, fixed
month list, recent-return confirmation, trend, inventory, event, curve,
volume, range, breakout, oscillator, volatility signal, or external-data
filter is authorized.

## 4. Entry Rules

1. Evaluate only on a new `XTIUSD.DWX` D1 bar while attached to exact
   `XTIUSD.DWX`, D1, EA ID 41055, slot 0.
2. Process malformed and stale owned exposure before every entry-only gate.
3. If owned exposure was opened in an earlier broker `yyyymm`, close it before
   considering the new month. Do not open while any owned exposure remains.
4. Accept only a native same-day D1 label or one uniform `+1` calendar-day
   energy offset, require the normalized current D1 date to equal broker date,
   and apply that offset to all historical labels. Enter only on the first
   normalized D1 bar of a genuine new broker calendar month. A mid-month first
   attachment consumes no historical opportunity and must remain flat until
   the next genuine boundary.
5. Derive the attempt key from the decision month's broker `yyyymm`. Persist
   it before history validation, news, spread, quote, ATR, sizing, or order
   gates. Never retry that month, including after restart or order failure.
6. For each exact year `Y-1` through `Y-10`, locate the first and last D1 bars
   in calendar month `M`. Require strict time order, the immediate prior D1
   bar to belong to the immediately preceding calendar month, and the
   immediate next D1 bar to belong to the immediately following calendar
   month. Use only the prior-bar close and final in-month close.
7. Skip an invalid historical year without substitution. Require at least
   five and no more than ten valid returns. Every endpoint must be positive
   and finite. Current-month open, high, low, close, volume, and tick price
   are forbidden from the signal.
8. Sort the valid log returns ascending. For odd `n`, select index `n/2`; for
   even `n`, average indices `n/2-1` and `n/2`. No arithmetic mean across the
   full sample, weighting, winsorization, interpolation, or fallback exists.
9. A median above `+1e-12` buys WTI; below `-1e-12` sells WTI. A value within
   the inclusive tolerance band consumes the month flat. Magnitude never
   changes size.
10. Require valid completed-bar ATR(20,D1). Place one frozen hard stop at
    `3.5 * ATR`; use no take-profit.
11. Require a valid quote and no genuinely positive spread above 1,500
    points. Modeled zero `.DWX` spread is valid.
12. Submit one market order once. No pending order, retry, scale-in, grid,
    martingale, pyramid, hedge, or companion leg exists.

## 5. Exit Rules

1. At the first observed D1 bar in a later broker `yyyymm`, close owned
   exposure before evaluating that month's signal.
2. Close after 35 elapsed calendar days as a final stale guard.
3. Immediately flatten duplicate, wrong-symbol, wrong-magic, invalid-side,
   missing-stop, invalid-volume, or invalid-open-time exposure.
4. The frozen broker hard stop and framework kill switch remain authoritative.
5. Framework Friday close is disabled for this monthly identity.
6. No target, reversal, trailing stop, break-even move, partial exit, or
   discretionary close is authorized.

## 6. Filters (No-Trade Module)

- Exact host, D1, EA 41055, slot 0, and registered magic.
- Framework kill switch and ownership checks remain authoritative.
- Both news axes are OFF; the signal uses completed native price history.
- Uniform native/`+1` label normalization, genuine new-month boundary, durable
  attempt, exact historical endpoint identity, sample floor, median
  arithmetic, sign tolerance, quote, spread, ATR, sizing, and stop geometry
  must be valid.
- Failure after attempt persistence consumes the month.

## 7. Trade Management Rules

- Own at most one position under magic `410550000`.
- Freeze the original hard stop; never widen, trail, or remove it.
- Run malformed, later-month, and stale repair on every tick before entry
  logic.
- Persist the last attempted broker `yyyymm` in terminal global state so a
  restart cannot create a second monthly attempt.
- Do not add, pyramid, grid, hedge, partially close, or reverse.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Frozen hard stop: `3.5 * ATR(20,D1)` from completed data.
- No take-profit and no signal-magnitude sizing.
- Invalid stop distance, tick value, tick size, volume step, minimum volume,
  computed lot, or price consumes the month.
- This card creates no live, demo, shadow, stress, or optimization preset.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| Input | Locked value | Role |
|---|---:|---|
| `strategy_lookback_years` | 10 | exact prior-year cap |
| `strategy_min_observations` | 5 | exact valid-sample floor |
| `strategy_signal_epsilon` | 1e-12 | sign/tie boundary |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 35 | stale repair only |
| `strategy_max_spread_points` | 1500 | WTI entry cost guard |
| `qm_friday_close_enabled` | false | preserve monthly hold |

No sweep, mean fallback, month selection, endpoint, direction, sample bound,
stop, or lifecycle change is authorized.

## Data Requirements

- Native `XTIUSD.DWX` D1 OHLC and timestamps from the registered factory
  history route.
- Broker clock, symbol quotes/properties, positions, deal history, and terminal
  global variables.
- No continuous-futures file, roll map, inventory, volume, open interest,
  futures curve, event calendar, API, CSV, optimizer artifact, or manual
  signal input.

## Source-Defined Rules

The paper defines recurring same-calendar-month return information, includes
crude oil in the commodity universe, and applies a five-year history floor.
It uses arithmetic means and cross-sectional portfolios; it does not define
this median, absolute-sign position, CFD implementation, stop, or lifecycle.

## QM Interpretations

QM fixes the native/`+1` uniform energy-label normalization, ten-year cap,
exact monthly endpoints, even/odd sample median, absolute sign and epsilon,
direct CFD carrier, durable attempt, fixed risk, ATR stop, spread ceiling,
monthly renewal, and stale guard. They are pre-result falsification choices.

## Framework Execution Overrides

The framework kill switch, ownership checks, fixed-risk sizing contract,
position/deal state, and order handling remain authoritative. Both news axes
and framework Friday close are OFF. This non-live card creates no live
mapping, deployment manifest, execution-contract registry row, or promotion
entitlement.

## Exit Precedence

1. Framework kill switch and broker hard stop remain authoritative.
2. Malformed, duplicate, wrong-side, or missing-stop exposure is flattened.
3. First observed D1 boundary in a later broker month is the ordinary exit.
4. The 35-day close repairs only a survivor.

## Runtime Data Dependencies

Runtime uses only native D1 OHLC/timestamps, broker time, current quotes,
symbol contract properties, positions, deals, and terminal-global attempt
state. It has no external feed, fitted artifact, trained output, optimizer
artifact, or manual signal input.

## Falsification And Requalification

Q02 retires the identity on zero trades, fewer than five completed positions
per full post-warm-up year, nonpositive governed economics, wrong endpoint
identity, current-month leakage, fewer than five valid prior-year returns,
wrong even/odd median arithmetic, mean fallback, wrong sign, late/repeated
entry, wrong monthly lifecycle, nondeterminism, invalid risk mode, or
insufficient local history. Any change to estimator, endpoint, sample bounds,
direction, stop, or hold creates a new identity. Q09 alone may establish
realized portfolio correlation.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact host/period, boundary, attempt, history, endpoints, median, side, spread, ATR | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers |
| malformed, later-month, and stale repair | Trade Management | `Strategy_ManageOpenPosition` plus lifecycle helper |
| monthly renewal and survivor repair | Trade Close | strategy lifecycle helper; Friday close disabled |
| kill switch, ownership, fixed-risk mode | Framework No-Trade | standard framework orchestration |
| news OFF | News hooks | `Strategy_NewsFilterHook` returns false; both modes OFF |

## Kill Criteria

Retire rather than tune on fewer than five completed positions per full post-
warm-up year; zero trades; nonpositive governed economics; wrong or partial
monthly endpoints; current-month leakage; invalid sample count; incorrect
median or sign; retry; missing stop; wrong monthly lifecycle; nondeterminism;
or registry/risk mismatch.

No weak result may be rescued by reverting to the historical mean, selecting
months, adding recent trend/return, inventory, event, curve, volume,
volatility, or price-action filters, changing the sample bounds, or extending
the hold.

## Validation Plan

Q01 must prove:

1. native and uniform `+1` label conventions select only the exact normalized
   month boundary, and same-calendar returns use only completed month endpoints
   for years `Y-1` through `Y-10`, with December/January wrapping and invalid
   years skipped without substitution;
2. five-to-ten sample bounds plus odd/even median arithmetic, tie tolerance,
   and direction are exact, including an outlier case where mean and median
   signs disagree;
3. no current-month OHLC, volume, or tick price enters the signal;
4. persistent `yyyymm` attempts prevent same-month retry after every
   downstream failure and restart;
5. fixed-risk sizing uses a valid frozen completed-bar ATR stop;
6. next-month close, malformed repair, stale guard, and disabled Friday close
   remain reachable; and
7. strict compile, card lint, build checks, setfile schema, magic resolver,
   and static Q01 validation pass.

Q02 alone may measure density and baseline economics. Q09 alone may establish
realized correlation with the certified book.

## Version History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-18 | initial robust median same-calendar WTI card | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-18 | APPROVED | `decisions/2026-08-18_wti_median_same_calendar_g0.md` |
| Q01 Build Validation | 2026-08-18 | PASS | `framework/build/compile/20260818_004637/QM5_41055_wti-medcal.compile.log`; `D:/QM/reports/framework/21/build_check_20260818_004637.json`; `D:/QM/reports/pipeline/QM5_41055/P1/P1_QM5_41055_result.json` |
| Q02 Baseline Screening | 2026-08-18 | NOT_ENQUEUED_CPU_CEILING | `docs/ops/evidence/2026-08-18_qm5_41055_wti_median_same_calendar_q01_q02_capacity_stop.md` |

## Safety Boundary

This card authorizes a non-live build, Q01 validation, one D1 backtest setfile,
and one paced target-only Q02 enqueue only below the tester and CPU ceilings.
It does not authorize a manual backtest, tester control, live/demo/shadow/
stress/optimization preset, AutoTrading, `T_Live`, a deploy or T_Live
manifest, portfolio-gate change, portfolio admission, decorrelation claim, or
correlation waiver.
