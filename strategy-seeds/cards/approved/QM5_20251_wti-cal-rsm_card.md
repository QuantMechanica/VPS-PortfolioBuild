---
card_schema_version: 2
type: strategy
strategy_id: KELOHARJU-PAPAILIAS-WTI-CALRSM-2026_S01
variant_id: KELOHARJU-PAPAILIAS-WTI-CALRSM-2026_S01
source_id: KELOHARJU-PAPAILIAS-WTI-CALRSM-2026
ea_id: QM5_20251
slug: wti-cal-rsm
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20251_wti-cal-rsm_card.md
execution_contract_status: DRAFT
created: 2026-08-06
created_by: Research+Development
last_updated: 2026-08-06
g0_status: APPROVED
source_authors: "Matti Keloharju; Juhani Linnainmaa; Peter Nyberg; Fotis Papailias; Jiadong Liu; Dimitrios D. Thomakos"
source_citation: "Keloharju, Linnainmaa, and Nyberg (2016), The Journal of Finance 71(4), 1557-1590, DOI 10.1111/jofi.12398; Papailias, Liu, and Thomakos (2021), Journal of Banking & Finance 124, 106063, DOI 10.1016/j.jbankfin.2021.106063."
source_citations:
  - type: peer_reviewed_paper
    citation: "Keloharju, M., Linnainmaa, J. T., and Nyberg, P. (2016). Return Seasonalities. The Journal of Finance 71(4), 1557-1590."
    location: "Commodity construction and crude-oil membership; DOI https://doi.org/10.1111/jofi.12398; complete governed review strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md"
    quality_tier: A
    role: same_calendar_seasonal_state
  - type: peer_reviewed_paper
    citation: "Papailias, F., Liu, J., and Thomakos, D. D. (2021). Return Signal Momentum. Journal of Banking & Finance 124, 106063."
    location: "Sections 2 and 4, Equations 7 and 10, WTI Tables G.1-G.3; DOI https://doi.org/10.1016/j.jbankfin.2021.106063; complete governed review strategy-seeds/sources/PAPAILIAS-RSM-2021/source.md"
    quality_tier: A
    role: twelve_month_return_sign_state
strategy_mechanic: monthly-wti-prior-ten-year-same-calendar-return-sign-agrees-with-twelve-completed-month-return-sign-probability
sources:
  - "[[sources/KELOHARJU-PAPAILIAS-WTI-CALRSM-2026]]"
  - "[[sources/KELOHARJU-RETSEAS-2016]]"
  - "[[sources/PAPAILIAS-RSM-2021]]"
concepts:
  - "[[concepts/same-calendar-month-seasonality]]"
  - "[[concepts/return-sign-momentum]]"
  - "[[concepts/seasonal-trend-concordance]]"
indicators:
  - "[[indicators/completed-month-log-return]]"
  - "[[indicators/arithmetic-mean]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, energy, crude-oil, adaptive-calendar-seasonality, return-sign-state, agreement-filter, monthly-rebalance, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
symbol_slot: 0
magic: 202510000
period: D1
timeframe: D1
expected_trade_frequency: "Estimated six to nine completed monthly WTI packages per full year after the five-year same-calendar warm-up; Q02 must prove or retire density."
expected_trades_per_year_per_symbol: 7
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PASS
q02_status: NOT_ENQUEUED
review_focus: "Falsify an adaptive WTI same-calendar/return-sign concordance stream whose crude-oil carrier and monthly state differ from the certified XAU/SP500/NDX/XNG book; only Q09 may establish realized portfolio decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [completed_month_reconstruction, same_calendar_estimator, binary_return_sign_state, fixed_threshold, concordance_gate, restart_attempt_state, risk_mode, friday_close_exception, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under decisions/2026-08-06_qm5_20251_wti_cal_rsm_g0.md: two tier-A peer-reviewed complete-read source lineages with explicit crude-oil/WTI membership; locked ten-year same-calendar estimator with five-sample floor, thirteen consecutive month ends, twelve binary return signs, fixed 0.40 threshold, strict agreement, persisted monthly attempt, ATR stop, rollover, and stale exit; registered XTIUSD.DWX D1 history; deterministic native arithmetic only. Dedup scanned 4,308 registry rows and 425 direct cards with no exact or fuzzy hit; manual mechanic review is clean. The conjunction is a QM hypothesis and no source efficacy or decorrelation transfers."
---

# QM5_20251 WTI Same-Calendar / Return-Sign Concordance

## Hypothesis

WTI demand, storage, hedging, refinery, transport, and capital-allocation
pressures can recur in the same calendar month, while the breadth of recent
monthly return signs measures whether price persistence agrees with that
recurring direction. A monthly WTI position admitted only when those two
independently defined states agree may isolate a slow crude-oil stream whose
economic driver differs from the incumbent XNG oscillator and the
index/precious-metal sleeves.

