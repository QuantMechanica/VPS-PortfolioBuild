---
card_schema_version: 2
type: strategy
strategy_id: KELOHARJU-HUBER-WTI-SAMECAL10-2026_S01
variant_id: KELOHARJU-HUBER-WTI-SAMECAL10-2026_S01
source_id: KELOHARJU-HUBER-WTI-SAMECAL10-2026
ea_id: QM5_41204
slug: wti-samecal-huber10
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41204_wti-samecal-huber10_card.md
execution_contract_status: APPROVED
created: 2026-08-29
created_by: Research+Development
last_updated: 2026-08-29
g0_status: APPROVED
g0_decision: decisions/2026-08-29_qm5_41204_wti_same_calendar_huber10_g0.md
source_approval: decisions/2026-08-29_wti_same_calendar_huber10_source_approval.md
source_author: "Matti Keloharju; Juhani T. Linnainmaa; Peter Nyberg; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; Peter J. Huber"
source_authors: "Matti Keloharju; Juhani T. Linnainmaa; Peter Nyberg; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; Peter J. Huber"
source_citation: "Keloharju, Linnainmaa, and Nyberg (2016), Return Seasonalities, Journal of Finance 71(4), 1557-1590, DOI 10.1111/jofi.12398; Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250, DOI 10.1016/j.jfineco.2011.11.003; Huber (1964), Robust Estimation of a Location Parameter, Annals of Mathematical Statistics 35(1), 73-101, DOI 10.1214/aoms/1177703732."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Keloharju, M., Linnainmaa, J. T., and Nyberg, P. (2016). Return Seasonalities. The Journal of Finance 71(4), 1557-1590."
    location: "DOI 10.1111/jofi.12398; complete-read packet strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md"
    quality_tier: A
    role: same_calendar_month_return_information_crude_oil_membership_and_history_floor
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; governed WTI lineage in strategy-seeds/sources/MOP-WTI-HUBER-2026/source.md"
    quality_tier: A
    role: explicit_wti_own_return_and_monthly_renewal_lineage
  - type: peer_reviewed_statistics_paper
    citation: "Huber, P. J. (1964). Robust Estimation of a Location Parameter. The Annals of Mathematical Statistics 35(1), 73-101."
    location: "DOI 10.1214/aoms/1177703732; bounded arithmetic in strategy-seeds/sources/MOP-WTI-HUBER-2026/source.md"
    quality_tier: A
    role: bounded_influence_location_lineage_only
  - type: governed_composite_source
    citation: "QuantMechanica bounded WTI exact-ten-year same-calendar fixed-step Huber extraction."
    location: "strategy-seeds/sources/KELOHARJU-HUBER-WTI-SAMECAL10-2026/source.md"
    quality_tier: internal_governed
    role: exact_calendar_endpoints_sample_scale_iterations_risk_and_lifecycle
strategy_mechanic: exact-prior-ten-year-same-calendar-month-wti-log-returns-even-median-mad-fixed-scale-thirty-two-update-huber-location-sign-monthly-renewal
sources:
  - "[[sources/KELOHARJU-HUBER-WTI-SAMECAL10-2026]]"
concepts:
  - "[[concepts/return-seasonality]]"
  - "[[concepts/robust-return-location]]"
  - "[[concepts/calendar-month-renewal]]"
indicators:
  - "[[indicators/completed-log-return]]"
  - "[[indicators/huber-m-location]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, calendar-seasonality, same-calendar-month, robust-location, bounded-influence, monthly-renewal, atr-hard-stop, low-frequency, symmetric-long-short]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
