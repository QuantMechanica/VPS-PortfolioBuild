---
card_schema_version: 2
ea_id: QM5_20226
slug: wti-seas-dow
type: strategy
strategy_id: BURAKOV-GORSKA-WTI-SEASDOW-2026_S01
variant_id: BURAKOV-GORSKA-WTI-SEASDOW-2026_S01
source_id: BURAKOV-GORSKA-WTI-SEASDOW-2026
status: APPROVED
g0_status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20226_wti-seas-dow_card.md
execution_contract_status: DRAFT
created: 2026-08-05
created_by: Research+Development
last_updated: 2026-08-05
source_authors: "Dmitry Burakov; Max Freidin; Yuriy Solovyev; Anna Gorska; Malgorzata Krawiec"
strategy_mechanic: wti-fixed-physical-season-direction-agrees-with-signed-genuine-weekday-session
source_citation: "Burakov, Freidin, and Solovyev (2018), International Journal of Energy Economics and Policy 8(2), 121-126; Gorska and Krawiec (2015), Problems of World Agriculture 15(4), 62-70."
source_citations:
  - type: peer_reviewed_open_access_paper
    citation: "Burakov, D., Freidin, M., and Solovyev, Y. (2018). The Halloween Effect on Energy Markets: An Empirical Study. International Journal of Energy Economics and Policy 8(2), 121-126."
    location: "Methods alternative two and WTI Tables 2-3; complete governed review strategy-seeds/sources/BURAKOV-WTI-HALLOWEEN-2018/source.md"
    quality_tier: B
    role: physical_season_direction
  - type: peer_reviewed_paper
    citation: "Gorska, A. and Krawiec, M. (2015). Calendar Effects in the Market of Crude Oil. Problems of World Agriculture 15(4), 62-70."
    location: "WTI Tables 1-2; DOI 10.22630/PRS.2015.15.4.54; complete governed review strategy-seeds/sources/GORSKA-KRAWIEC-WTI-CAL-2015/source.md"
    quality_tier: B
    role: signed_weekday_direction
sources:
  - "[[sources/BURAKOV-GORSKA-WTI-SEASDOW-2026]]"
concepts:
  - "[[concepts/wti-seasonal-direction]]"
  - "[[concepts/crude-oil-day-of-week-seasonality]]"
  - "[[concepts/calendar-concordance]]"
indicators:
  - "[[indicators/broker-calendar]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, energy, calendar-seasonality, day-of-week, agreement-filter, symmetric-calendar-map, one-session-hold, atr-hard-stop, time-stop, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy, crude_oil]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
period: D1
timeframe: D1
timeframes: [D1]
expected_trade_frequency: "One eligible WTI weekday session per ordinary broker week: Friday long in November-May or Monday short in June-October; estimate 42-50 completed packages/year after holidays."
expected_trades_per_year_per_symbol: 46
expected_pf: 1.01
expected_dd_pct: 25.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PASS
q02_status: ENQUEUED
review_focus: "Falsify whether physical-season and weekday-direction concordance creates a one-session direct-WTI stream whose carrier and dual calendar clock differ from the certified XAU/SP500/NDX/XNG book; Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [risk_mode, friday_close_semantics, restart_safe_attempt, genuine_weekday_sequence, entry_grace, source_to_cfd_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under the OWNER 2026-08-05 commodity/energy sleeve mission: R1 fully reviewed peer-reviewed WTI physical-season and weekday sources; R2 locked season map, signed weekdays, genuine prior-day sequences, five-minute entry grace, consumed attempt, stop, spread, and one-session exit; R3 registered native XTIUSD.DWX D1 carrier; R4 deterministic native calendar/price arithmetic only. Deterministic dedup CLEAN; unconditional weekday, unconditional season, weekday/trend, seasonal/sign, and RSI relatives manually resolved."
---

# QM5_20226 WTI Physical-Season / Weekday Concordance

## Hypothesis

WTI's November-May versus June-October return asymmetry reflects recurring
heating demand, refinery transitions, inventory cycles, driving-season flows,
producer hedging, and weather risk. WTI also has a documented negative Monday
and positive Friday return contrast. Trading only when those two independent
calendar clocks agree may isolate a short-horizon crude-oil state: buy Friday
inside the positive physical season and sell Monday inside the negative
physical season.

The candidate adds direct crude-oil exposure with a one-session clock that is
economically different from the certified XAU/SP500/NDX/XNG book. This is a
falsifiable interaction, not a profitability, decorrelation, certification,
or portfolio-admission claim. Q02 must establish economics and execution;
the unchanged downstream portfolio gate alone may measure realized overlap.

## Source Traceability And Claim Boundary

The governed composite packet is
`strategy-seeds/sources/BURAKOV-GORSKA-WTI-SEASDOW-2026/source.md`.
Burakov, Freidin, and Solovyev supply positive November-May and negative
June-October WTI seasonal directions. Gorska and Krawiec supply negative
Monday and positive Friday WTI weekday directions.

