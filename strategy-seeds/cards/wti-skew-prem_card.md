---
card_schema_version: 2
type: strategy
strategy_id: FERNANDEZ-SKEW-2018_XTI_TS_S03
variant_id: FERNANDEZ-SKEW-2018_XTI_TS_S03
source_id: FERNANDEZ-WTI-SKEW-2026
ea_id: QM5_20290
slug: wti-skew-prem
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20290_wti-skew-prem_card.md
execution_contract_status: DRAFT
created: 2026-08-12
created_by: Research+Development
last_updated: 2026-08-12
g0_status: APPROVED
source_author: "Adrian Fernandez-Perez; Bart Frijns; Ana-Maria Fuertes; Joelle Miffre"
source_authors: "Adrian Fernandez-Perez; Bart Frijns; Ana-Maria Fuertes; Joelle Miffre"
source_citation: "Fernandez-Perez, Frijns, Fuertes, and Miffre (2018), The Skewness of Commodity Futures Returns, Journal of Banking & Finance 86, 143-158, DOI 10.1016/j.jbankfin.2017.06.015."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Fernandez-Perez, A., Frijns, B., Fuertes, A.-M., and Miffre, J. (2018). The Skewness of Commodity Futures Returns. Journal of Banking & Finance 86, 143-158."
    location: "DOI https://doi.org/10.1016/j.jbankfin.2017.06.015; complete-paper evidence strategy-seeds/sources/FERNANDEZ-SKEW-2018/source.md; bounded extraction strategy-seeds/sources/FERNANDEZ-WTI-SKEW-2026/source.md"
    quality_tier: A
    role: primary_pearson_skewness_estimator_negative_premium_and_monthly_cadence
strategy_mechanic: monthly-wti-prior-twelve-complete-month-pearson-skewness-zero-pivot-premium
sources:
  - "[[sources/FERNANDEZ-WTI-SKEW-2026]]"
concepts:
  - "[[concepts/commodity-skewness-premium]]"
  - "[[concepts/third-moment-risk-premium]]"
  - "[[concepts/crude-oil-structural-premium]]"
indicators:
  - "[[indicators/pearson-skewness]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, energy, realized-skewness, third-moment-premium, time-series-premium, monthly-rebalance, atr-hard-stop, time-stop, low-frequency, symmetric-long-short]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
symbol_slot: 0
magic: 202900000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately eleven to twelve monthly WTI positions/year after the twelve-complete-month warm-up because only near-zero or invalid skewness states stay flat; Q02 must prove at least five completed positions/year or retire."
expected_trades_per_year_per_symbol: 11
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
q01_status: PENDING_BUILD
q02_status: NOT_ENQUEUED
review_focus: "Falsify an outright WTI monthly third-moment premium driven by absolute twelve-month Pearson skewness, unlike existing XTI/XNG and XAU/XAG relative-rank baskets, WTI signed semivariance, return trend/reversal, calendar, event, and XNG RSI neighbors; Q09 alone may establish realized book decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [twelve_complete_broker_months, within_window_return_inclusion, pearson_population_skewness, absolute_zero_pivot, low_skew_premium_direction, monthly_attempt_state, risk_mode_dual, friday_close_disabled, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under decisions/2026-08-12_qm5_20290_wti_skew_prem_g0.md: R1 complete-read peer-reviewed commodity-skewness source with explicit WTI membership; R2 exact twelve-complete-month log returns, Pearson population moments, zero-pivot low-skew premium direction and lifecycle; R3 registered WTI D1 route; R4 deterministic native arithmetic with no trained output or prohibited signal indicator; no exact identity and two source-family fuzzy neighbors manually resolved."
---

# QM5_20290 WTI Skewness Premium

## Hypothesis

Commodity investors can prefer lottery-like positive skewness and avoid
negative skewness, leaving high-skew contracts relatively overpriced and low-
skew contracts with a subsequent return premium. This card tests a single-WTI
time-series carrier of the source's negative skewness relation: buy when the
preceding twelve complete months of daily WTI returns have negative Pearson
skewness and sell when they have positive skewness.