This is a falsifiable interaction, not a profitability, certification, or
decorrelation claim. Q02 must establish density and economics. Only the
unchanged Q09 portfolio gate may measure realized book overlap.

## Source Traceability And Claim Boundary

The governed composite packet is
`strategy-seeds/sources/KELOHARJU-PAPAILIAS-WTI-CALRSM-2026/source.md`.
Keloharju, Linnainmaa, and Nyberg supply the prior-year same-calendar return
estimator and explicit crude-oil membership. Papailias, Liu, and Thomakos
supply explicit WTI membership, twelve binary monthly return signs, fixed
`0.40` direction threshold, and monthly renewal.

Neither source tests the conjunction, a single Darwinex continuous WTI CFD,
fixed cash risk, ATR stops, broker-month reconstruction, or the QM portfolio.
No source PF, Sharpe, return, drawdown, trade count, correlation, or CFD-basis
statistic transfers. Papailias et al.'s adverse WTI drawdown evidence remains
an explicit kill risk.

## Non-Duplicate Decision

The deterministic checker scanned 4,308 pre-allocation registry rows and 425
direct cards and returned `CLEAN`, without an exact or fuzzy match. Manual
mechanic review fixes the nearest boundaries:

- `QM5_20099_wti-samecal` follows the historical same-calendar sign alone.
- `QM5_13150_wti-signmom` follows the twelve-return sign state alone.
- `QM5_20136_wti-caltrend` confirms same-calendar seasonality with a single
  completed 63-D1 cumulative return.
- `QM5_20205_wti-calmom1` confirms same-calendar seasonality with exactly the
  immediately completed broker-calendar-month return.
- `QM5_20222_wti-seas-sign` uses a fixed November-May / June-October direction
  rather than recomputing the upcoming month's history.
- `QM5_20244_wti-trend-sign` agrees one twelve-month cumulative return with
  the binary sign state and contains no recurring calendar sample.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon XNG oscillator pullback.

The prior-year matching-month sample, absolute seasonal sign, twelve binary
monthly signs, fixed threshold, strict agreement, disagreement-flat state,
and monthly attempt clock are jointly load-bearing. Removing either state
recreates a built parent.

## Markets, Timeframe, And Cadence

- Carrier: `XTIUSD.DWX`, D1, slot 0, magic `202510000`.
- Decision: first tradable D1 bar of every broker-calendar month.
- Seasonal formation: up to ten prior returns for the decision calendar
  month, minimum five valid observations.
- Return-sign formation: thirteen consecutive completed month ends defining
  twelve monthly returns.
- Hold: next month boundary, with a forty-calendar-day stale guard.
- Expected density: six to nine completed packages/year after warm-up; retire
  below five per full post-warm-up year.

## Rules

At the first tradable D1 bar of month `m`, reconstruct WTI's completed return
for calendar month `m` in each of the prior ten years:

`seasonal_return[y,m] = ln(month_end[y,m] / month_end[y,previous_month])`

Require at least five valid observations and take their arithmetic mean. A
strictly positive mean is a seasonal long state; a strictly negative mean is
a seasonal short state; an absolute mean at most `1e-12` is flat.

Separately reconstruct the latest thirteen consecutive completed
broker-month closes. Convert each of the twelve returns to `1` when
non-negative and `0` when negative:

`positive_probability = non_negative_return_count / 12`

The return-sign state is long at probability `>= 0.40` and short otherwise.
Buy only when both states are long; sell only when both states are short.
Disagreement, invalid history, or a flat seasonal state consumes the month
without exposure. Current-month prices never enter either state.

## 4. Entry Rules

1. Require exact EA ID `20251`, `XTIUSD.DWX` D1, slot 0, and every baseline
   input locked to the values below.
2. Process lifecycle exits before entry-only gates and evaluate only at a
   genuine broker-month transition.
3. Persist the monthly attempt before history, signal, agreement, spread,
   quote, news, stop, sizing, or order gates.
4. Reject an owned position or an owned entry deal already recorded in the
   current broker month.
5. Copy no more than 3,000 completed D1 bars. Build the up-to-ten-year
   same-calendar sample and require at least five valid returns.
6. Build exactly thirteen consecutive completed month ends for the return-sign
   state, ending with the just-completed month.
7. Classify the seasonal mean and the fixed-threshold sign probability. Stay
   flat unless both directions agree exactly.
8. Require spread in `[0,1500]` points, a valid quote, completed
   `ATR(20,D1)`, valid symbol metadata, fixed-risk mode, and framework entry
   clearance.
9. Open one market position with a frozen `3.5 * ATR(20,D1)` hard stop and no
   take-profit. Framework fixed-risk sizing remains authoritative.

## 5. Exit Rules

1. Close prior-month exposure on the first tradable D1 bar of a new broker
   month before considering replacement risk.
2. Close any position after forty calendar days as a stale guard.
3. Broker hard stops and the framework kill switch remain authoritative.
4. Friday close is disabled because the source hold spans weekends.
5. No intramonth signal flip, target, trail, break-even, partial close,
   scale-in, grid, martingale, pyramid, or discretionary exit is authorized.