Neither source tests the conjunction, a Darwinex continuous CFD, broker-open
execution, a fixed-risk ATR stop, or the QM portfolio. The source weekday
return includes the prior close-to-open component, while this executable rule
begins at the first observed D1 tick. No source return, significance, PF,
drawdown, cost, correlation, or neutrality statistic is imported.

## Non-Duplicate Decision

The deterministic checker scanned 4,283 registry rows and 399 canonical
cards. It found no exact identity and no fuzzy match above threshold. Manual
mechanic review fixes the boundaries:

- `QM5_20029_wti-monfri-daily` sells Mondays and buys Fridays year-round; it
  has no physical-season agreement gate.
- `QM5_12596_wti-mon-fade` and `QM5_12597_wti-fri-prem` isolate one
  unconditional weekday side.
- `QM5_20015_wti-halloween-winter`, `QM5_20046_wti-halloween-ls`, and
  `QM5_20093_wti-summer-short` carry monthly seasonal exposure rather than
  one weekday session.
- `QM5_20145_wti-fri-trend`, `QM5_20149_wti-montrend`,
  `QM5_20172_wti-fri-bear`, and `QM5_20173_wti-mon-bullfade` condition
  weekdays on a completed 252-D1 return sign, not the fixed physical season.
- `QM5_20222_wti-seas-sign` is a monthly twelve-return-sign concordance rule.
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback above a
  long-horizon filter.

The season map, weekday map, fixed directions, genuine prior-weekday
sequence, and one-session lifecycle are jointly load-bearing. Removing the
season gate recreates the year-round weekday parent; removing the weekday
gate recreates a monthly seasonal parent.

## Markets, Timeframe, And Cadence

- Carrier: `XTIUSD.DWX`, D1, slot 0, prospective magic `202260000`.
- Winter state: November-May; only a genuine Friday can BUY.
- Summer state: June-October; only a genuine Monday can SELL.
- Genuine Friday: the prior completed D1 bar is Thursday.
- Genuine Monday: the prior completed D1 bar is Friday.
- Entry observation: no later than five minutes after the eligible D1 bar
  opens.
- Ordinary exit: Friday framework close at broker hour 21 or the first
  following D1 boundary.
- Expected cadence: 42-50 completed packages/year after holidays; retire
  below five/year.

## Rules

At the first observed tick of each new `XTIUSD.DWX` D1 bar, derive the broker
month and weekday from the current bar open time:

- November-May plus Friday plus prior completed Thursday: BUY.
- June-October plus Monday plus prior completed Friday: SELL.
- Every other state, a holiday-broken sequence, or attachment later than five
  minutes after bar open: remain flat.

Persist the eligible day attempt before history, spread, quote, news, stop,
sizing, or order gates. A blocked or rejected attempt cannot retry that day.
There is no price-direction signal, unconditional fallback, alternate season,
weekday sweep, or post-result rescue path.

## 4. Entry Rules

1. Require exact EA ID `20226`, `XTIUSD.DWX` D1, magic slot 0, and every
   baseline input locked to the values below.
2. Process lifecycle exits before entry-only gates and evaluate only on a new
   D1 bar.
3. Classify November-May as the positive physical season and June-October as
   the negative physical season.
4. In November-May, continue only on Friday when the prior completed D1 bar
   is Thursday; direction is BUY.
5. In June-October, continue only on Monday when the prior completed D1 bar
   is Friday; direction is SELL.
6. Require the first observed tick no more than five minutes after the current
   D1 bar open.
7. Persist the exact broker day as consumed before spread, quote, ATR, news,
   sizing, or order gates. Reject an owned position or same-day owned entry
   deal.
8. Require spread in `[0,1500]` points, a valid executable quote, completed
   `ATR(20,D1)`, symbol metadata, fixed-risk mode, and news gates.
9. Open one market position with a frozen `3.0 * ATR(20,D1)` hard stop and no
   take-profit. Framework fixed-risk sizing remains authoritative.

## 5. Exit Rules

1. Close a Monday short on the first following D1 boundary before any new
   entry decision.
2. Close a Friday long through the framework Friday-close control at broker
   hour 21. If that close is missed, close on the first non-Friday D1 bar.
3. Close an unexpected wrong-side position immediately.
4. Close any position after three calendar days as a stale guard.
5. Broker hard stops and the framework kill switch remain authoritative.
6. No target, trail, break-even, partial close, scale-in, grid, martingale,
   pyramid, intraday retry, or discretionary exit is authorized.

## 6. Filters (No-Trade Module)

- Fail closed outside exact symbol, D1 timeframe, EA ID, slot, and frozen
  input contract.
- Reject the wrong season/weekday combination, holiday-broken prior weekday,
  late attachment, invalid day key, negative/excess spread, invalid
  ATR/quote/point metadata, consumed attempt, same-day deal, or open position.