The direct crude-oil carrier and monthly third-moment clock differ from the
certified XAU, SP500, NDX, and XNG book. That does not prove decorrelation,
profitability, or portfolio suitability. Q02 owns density and baseline
economics; unchanged downstream gates, including Q09, own robustness and
realized overlap.

## Source Traceability And Claim Boundary

The single trading source of record is the governed bounded packet
`strategy-seeds/sources/FERNANDEZ-WTI-SKEW-2026/source.md`. Its complete-read
parent is Fernandez-Perez, Frijns, Fuertes, and Miffre (2018), a peer-reviewed
*Journal of Banking & Finance* paper defining twelve-month Pearson return
skewness, documenting a negative cross-sectional skewness premium, and
including crude oil in its commodity-futures universe.

The paper does not test an absolute zero-pivot time-series rule. The zero
pivot, outright WTI direction, Darwinex continuous CFD, broker-calendar
reconstruction, population finite-sample convention, fixed-dollar sizing,
ATR hard stop, spread cap, attempt ledger, and lifecycle controls are
transparent QM hypotheses and mechanizations. No source return, alpha,
drawdown, WTI-specific result, trade count, cost, CFD equivalence, or
correlation statistic is imported.

## Non-Duplicate Decision

The canonical checker scanned 4,355 EA-registry rows and 467 root cards. It
found no exact identity and two expected source-family fuzzy matches. Manual
family review separated the closest neighbors:

- `QM5_13118_energy-skew-rank` ranks simultaneous XTI and XNG skewness values
  and maintains a two-leg package. This card has one WTI state, no rank,
  second leg, or orphan, and trades absolute skewness around zero.
- `QM5_20233_xauxag-skew-rank` is a paired precious-metal carrier with two
  magics and equal risk halves; it neither carries outright WTI nor maps one
  skewness value around zero.
- `QM5_20289_wti-rsj-rev` uses one complete month and normalized upside-minus-
  downside semivariance. This card uses twelve complete months and the
  centered third standardized moment.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only oscillator
  pullback above a slow filter, not a monthly third-moment state.
- WTI cumulative, sign, regression, rank, robust-location, path-efficiency,
  variance-ratio, ordinary reversal, calendar, event, and breakout EAs use
  different information objects, directions, or clocks.

The twelve complete months, boundary-contained log returns, Pearson
population skewness, fixed zero pivot, negative-skew long/positive-skew short
time-series map, outright WTI carrier, and monthly lifecycle are jointly load-
bearing. Verdict:
`CLEAN_AFTER_MANUAL_CROSS_SECTIONAL_TO_TIME_SERIES_REVIEW`.

## Markets, Timeframe, And Cadence

- Exact host and traded symbol: `XTIUSD.DWX`.
- Timeframe: D1; magic slot 0; intended magic `202900000`.
- Decision clock: first processed D1 bar after a genuine broker-month change.
- Formation: adjacent D1 log returns wholly contained in the twelve complete
  broker months immediately preceding the decision month.
- Holding clock: next broker-month boundary, with a forty-calendar-day guard.
- Expected cadence: eleven to twelve positions per full post-warm-up year;
  retire below five observed positions.
- Runtime data: native MT5 D1 time/close, ATR, spread, quote, position, deal,
  broker calendar, and contract metadata only.

## Formula

For adjacent positive finite D1 closes whose two timestamps both lie in the
twelve-month formation interval:

```text
r[d] = ln(close[d] / close[d-1])
mu   = mean(r[d])
m2   = mean((r[d] - mu)^2)
m3   = mean((r[d] - mu)^3)
skew = m3 / (m2^(3/2))
```

Require every expected month key, 180 through 280 returns, finite arithmetic,
and `m2 > 1e-12`. BUY when `skew < -1e-12`; SELL when
`skew > +1e-12`; near-zero or invalid state remains flat. The score's
magnitude never scales risk.

## Rules