magic: 412040000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: long_short
expected_trade_frequency: "Approximately 10-12 completed XTI monthly positions per full post-warm-up year; an invalid exact year, endpoint, MAD, iteration, or tie-band state consumes the month flat."
expected_trades_per_year_per_symbol: 10
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_COMPOSITE_ESTIMATOR_AND_CFD_TRANSLATION_RISK
r1_reasoning: "Complete peer-reviewed same-calendar commodity evidence with explicit crude-oil membership plus governed peer-reviewed WTI own-return and Huber bounded-location lineage; the exact ten-year standalone-CFD conjunction remains untested."
r2_mechanical: PASS
r2_reasoning: "Month clock, uniform normalized endpoints, exact Y-1..Y-10 sample, even median/MAD, fixed scale, tuning, weight equation, 32 updates, sign band, consumed attempt, fixed risk, hard stop, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_qualification: LONG_WARMUP_AND_CONTINUOUS_CFD_BASIS_RISK
r3_reasoning: "Registered XTIUSD.DWX D1 history and native MT5 state supply every runtime input; ten-year warm-up, D1 session labels, rolls, and futures/CFD basis remain explicit."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, sorting, absolute deviations, fixed arithmetic, comparisons, ATR risk controls, and execution state; no trained signal, banned signal indicator, or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: exact prior 10 same-calendar years and all 10 required; even median and even raw MAD; scale 1.4826*MAD; tuning 1.5; fixed scale; exact 32 reweight updates; sign epsilon 1e-12; 3000 D1 history bars; ATR(20)*3.5 stop; 35-day stale exit; 1500-point entry spread ceiling."
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
review_focus: "Falsify a direct-WTI robust same-calendar sleeve outside the directional XAU/SP500/NDX/XNG book. Verify uniform D1-label normalization, exact Y-1..Y-10 completed endpoints, even median/MAD, frozen scale, exact weights and 32 updates, strict sign direction, consumed month, fixed risk, frozen stop, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_month_bar_clock, uniform_energy_label_normalization, exact_prior_ten_years, exact_same_calendar_months, completed_month_endpoints, no_current_month_price, ten_of_ten_sample, even_median, even_mad, frozen_huber_scale, huber_weight_equation, exactly_thirty_two_updates, sign_epsilon, sign_only_direction, monthly_attempt_state, monthly_renewal, risk_mode_dual, hard_stop_present, friday_close_disabled, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-29 and decisions/2026-08-29_qm5_41204_wti_same_calendar_huber10_g0.md: R1 passes with peer-reviewed same-calendar crude-oil evidence and governed peer-reviewed WTI own-return/Huber lineage; R2 locks calendar, endpoints, exact sample, median/MAD, scale, weights, update count, side, attempt, risk, stop, and lifecycle; R3 uses registered native XTI D1 with warm-up/session/CFD risk; R4 is deterministic native arithmetic only. Canonical dedup found only the expected raw-mean neighbor, and manual review plus a fixed fixture proves directional non-equivalence."
---

# QM5_41204 WTI Ten-Year Same-Calendar Huber Seasonality

## Hypothesis

WTI demand, refinery utilization, storage, maintenance, weather, hedging, and
capital-allocation pressures may recur in the same calendar month. A raw
historical mean is vulnerable to one oil-shock year. This rule estimates the
central direction of the exact ten prior returns for the upcoming calendar
month with a fixed-scale bounded-influence Huber location, then follows only
its sign for one month.

Direct WTI supplies crude-oil exposure absent from the stated directional
XAU, SP500, NDX, and XNG book. That economic distinction does not prove low
realized correlation. Q02 owns density/economics and unchanged Q09 owns
portfolio overlap.

## Source Traceability And Claim Boundary

The approved bounded packet is
`strategy-seeds/sources/KELOHARJU-HUBER-WTI-SAMECAL10-2026/source.md`, SHA-256
`3EB1889CE3A5DFCBCF7AAC69F8FE1FDF103F70EEDBEE50D930CBCEE770D23531`,
authorized by
`decisions/2026-08-29_wti_same_calendar_huber10_source_approval.md` at commit
`480eace0a` before extraction.

Keloharju, Linnainmaa, and Nyberg supply the same-calendar-month information
object, explicit crude-oil membership, and history floor. Moskowitz, Ooi, and
Pedersen supply WTI own-return and monthly-renewal lineage. Huber supplies the
bounded-influence location family; the governed parent packet fixes the exact
iteration arithmetic. No source tests this exact direct-WTI seasonal
position.

No source return, alpha, probability, significance, density, profit factor,
drawdown, transaction cost, CFD equivalence, decorrelation, or portfolio
statistic transfers.

## Source-Defined Rules

- Keloharju, Linnainmaa, and Nyberg define the recurring same-calendar-month
  information object, monthly renewal, a history floor, and explicit crude-oil
  membership in a broad commodity-futures portfolio.
- Moskowitz, Ooi, and Pedersen support testing WTI own-return direction on a
  monthly clock.
- Huber defines a bounded-influence location family. The governed parent
  packet fixes the median/MAD scale, constants, weight equation, and fixed
  update count used here.
- No source defines this exact ten-year single-CFD conjunction, hard stop,
  spread cap, attempt ledger, or portfolio role.

## QM Interpretations

- The exact years `Y-1..Y-10`, all-ten requirement, uniform energy-label
  convention, and strict completed-month endpoints are pre-result CFD
  translation choices.
- The even median/MAD, `1.4826` normalizer, `1.5` tuning multiplier, frozen
  scale, 32 updates, and `1e-12` sign band are the bounded governed estimator
  contract; they are not fitted to this candidate's results.