- Q02 freezes both news axes and legacy news mode OFF. No external calendar,
  futures chain, inventory, volume, open interest, CSV, API, or forecast is
  read at runtime.
- Require framework Friday close enabled at broker hour 21.

## 7. Trade Management Rules

- One position maximum for magic `202260000` and one consumed attempt per
  eligible broker day.
- Lifecycle exits run before entry-only filters and remain retryable on later
  ticks if the first close attempt fails.
- Terminal-global attempt state survives restart; owned deal history provides
  a second no-reentry guard.
- Maintain the original server-side stop; never trail or move it.
- No hedge, averaging, scale-in, pyramiding, grid, martingale, partial close,
  adaptive fit, random path, or discretionary override exists.

## Parameters To Test

| parameter | baseline | authorized values | role |
|---|---:|---|---|
| `strategy_winter_first_month` | 11 | [11] | positive-season start |
| `strategy_winter_last_month` | 5 | [5] | positive-season end |
| `strategy_summer_first_month` | 6 | [6] | negative-season start |
| `strategy_summer_last_month` | 10 | [10] | negative-season end |
| `strategy_long_weekday` | 5 | [5] | broker Friday BUY event |
| `strategy_short_weekday` | 1 | [1] | broker Monday SELL event |
| `strategy_entry_grace_minutes` | 5 | [5] | maximum attachment delay |
| `strategy_atr_period` | 20 | [20] | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.0 | [3.0] | frozen hard-stop distance |
| `strategy_max_hold_days` | 3 | [3] | missed-exit stale guard |
| `strategy_max_spread_points` | 1500 | [1500] | WTI entry spread ceiling |

Changing a season, weekday, direction, sequence check, entry grace, hold,
stop, carrier, or retry policy requires a new card and full pipeline run.

## Risk

Q02 uses exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. `RISK_FIXED` is a stop-normalized loss budget, not fixed
notional exposure. No live-risk mode is authorized.

Primary risks are omitted overnight return, broker weekday/session mapping,
holiday sparsity, WTI gaps and rolls, futures-to-CFD basis, financing,
one-name exposure, source decay, seasonal interaction decay, and correlation
with XNG or directional assets. Retire below five completed packages/year or
on nonpositive governed economics, wrong season/weekday/direction, late or
duplicate entry, weekend hold, missing stop, risk mismatch, nondeterminism,
or later correlation rejection. No rescue or waiver is allowed.

## Strategy Allowability Check

- [x] R1 reputable: two named-author peer-reviewed papers with durable
  complete-read repository evidence and WTI-specific results.
- [x] R2 mechanical: fixed season map, weekdays, directions, genuine-day
  sequences, entry grace, consumed attempt, stop, spread, and exits.
- [x] R3 testable: registered native `XTIUSD.DWX` D1 carrier.
- [x] R4 compliant: deterministic native calendar/price arithmetic only; no
  trained model, banned indicator, external runtime feed, grid, martingale,
  scale-in, or pyramiding.
- [x] No exact or fuzzy identity; all nearest calendar, trend, and oscillator
  relatives are manually resolved with load-bearing distinctions.

## Framework Alignment

- no_trade: exact carrier/ID/slot, frozen inputs, season/weekday sequence,
  entry grace, spread, attempt, and framework safety gates.
- trade_entry: calendar-concordant BUY or SELL, restart-safe consumed attempt,
  fixed-risk sizing, and frozen ATR stop.
- trade_management: following-D1, wrong-side, and stale closes before entry
  gates.
- trade_close: framework Friday close, position-close helper, broker hard
  stop, and kill switch.

## Safety Boundary

This card authorizes one branch-only research build, strict compile, one
`RISK_FIXED` backtest setfile, and one paced Q02 enqueue. It does not authorize
a manual backtest; live, demo, or shadow setfiles; AutoTrading; `T_Live`; a
deploy or T_Live manifest; portfolio admission; a portfolio-gate change; or a
correlation waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-05 | initial WTI physical-season / weekday concordance candidate | G0 | APPROVED |
| v2 | 2026-08-05 | initial framework implementation | Q01 | PASS; strict compile and build checks |
| v3 | 2026-08-05 | paced baseline handoff | Q02 | ENQUEUED as priority work item `f92e06a9-833a-42a7-941c-c3dcfb14c7f3` |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-05 | APPROVED; R1-R4 PASS | `decisions/2026-08-05_qm5_20226_wti_seas_dow_g0.md` |
| Q01 Compile / Static Validation | 2026-08-05 | PASS | `framework/build/compile/20260805_160700/QM5_20226_wti-seas-dow.compile.log`; `D:/QM/reports/framework/21/build_check_20260805_160700.json` |
| Q02 Baseline Screening | 2026-08-05 | ENQUEUED | `docs/ops/evidence/2026-08-05_qm5_20226_wti_seas_dow_q02_enqueue.md` |