These are the complete authorized baseline. There is no signal-parameter
sweep and no fallback to a cross-sectional rank, raw return, cumulative
return, semivariance, moving average, oscillator, calendar direction,
external series, or previous pipeline result.

## 4. Entry Rules

1. Require exact EA ID `20290`, `XTIUSD.DWX` D1, magic slot 0, and every
   baseline input locked to its declared value.
2. Process lifecycle exits before entry-only gates and evaluate only at a
   genuine broker-month transition.
3. Persist the current month as consumed before history, signal, spread,
   quote, news, stop, sizing, or order checks. No outcome may retry that month.
4. Reject owned exposure or any same-month entry deal for the magic.
5. Derive the exact half-open formation interval covering the twelve complete
   broker months before the decision month. Load bounded completed-D1 history
   in strictly increasing timestamp order and include a return only when both
   adjacent bars fall inside that interval.
6. Reject current-month leakage, a boundary-crossing return, duplicate or
   non-increasing timestamps, a missing expected month key, a nonpositive
   close, or count outside 180-280.
7. Compute the arithmetic mean, population second central moment, and
   population third central moment over exactly the included log returns.
   Require finite moments and `m2 > 1e-12`; calculate raw Pearson skewness
   without bias correction or annualization.
8. Buy when skewness is below `-1e-12` and sell when above `+1e-12`;
   near-zero stays flat. Do not rank, winsorize, benchmark-demean, threshold-
   fit, reverse the low-skew direction, or size risk from magnitude.
9. Require spread in `[0,1500]` points, executable quote, completed
   `ATR(20,D1)`, valid point/digit/volume metadata, and fixed-risk sizing.
10. Open at most one market position with a frozen `3.5 * ATR(20,D1)` broker
    hard stop and no take-profit.

## 5. Exit Rules

1. Close the prior position on the first processed D1 bar of every new broker
   month before considering replacement risk, even if direction is unchanged.
2. Close after forty elapsed calendar days as a stale guard.
3. Close duplicate, wrong-symbol, invalid-type, or missing-stop exposure owned
   by this EA's magic.
4. Broker hard stops and the framework kill switch remain authoritative.
5. Friday close is disabled because the source-aligned hold spans weekends.
6. No intramonth signal flip, target, trail, break-even, partial close,
   scale-in, grid, martingale, pyramid, or discretionary exit is authorized.

## 6. Filters (No-Trade Module)

- Fail closed outside exact symbol, timeframe, EA ID, slot, fixed risk,
  news/Friday contract, or locked strategy inputs.
- Reject a consumed attempt, owned exposure, same-month entry history,
  malformed formation bounds, missing month coverage, current-month leakage,
  boundary-crossing return, observation count outside 180-280, nonpositive
  close, nonfinite return or moment, variance at or below `1e-12`, near-zero
  signal, excessive spread, invalid quote, unavailable ATR, invalid stop, or
  invalid metadata.
- Both news axes and legacy news mode are locked OFF for Q02. Lifecycle exits
  run before entry-only gates.
- Runtime may not read a futures chain, inventory release, volume, open
  interest, file, API, analyst forecast, trained output, optimizer result, or
  portfolio state.

## 7. Trade Management Rules

- Maintain at most one WTI position and one consumed attempt per broker month.
- Preserve the original hard stop; close before monthly renewal or after forty
  calendar days.
- Restart recovery combines a terminal-persistent month marker with owned
  position and deal history; tester initialization clears a future marker so
  historical runs remain deterministic.
- Lifecycle repair closes duplicate, wrong-symbol, invalid-type, or missing-
  stop exposure before any new entry logic.
