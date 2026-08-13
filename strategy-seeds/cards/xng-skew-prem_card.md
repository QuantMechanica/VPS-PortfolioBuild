---
card_schema_version: 2
type: strategy
strategy_id: FERNANDEZ-SKEW-2018_XNG_TS_S04
variant_id: FERNANDEZ-SKEW-2018_XNG_TS_S04
source_id: FERNANDEZ-XNG-SKEW-2026
ea_id: QM5_20296
slug: xng-skew-prem
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20296_xng-skew-prem_card.md
execution_contract_status: DRAFT
created: 2026-08-13
created_by: Research+Development
last_updated: 2026-08-13
g0_status: APPROVED
source_author: "Adrian Fernandez-Perez; Bart Frijns; Ana-Maria Fuertes; Joelle Miffre"
source_authors: "Adrian Fernandez-Perez; Bart Frijns; Ana-Maria Fuertes; Joelle Miffre"
source_citation: "Fernandez-Perez, Frijns, Fuertes, and Miffre (2018), The Skewness of Commodity Futures Returns, Journal of Banking & Finance 86, 143-158, DOI 10.1016/j.jbankfin.2017.06.015."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Fernandez-Perez, A., Frijns, B., Fuertes, A.-M., and Miffre, J. (2018). The Skewness of Commodity Futures Returns. Journal of Banking & Finance 86, 143-158."
    location: "DOI https://doi.org/10.1016/j.jbankfin.2017.06.015; complete-paper evidence strategy-seeds/sources/FERNANDEZ-SKEW-2018/source.md; bounded extraction strategy-seeds/sources/FERNANDEZ-XNG-SKEW-2026/source.md"
    quality_tier: A
    role: primary_pearson_skewness_estimator_negative_premium_monthly_cadence_and_natural_gas_membership
strategy_mechanic: monthly-xng-prior-twelve-complete-month-pearson-skewness-zero-pivot-premium
sources:
  - "[[sources/FERNANDEZ-XNG-SKEW-2026]]"
concepts:
  - "[[concepts/commodity-skewness-premium]]"
  - "[[concepts/third-moment-risk-premium]]"
  - "[[concepts/natural-gas-structural-premium]]"
indicators:
  - "[[indicators/pearson-skewness]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, energy, natural-gas, realized-skewness, third-moment-premium, time-series-premium, monthly-rebalance, atr-hard-stop, time-stop, low-frequency, symmetric-long-short]