- `XTIUSD.DWX` is a continuous spot-CFD carrier, not the source futures. Roll,
  financing, session labels, contract properties, and fills remain empirical
  risks.
- A direct WTI carrier is economically different from the stated book but is
  not presumed decorrelated or admitted.

## Non-Duplicate Decision

The fail-closed checker scanned 4,703 registry identities, 1,349 cards, and 45
Strategy Wiki nodes. It found no exact identity and surfaced only the
expected raw-mean same-calendar neighbor. Receipt:
`artifacts/qm5_wti_samecal_huber10_preallocation_dedup_20260829.json`, SHA-256
`63BD6DE74308678C8B23CCC5D9BF0C2F25EABEDB348734AC817C64887815DB4A`.

- `QM5_20099` averages prior same-calendar WTI returns without a robust scale
  or iterative influence weights.
- `QM5_20285` applies the Huber family to twelve adjacent recent broker-month
  returns, not ten disjoint exact-year returns for one recurring month.
- `QM5_41191` forms a centered signed absolute-rank sum, not a return location.
- `QM5_41199`, `QM5_41201`, and `QM5_41202` use exact-five-year trim,
  inclusive-pair pseudomedian, and Winsorized statistics.
- For
  `[.0188,-.0148,.0122,.0021,-.0084,-.0013,.0012,.0006,.0058,-.0160]`,
  this rule is approximately `-0.0003122567` and sells, while the raw mean is
  `+0.00002` and the centered signed-rank score is `+3`; both buy.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_WTI_EXACT_TEN_YEAR_SAME_CALENDAR_FIXED_SCALE_HUBER_LOCATION_SIGN_MONTHLY_RENEWAL`.

## Markets, Timeframe, And Cadence

- Host/traded symbol: exact `XTIUSD.DWX`, D1, slot 0.
- Intended magic: `412040000`.
- Decision: first executable tick of the first normalized D1 bar after a
  genuine broker-month transition.
- Formation: same target calendar month in every exact year `Y-1..Y-10`; all
  ten observations are mandatory.
- Hold: next broker-month boundary; 35 days is stale repair.
- Expected pre-result cadence: ten to twelve positions/year after warm-up;
  Q02 retires below five in any full post-warm-up year.

## Formula

For target calendar month `M` in historical year `H`:

```text
pre_close(H,M) = close of the immediately preceding D1 bar, normalized into
                 the immediately preceding calendar month
end_close(H,M) = close of the final normalized D1 bar in (H,M), confirmed by
                 a following D1 bar in the immediately following month
r(H,M)         = ln(end_close(H,M) / pre_close(H,M))

collect exactly r(Y-k,M), k=1..10
require all ten returns finite and all exact years present

s = sort(r); m = (s[4]+s[5])/2
a = sort(abs(r-m)); MAD = (a[4]+a[5])/2
delta = 1.5 * 1.4826 * MAD

mu = m
repeat exactly 32 times:
  w_i = 1 when abs(r_i-mu)<=delta, else delta/abs(r_i-mu)
  mu = sum(w_i*r_i)/sum(w_i)