- No randomness, adaptive fitting, external state, partial close, scale-in,
  grid, martingale, or pyramiding is allowed.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_lookback_months` | 12 | [12] | exact complete broker-month formation |
| `strategy_history_bars_d1` | 500 | [500] | bounded D1 reconstruction |
| `strategy_min_return_observations` | 180 | [180] | minimum contained log returns |
| `strategy_max_return_observations` | 280 | [280] | maximum contained log returns |
| `strategy_variance_floor` | 1e-12 | [1e-12] | positive population-variance floor |
| `strategy_skew_tolerance` | 1e-12 | [1e-12] | symmetric zero-pivot tolerance |
| `strategy_atr_period_d1` | 20 | [20] | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen broker hard-stop distance |
| `strategy_max_hold_days` | 40 | [40] | monthly stale guard |
| `strategy_max_spread_points` | 1500 | [1500] | WTI entry spread ceiling |

All values and the formation selection, return inclusion, log-return formula,
population moments, zero pivot, low-skew direction, entry clock, risk, stop,
hold, and no-retry policy are locked. Any change requires a new card and
pipeline.

## Author Claims

Fernandez-Perez, Frijns, Fuertes, and Miffre define twelve-month Pearson
skewness, document a negative skewness premium across commodity-futures
portfolios, and include crude oil in their universe. They do not claim that
absolute zero predicts WTI, that a continuous CFD reproduces collateralized
futures, or that this candidate diversifies the QM book.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Risk is high: WTI gaps, CFD roll/basis and financing,
single-name concentration, persistent positive or negative skew regimes,
third-moment estimator noise, hard-stop slippage, session-boundary
sensitivity, and correlation with XNG or risk assets can dominate the
premise. Same-source paired carriers do not supply performance evidence for
this time-series translation.

## Kill Criteria

- Retire on zero trades or fewer than five completed positions per full post-
  warm-up year.
- Fail on wrong formation bounds, boundary-crossing or current-month returns,
  missing month coverage, wrong return orientation, count outside 180-280,
  nonpositive variance, non-Pearson estimator, alternate pivot, positive-skew
  long direction, repeated attempt, hold beyond forty days, missing hard stop,
  invalid risk mode, or nondeterminism.
- Retire on nonpositive governed economics or later portfolio-correlation
  rejection.
- Do not rescue failure by changing formation, pivot, estimator, direction,
  entry clock, stop, hold, spread, retry, or carrier.

## Strategy Allowability Check

| gate | verdict | reasoning |
|---|---|---|
| R1 | PASS | One Tier-A peer-reviewed trading source with DOI, complete-paper evidence, durable packet hash, and explicit WTI membership. |
| R2 | PASS | Fixed twelve months, contained returns, Pearson population moments, pivot, direction, attempt, hard stop, rollover, and stale exit. |
| R3 | PASS | Registered `XTIUSD.DWX` D1 plus native V5 execution state only. |
| R4 | PASS | Deterministic arithmetic only; no trained model, prohibited signal indicator, external feed, grid, or martingale. |

- [x] Dedup: no exact identity; cross-sectional skewness baskets and all WTI
  neighbors were manually resolved.

## Framework Alignment

- no_trade: exact WTI/D1/EA/slot, locked inputs, fixed risk/news/Friday
  contract, and cheap parameter guards.
- trade_entry: month-attempt persistence, twelve-month D1 reconstruction,
  contained returns, Pearson skewness state, spread/quote/ATR/stop checks, and
  one fixed-risk order.
- trade_management: malformed-state repair, broker-month exit, and stale exit
  before entry-only gates.
- trade_close: framework close helper, broker hard stop, and kill switch.

## Safety Boundary

This card authorizes only research, deterministic allocation, build, strict
compile/Q01, and one non-live paced Q02 handoff. It does not authorize a
manual backtest; live, demo, shadow, optimization, or stress setfile;
AutoTrading; `T_Live`; deploy or T_Live manifest; portfolio admission;
portfolio-gate edit; or correlation waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-12 | initial source-bounded WTI absolute-skewness premium card | G0 | APPROVED; build pending |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-08-12 | APPROVED | `decisions/2026-08-12_qm5_20290_wti_skew_prem_g0.md` |
| Q01 Build Validation | - | PENDING | - |
| Q02 Baseline Screening | - | NOT ENQUEUED | - |