## 6. Filters (No-Trade Module)

- Fail closed outside the exact symbol, D1 timeframe, EA ID, slot, and frozen
  input contract.
- Reject missing, nonconsecutive, nonpositive, current-month, or otherwise
  malformed endpoints; insufficient same-calendar history; invalid log
  arithmetic; disagreement; invalid ATR/quote/point metadata; negative or
  excessive spread; consumed attempt; same-month deal; or open position.
- Q02 freezes both news axes and legacy news mode OFF. Lifecycle exits are not
  delayed by entry-only news gates.
- Runtime may not read a futures curve, inventory release, volume, open
  interest, COT, file, API, analyst input, trained output, or portfolio result.

## 7. Trade Management Rules

- One position maximum for magic `202510000` and one consumed attempt per
  broker month.
- Close before renewal, after forty days, on the hard stop, or under framework
  safety action.
- Terminal-global attempt state survives restart; owned deal history supplies
  an independent no-reentry guard. A future-dated tester marker is deleted at
  initialization.
- No hedge, averaging, scale-in, pyramiding, grid, martingale, partial close,
  adaptive PnL fit, or random path exists.

## Parameters To Test

| parameter | baseline | authorized values | role |
|---|---:|---|---|
| `strategy_history_years` | 10 | [10] | bounded prior same-month sample |
| `strategy_min_history_years` | 5 | [5] | source minimum valid observations |
| `strategy_lookback_months` | 12 | [12] | return-sign window |
| `strategy_positive_threshold` | 0.40 | [0.40] | fixed return-sign direction threshold |
| `strategy_history_bars` | 3000 | [3000] | bounded D1 reconstruction |
| `strategy_atr_period` | 20 | [20] | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | [40] | monthly stale guard |
| `strategy_max_spread_points` | 1500 | [1500] | WTI entry spread ceiling |

Changing the estimator, sample floor, sign encoding, threshold, agreement
rule, hold, stop, carrier, spread cap, or retry state requires a new card and
full pipeline run. No baseline sweep or post-result rescue is authorized.

## Author Claims

The sources document recurring calendar-month return information and fixed
return-sign momentum in broad futures portfolios that include crude oil/WTI.
They do not claim that this concordance improves WTI entries, that a continuous
CFD reproduces futures, or that the candidate diversifies the QM book.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Risk is high: the source portfolios are broad while this
carrier is one CFD; same-calendar history is sparse; continuous-CFD rolls,
financing, gaps, stops, source decay, and agreement filtering can destroy
economics or density; and direct WTI may correlate with XNG or risk assets.

Retire on zero trades or fewer than five completed packages per full
post-warm-up year, nonpositive governed economics, wrong-month or
nonconsecutive endpoints, current-month leakage, wrong seasonal mean, wrong
binary state/threshold, disagreement entry, duplicate attempt, missing hard
stop, invalid risk mode, nondeterminism, or later correlation rejection. No
rescue or waiver is permitted.

## Strategy Allowability Check

- [x] R1 reputable: two named-author peer-reviewed papers with DOI, durable
  complete-read repository evidence, and explicit crude-oil/WTI membership.
- [x] R2 mechanical: fixed month endpoints, same-calendar estimator, binary
  signs, threshold, concordance, attempt, stop, spread, and exits.
- [x] R3 testable: registered native `XTIUSD.DWX` D1 carrier.
- [x] R4 compliant: deterministic native arithmetic only; no trained model,
  banned signal indicator, external runtime feed, grid, or martingale.
- [x] Exact/fuzzy dedup clean; all nearest semantic relatives manually
  resolved with load-bearing distinctions.

## Framework Alignment

- no_trade: exact carrier/ID/slot, frozen inputs, month state, attempt/deal
  guards, spread, and framework safety gates.
- trade_entry: same-calendar estimator, twelve-return sign probability,
  strict concordance, fixed-risk sizing, and frozen ATR stop.
- trade_management: close-before-renew and stale close before entry-only
  gates.
- trade_close: framework close helper, broker hard stop, and kill switch.

## Safety Boundary

This card authorizes only research, build, strict compile, and one non-live
paced Q02 handoff. It does not authorize a manual backtest; live, demo,
shadow, optimization, or stress setfile; AutoTrading; `T_Live`; deploy or
T_Live manifest; portfolio admission; portfolio-gate edit; or correlation
waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-06 | initial source-bounded WTI calendar/RSM card | G0 | APPROVED |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-06 | APPROVED | `decisions/2026-08-06_qm5_20251_wti_cal_rsm_g0.md` |
| Q01 Compile / Static Validation | 2026-08-06 | PASS | strict compile: 0 errors, 0 warnings; build check: 0 failures, 0 warnings |
| Q02 Baseline Screening | - | NOT_ENQUEUED | pending Q01 PASS |