BUY  iff mu > +1e-12
SELL iff mu < -1e-12
FLAT otherwise
```

Signal magnitude never changes risk. There is no estimator fallback,
missing-year substitution, early convergence exit, or current-month input.

## Rules

These rules are the complete baseline. No raw mean, raw median, trim,
Winsorization, pairwise pseudomedian, hit-rate, signed rank, contiguous-return
Huber state, fixed month list, recent-return confirmation, trend, inventory,
event, curve, volume, range, breakout, oscillator, volatility signal,
optimizer artifact, or external-data filter is authorized.

## 4. Entry Rules

1. Evaluate only on exact `XTIUSD.DWX`, D1, EA ID 41204, slot 0.
2. Process malformed and later-month owned exposure before every entry gate.
3. Accept only native same-day D1 labels or one uniform `+1` calendar-day
   energy offset. Require the normalized current D1 date to equal the broker
   date and apply the same offset to every historical endpoint.
4. Enter only on the first normalized D1 bar after a genuine broker-month
   transition. Mid-month initialization waits for the next boundary.
5. Persist broker `yyyymm` before history, signal, news, spread, quote, ATR,
   sizing, margin, or submission. Never retry after any downstream outcome.
6. Copy at most 3,000 completed D1 bars. For every exact year `Y-1..Y-10`,
   select the final normalized close in target month `M`, its immediately
   preceding D1 close, and a following D1 bar. Require adjacent calendar-month
   identities; reject the whole month if any exact year is invalid.
7. Compute all ten finite log returns, the exact even median and raw MAD,
   freeze `delta`, and execute exactly 32 finite Huber updates with the locked
   weight equation.
8. Positive beyond `1e-12` buys; negative below `-1e-12` sells; the inclusive
   tie band consumes the month.
9. Require valid completed-bar ATR(20,D1). Place one frozen hard stop at
   `3.5*ATR`; use no take-profit.
10. Require a valid quote and no genuinely positive spread above 1,500
    points. Modeled zero `.DWX` spread is valid.
11. Submit one market order once. No retry, pending order, scale-in, grid,
    martingale, pyramid, hedge, or companion leg exists.

## 5. Exit Rules

1. At the first observed D1 bar in a later broker `yyyymm`, close owned
   exposure before evaluating the new month.
2. Close after 35 elapsed calendar days as a final stale guard.
3. The frozen broker hard stop and framework kill switch remain authoritative.
4. Framework Friday close is disabled for this monthly identity.
5. No target, reversal, trailing stop, break-even move, partial exit, or
   discretionary close is authorized.

## 6. Filters (No-Trade Module)

- The framework kill switch and ownership checks remain authoritative.
- Both news axes and the legacy news mode are OFF; no external calendar is
  consulted.
- Wrong host symbol, wrong period, mid-month initialization, duplicate owned
  exposure, invalid history, nonpositive MAD/scale, invalid iteration, quote,
  spread, ATR, sizing, or margin consumes the already-persisted attempt.
- Framework Friday close is OFF so it cannot truncate the structural monthly
  hold.

## 7. Trade Management Rules

- Immediately flatten duplicate, wrong-symbol, wrong-magic, invalid-side,
  missing-stop, invalid-volume, or invalid-open-time owned exposure.
- Keep the entry hard stop frozen. Do not trail, break even, scale, pyramid,
  partially close, or change risk from the signal magnitude.
- Process malformed, later-month, and 35-day stale survivor repair before any
  new entry decision.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| Input | Locked value | Role |
|---|---:|---|
| `strategy_history_years` | 10 | exact prior years; all required |
| `strategy_required_observations` | 10 | exact return count |
| `strategy_mad_normalizer` | 1.4826 | frozen robust-scale constant |
| `strategy_huber_tuning` | 1.5 | fixed influence threshold multiplier |
| `strategy_huber_steps` | 32 | exact update count |
| `strategy_signal_epsilon` | 1e-12 | inclusive flat band |
| `strategy_history_bars_d1` | 3000 | bounded endpoint reconstruction |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 35 | stale repair only |
| `strategy_max_spread_points` | 1500 | WTI entry cost guard |
| `qm_friday_close_enabled` | false | preserve monthly hold |

No sweep, statistic fallback, calendar-month selection, endpoint, direction,
sample, scale, tuning, update count, stop, or lifecycle change is authorized.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Frozen hard stop: `3.5*ATR(20,D1)` from completed data.
- No take-profit and no signal-magnitude sizing.
- Invalid stop distance, tick value, tick size, volume step, minimum volume,
  computed lot, or price consumes the month.
- This card creates no live, demo, shadow, stress, or optimization preset.

The empirical source is a diversified futures result and the exact estimator
conjunction is untested. Continuous-CFD roll, financing, gaps, spread, and
contract translation can erase the premise. Only Q09 may assess realized book
correlation.

## Data Requirements

Native `XTIUSD.DWX` D1 OHLC/timestamps, broker clock, symbol quotes and
properties, positions, deal history, and terminal-global attempt state only.
No futures curve, inventory, volume, open interest, event feed, API, CSV,
optimizer artifact, trained output, or manual signal input.

## Framework Execution Overrides

- News temporal mode: `QM_NEWS_TEMPORAL_OFF`.
- News compliance profile: `QM_NEWS_COMPLIANCE_NONE`.
- Legacy news mode: OFF.
- Framework Friday close: disabled.
- Framework kill switch and broker hard stop: authoritative.
- Forced session flatten: none; monthly lifecycle remains authoritative.

## Exit Precedence

1. Framework kill switch and broker hard stop.
2. Malformed or unauthorized owned-exposure repair.
3. First D1 observation of a later broker month.
4. Thirty-five-calendar-day stale survivor repair.
5. No discretionary or signal-reversal exit inside the month.

## Runtime Data Dependencies

- Chart, signal, and traded symbol: exact `XTIUSD.DWX`, D1.
- Native completed D1 timestamps and closes, current broker date, quotes,
  spread, ATR risk helper, symbol metadata, positions, deals, and terminal
  global variables only.
- No additional symbol, custom runtime file, external calendar, curve,
  inventory, volume, open interest, API, optimizer output, or trained state.
- The tester account currency and fixed-dollar risk plumbing remain
  framework-owned and must pass the canonical setfile/build guards.

## Reputable-Source Gate Findings

| Gate | Status | Finding |
|---|---|---|
| R1 | PASS_WITH_COMPOSITE_ESTIMATOR_AND_CFD_TRANSLATION_RISK | Complete peer-reviewed same-calendar crude-oil evidence plus governed peer-reviewed WTI own-return and Huber-location lineage; exact conjunction untested. |
| R2 | PASS | Calendar, endpoints, sample, median/MAD, scale, weights, updates, side, attempt, risk, and lifecycle locked. |
| R3 | PASS_WITH_LONG_WARMUP_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK | Registered native XTI D1 and MT5 state supply every runtime field. |
| R4 | PASS | Deterministic native arithmetic and state only; no trained signal or external runtime feed. |

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact host/period, boundary, attempt, history, endpoints, median/MAD, fixed scale, 32 updates, side, spread, ATR | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers |
| malformed, later-month, and stale repair | Trade Management | `Strategy_ManageOpenPosition` plus lifecycle helper |
| monthly renewal and survivor repair | Trade Close | strategy lifecycle helper; Friday close disabled |
| kill switch, ownership, fixed-risk mode | Framework No-Trade | standard framework orchestration |
| news OFF | News hooks | `Strategy_NewsFilterHook` returns false; both modes OFF |

## Kill Criteria

Retire rather than tune on fewer than five completed positions per full
post-warm-up year; zero trades; nonpositive governed economics; wrong or
partial monthly endpoints; current-month leakage; any missing exact year;
wrong return count, median, MAD, scale, weights, update count, epsilon, or side;
retry; missing stop; wrong monthly lifecycle; nondeterminism; or registry/risk
mismatch.

No weak result may be rescued by reverting to another estimator, selecting
months, adding recent trend/return, inventory, event, curve, volume,
volatility, or price-action filters, changing the sample, or extending the
hold.

## Falsification And Requalification

Q02 is the first economic falsification and must retire the unchanged identity
on the density, economics, or implementation failures above. Any change to the
carrier, exact-year sample, endpoint convention, estimator, constants, update
count, side, retry ledger, risk, stop, spread cap, or lifecycle creates a new
strategy identity and requires new source/card approval plus a fresh pipeline.
Only downstream governed gates may assess robustness, news, costs, and realized
portfolio correlation; this card grants no shortcut or waiver.

## Validation Plan

Q01 must prove:

1. native and uniform `+1` labels select only the exact normalized month
   boundary and same-calendar returns use completed endpoints for every exact
   year `Y-1..Y-10`, including December/January wrapping;
2. any missing or malformed exact year consumes the month without
   substitution;
3. ten raw returns produce the exact even median and even raw MAD, the scale
   freezes, and exactly 32 updates use the locked weights;
4. the fixed disagreement vector produces the locked side and distinguishes
   raw mean, median, signed-rank, contiguous Huber, trim, pairwise central, and
   Winsorized neighbors;
5. no current-month OHLC, volume, or tick price enters the signal;
6. persistent `yyyymm` attempts prevent same-month retry after every
   downstream failure and restart;
7. fixed-risk sizing uses a valid frozen completed-bar ATR stop;
8. next-month close, malformed repair, stale guard, and disabled Friday close
   remain reachable; and
9. strict compile, card lint, build checks, setfile schema, magic resolver,
   and static Q01 validation pass.

Q02 alone may measure density and baseline economics. Q09 alone may establish
realized portfolio correlation.

## Version History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-29 | initial WTI ten-year same-calendar Huber card | G0 | APPROVED; build pending |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-29 | APPROVED; R1-R4 PASS | `decisions/2026-08-29_qm5_41204_wti_same_calendar_huber10_g0.md`; approved source packet |
| Q01 Build Validation | 2026-08-29 | NOT_BUILT | deterministic magic allocation and build pending |
| Q02 Baseline Screening | 2026-08-29 | NOT_ENQUEUED_Q01_PENDING | no work item before compile/review PASS |

## Safety Boundary

This card authorizes one branch-only non-live build, deterministic allocation,
strict Q01 validation, one `RISK_FIXED` D1 backtest setfile, and one paced Q02
enqueue only after prerequisites and a non-binding CPU check. It does not
authorize a manual backtest, live/demo/shadow/stress/optimization preset,
AutoTrading, `T_Live`, deploy or live manifest, portfolio-gate change,
portfolio admission, correlation waiver, terminal control, or queue deletion.