markets: [commodities, energy, natural_gas]
timeframes: [D1]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
single_symbol_only: true
logical_symbol: XNGUSD.DWX
symbol: XNGUSD.DWX
symbol_slot: 0
magic: 202960000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately eleven to twelve monthly XNG positions/year after the twelve-complete-month warm-up because only near-zero or invalid skewness states stay flat; Q02 must prove at least five completed positions/year or retire."
expected_trades_per_year_per_symbol: 11
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0_APPROVED
q01_status: NOT_STARTED
q02_status: NOT_STARTED
review_focus: "Falsify an outright monthly natural-gas third-moment premium, unlike QM5_12567's short-horizon long-only cumulative-RSI pullback and existing XNG trend, calendar, storage-event, breakout, relative-rank, and variance-ratio systems; Q09 alone may establish realized overlap with the XAU/SP500/NDX/XNG book."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [twelve_complete_broker_months, within_window_return_inclusion, pearson_population_skewness, absolute_zero_pivot, low_skew_premium_direction, monthly_attempt_state, risk_mode_dual, friday_close_disabled, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under decisions/2026-08-13_qm5_20296_xng_skew_prem_g0.md: R1 complete-read peer-reviewed commodity-skewness source with explicit natural-gas membership; R2 exact twelve-complete-month log returns, Pearson population moments, zero-pivot low-skew premium direction and lifecycle; R3 registered XNG D1 route; R4 deterministic native arithmetic without trained output or prohibited signal indicator. No exact identity; three same-source fuzzy neighbors were manually separated by carrier, rank/leg structure, and lifecycle."
---

# QM5_20296 XNG Pearson-Skewness Premium

## Hypothesis

Commodity investors can prefer lottery-like positive skewness and avoid
negative skewness, leaving high-skew contracts relatively overpriced and low-
skew contracts with a subsequent return premium. This card tests a single-XNG
time-series carrier of the source's negative skewness relation: buy when the
preceding twelve complete months of daily natural-gas returns have negative
Pearson skewness and sell when they have positive skewness.

This is a second natural-gas candidate, but its monthly third-moment state is
structurally different from the certified `QM5_12567` XNG cumulative-RSI
pullback. That difference does not prove decorrelation, profitability, or
portfolio suitability. Q02 owns density and baseline economics; unchanged
downstream gates, including Q09, own robustness and realized overlap.

## Source Traceability And Claim Boundary

The source of record is the governed bounded packet
`strategy-seeds/sources/FERNANDEZ-XNG-SKEW-2026/source.md`. Its complete-read
parent is Fernandez-Perez, Frijns, Fuertes, and Miffre (2018), a peer-reviewed
*Journal of Banking & Finance* paper defining twelve-month Pearson return
skewness, documenting a negative cross-sectional skewness premium, and
including natural gas in its commodity-futures universe.

The paper does not test an absolute zero-pivot natural-gas time-series rule.
The zero pivot, outright XNG direction, Darwinex continuous CFD, broker-
calendar reconstruction, population finite-sample convention, fixed-dollar
sizing, ATR hard stop, spread cap, attempt ledger, and lifecycle controls are
transparent QM hypotheses and mechanizations. No source return, alpha,
drawdown, XNG-only result, trade count, cost, CFD equivalence, or correlation
statistic is imported.

## Non-Duplicate Decision

The canonical checker scanned 4,361 EA-registry rows and 472 root cards. It
found no exact identity and three expected source-family fuzzy matches. Manual
review separated them:

- `QM5_13118_energy-skew-rank` ranks simultaneous XTI and XNG skewness values
  and maintains a two-leg opposite-side package. This card has one XNG state,
  one magic, no XTI input, no rank, and no orphan leg.
- `QM5_20233_xauxag-skew-rank` is a paired precious-metal rank with two
  magics; it neither carries outright natural gas nor maps one skewness value
  around zero.
- `QM5_20290_wti-skew-prem` preserves the source estimator and direction on
  WTI. This is a separately authorized XNG carrier with distinct history,
  contract economics, spread guard, magic, and standalone Q02 verdict; no WTI
  evidence transfers.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only oscillator
  pullback above a slow filter, not a monthly third-moment state.
- XNG return trend/reversal, seasonality, storage-event, breakout, carry,
  variance-ratio, and relative-spread EAs use different information objects.

The XNG carrier, twelve complete months, boundary-contained log returns,
Pearson population skewness, fixed zero pivot, negative-skew long/positive-
skew short map, and monthly consumed attempt are jointly load-bearing.
Verdict: `CLEAN_AUTHORIZED_XNG_CARRIER_AFTER_MANUAL_REVIEW`.

## Markets, Timeframe, And Cadence

- Exact host and traded symbol: `XNGUSD.DWX`.
- Timeframe: D1; magic slot 0; intended magic `202960000`.
- Decision clock: first processed D1 bar after a genuine broker-month change.
- Formation: adjacent D1 log returns wholly contained in the twelve complete
  broker months immediately preceding the decision month.
- Holding clock: next broker-month boundary, with a forty-calendar-day guard.
- Expected cadence: eleven to twelve positions per full post-warm-up year;
  retire below five observed positions/year.
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
external series, or prior pipeline result.

## 4. Entry Rules

1. Require exact EA ID `20296`, `XNGUSD.DWX` D1, magic slot 0, and every
   baseline input locked to its declared value.
2. Process lifecycle exits before entry-only gates and evaluate only at a
   genuine broker-month transition.
3. Persist the current month as consumed before history, signal, spread,
   quote, news, ATR, sizing, or order checks. No outcome may retry that month.
4. Reject owned exposure or any same-month entry deal for the magic.
5. Build the exact half-open formation interval from the twelve complete
   broker months preceding the decision month.
6. Load bounded completed-D1 history. Include a log return only when both
   adjacent timestamps lie inside the interval; reject current-month leakage,
   boundary-crossing returns, non-increasing timestamps, nonpositive closes,
   or nonfinite arithmetic.
7. Require all twelve expected month keys and 180 through 280 returns.
8. Compute population mean, second central moment, third central moment, and
   Pearson skewness. Require `m2 > 1e-12` and finite values.
9. Buy below `-1e-12`; sell above `+1e-12`; consume the tolerance band flat.
10. Require spread in `[0,2500]` points, executable quote, completed
    `ATR(20,D1)`, and valid contract metadata.
11. Open at most one market position with a frozen `3.5 * ATR(20,D1)` broker
    hard stop and no take-profit.

## 5. Exit Rules

1. Close the prior position on the first processed D1 bar of every new broker
   month before considering replacement, even if direction is unchanged.
2. Close after forty elapsed calendar days as a stale guard.
3. Close duplicate, wrong-symbol, invalid-type, or missing-stop exposure owned
   by this EA's magic.
4. Broker hard stops and the framework kill switch remain authoritative.
5. Friday close is disabled because the source-aligned hold spans weekends.
6. No intramonth flip, target, trail, break-even, partial close, scale-in,
   grid, martingale, pyramid, or discretionary exit is authorized.

## 6. Filters (No-Trade Module)

- Fail closed outside exact symbol, timeframe, EA ID, slot, fixed-risk,
  news/Friday contract, or locked strategy inputs.
- Reject a consumed attempt, owned exposure, same-month entry history,
  incomplete month coverage, wrong return count, invalid chronology,
  nonpositive close, nonfinite return/moment, variance at or below `1e-12`,
  zero-pivot tie, excessive spread, invalid quote, unavailable ATR, invalid
  stop, or invalid contract metadata.
- Both news axes and legacy news mode are locked OFF for Q02. Lifecycle exits
  run before entry-only gates.
- Runtime may not read a futures chain, options, weather, inventory, volume,
  open interest, file, API, analyst forecast, trained output, optimizer result,
  or portfolio state.

## 7. Trade Management Rules

- Maintain at most one XNG position and one consumed attempt per broker month.
- Preserve the original hard stop; close before monthly replacement or after
  forty calendar days.
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
| `strategy_lookback_months` | 12 | [12] | exact complete-month formation span |
| `strategy_history_bars_d1` | 500 | [500] | bounded completed-D1 history request |
| `strategy_min_return_observations` | 180 | [180] | inclusive minimum contained returns |
| `strategy_max_return_observations` | 280 | [280] | inclusive maximum contained returns |
| `strategy_variance_floor` | 1e-12 | [1e-12] | positive population-variance floor |
| `strategy_skew_tolerance` | 1e-12 | [1e-12] | symmetric zero-pivot tolerance |
| `strategy_atr_period_d1` | 20 | [20] | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen hard-stop multiple |
| `strategy_max_hold_days` | 40 | [40] | monthly stale guard |
| `strategy_max_spread_points` | 2500 | [2500] | natural-gas entry spread ceiling |

All values, moments, pivot, direction, entry clock, risk, stop, hold, and
no-retry policy are locked. Any change requires a new card and pipeline.

## Author Claims

Fernandez-Perez et al. define prior-twelve-month Pearson skewness, report a
negative cross-sectional relation, rebalance monthly, and include natural gas.
They do not claim that zero predicts XNG, that a continuous CFD reproduces
collateralized futures, or that this carrier diversifies the QM book.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Risk is high: cross-sectional-to-time-series translation,
persistent directional XNG states, weather and storage shocks, gaps, rolls,
financing, continuous-CFD basis, third-moment estimator noise, stop slippage,
and correlation with the incumbent XNG sleeve can dominate the premise.

## Kill Criteria

- Retire on zero trades or fewer than five completed positions per full post-
  warm-up year.
- Fail on wrong formation months, return inclusion, estimator denominator,
  moment convention, pivot, direction, repeated attempt, hold beyond forty
  days, missing hard stop, invalid risk mode, or nondeterminism.
- Retire on nonpositive governed economics or later portfolio-correlation
  rejection.
- Do not rescue failure by changing the formation, estimator, pivot,
  direction, stop, hold, spread, retry, or carrier.

## Strategy Allowability Check

| gate | verdict | reasoning |
|---|---|---|
| R1 | PASS | Tier-A peer-reviewed source with DOI, complete-read accepted-manuscript record, and explicit natural-gas membership. |
| R2 | PASS | Fixed twelve-month interval, contained-return rule, population Pearson estimator, zero pivot, direction, attempt, stop, rollover, and stale exit. |
| R3 | PASS | Registered `XNGUSD.DWX` D1 route plus native V5 execution state only. |
| R4 | PASS | Deterministic arithmetic only; no trained output, prohibited signal indicator, external feed, grid, or martingale. |

- [x] Dedup: no exact identity; three same-paper carrier/rank fuzzy neighbors
  manually resolved.

## Framework Alignment

- no_trade: exact XNG/D1/EA/slot, locked inputs, fixed risk/news/Friday
  contract, and cheap parameter guards.
- trade_entry: month-attempt persistence, formation bounds, contained log
  returns, Pearson skewness state, spread/quote/ATR/stop checks, and one fixed-
  risk order.
- trade_management: malformed-state repair, broker-month exit, and stale exit
  before entry-only gates.
- trade_close: framework close helper, broker hard stop, and kill switch.

## Safety Boundary

This card authorizes only research, deterministic allocation, build, strict
compile/Q01, and one non-live paced Q02 handoff. It does not authorize a manual
backtest; live, demo, shadow, optimization, or stress setfile; AutoTrading;
`T_Live`; deploy or T_Live manifest; portfolio-gate change; portfolio
admission; or a correlation waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-13 | initial XNG Pearson-skewness premium | G0 | APPROVED; build pending |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-13 | APPROVED; R1-R4 PASS | `decisions/2026-08-13_qm5_20296_xng_skew_prem_g0.md`; bounded source packet |
| Q01 Build Validation | - | NOT STARTED | - |
| Q02 Baseline Screening | - | NOT STARTED | - |
