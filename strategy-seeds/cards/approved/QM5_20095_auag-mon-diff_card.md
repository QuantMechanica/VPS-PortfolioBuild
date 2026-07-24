---
ea_id: QM5_20095
slug: auag-mon-diff
strategy_id: LUCEY-TULLY-DOW-2006_S01
source_id: LUCEY-TULLY-DOW-2006
status: APPROVED
g0_status: APPROVED
created: 2026-07-24
created_by: Research+Development
last_updated: 2026-07-24
source_citation: "Lucey, B. M. and Tully, E. (2006). Seasonality, risk and return in daily COMEX gold and silver data 1982-2002. Applied Financial Economics 16(4), 319-333."
source_citations:
  - type: academic_paper
    citation: "Lucey, B. M. and Tully, E. (2006). Seasonality, risk and return in daily COMEX gold and silver data 1982-2002. Applied Financial Economics 16(4), 319-333."
    location: "Table 2 Monday means; Tables 4-7; conclusion; DOI 10.1080/09603100500386586."
    quality_tier: B
    role: primary
strategy_type_flags: [calendar-seasonality, relative-value, market-neutral-basket, weekday, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals, relative_value]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
timeframes: [D1]
period: D1
expected_trades_per_year_per_symbol: 48
expected_trade_frequency: "About 45-52 completed two-leg Monday-session packages/year; Q02 must prove at least five/year."
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
hard_rules_at_risk: [HR-001, HR-002, HR-003, HR-004, HR-005, HR-006, HR-008, HR-010]
target_modules: [no_trade, trade_entry, trade_management, trade_close]
r1_track_record: TIER_B
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PASS
q02_status: PENDING
review_focus: "Falsify the weak XAU-minus-XAG Monday-session differential after two-leg costs and broker-boundary basis; Q09 alone measures realized book correlation."
g0_approval_reasoning: "OWNER commodity-sleeve mission: complete peer-reviewed source reviewed; deterministic one-session two-leg rule; registered XAU/XAG D1 routes; calendar and ATR only; exact-mechanic dedup CLEAN; weak source evidence explicitly bounded."
---

# XAU/XAG Monday-Session Relative-Value Basket

## Hypothesis

Lucey and Tully report that COMEX silver's unconditional Monday return was
more negative than gold's in both cash (`-0.0011` versus `-0.0007`) and
continuous futures (`-0.0007` versus `-0.0002`) over 1982-2002. A
one-session, equal-USD-notional XAU-long/XAG-short package tests whether that
cross-metal differential transfers to registered Darwinex CFDs while
suppressing common precious-metal beta.

The source does not test the two-leg differential, finds the futures Monday
coefficients insignificant, and calls mean seasonality weak and non-robust.
This is therefore a deliberately weak falsification hypothesis. It is not a
source performance claim, decorrelation claim, or portfolio-admission claim.

## Rules

- Run only on `XAUUSD.DWX` D1, magic slot 0; trade `XAGUSD.DWX` in slot 1.
- On a genuine synchronized broker-Monday D1 boundary, consume exactly one
  attempt before news, spread, ATR, price, or order gates.
- BUY XAU and SELL XAG at a `1.0:1.0` absolute USD-notional target, rounding
  lots down only.
- Allocate one combined `RISK_FIXED=1000` budget across frozen
  `3.0 * ATR(20)` hard stops; maximum notional mismatch is 20%.
- Close both legs at the first following XAU D1 boundary. A three-calendar-day
  stale guard, broken-package repair, hard stops, and Friday emergency close
  remain authoritative.
- No retry, scale-in, partial close, trailing, break-even, grid, martingale,
  pyramid, external runtime feed, adaptive fit, or parameter sweep.

## 4. Entry rules

1. Require exact EA ID, host symbol, D1 timeframe, host slot, locked inputs,
   synchronized XAU/XAG D1 bar timestamps, valid symbols, and no owned leg.
2. Require the genuine host bar timestamp to have broker
   `day_of_week == 1` (Sunday is zero).
3. Reject an opening delay greater than 15 minutes. Persist the Monday
   attempt before all fallible news, spread, ATR, quote, sizing, and order
   operations. Never shift or retry a blocked/rejected Monday.
4. Require XAU and XAG entry spreads no greater than 1500 and 500 points.
5. Calculate completed-D1 `ATR(20)` independently for each leg. Put the XAU
   long stop at `ask - 3.0*ATR` and the XAG short stop at
   `bid + 3.0*ATR`.
6. Solve downward-rounded lots jointly so aggregate stop risk is no greater
   than the one framework fixed-risk budget and the absolute USD-notional
   ratio is within 20% of `1.0`.
7. Open XAU first, then XAG. Keep the package only if exactly one correctly
   directed, stopped position exists per registered magic and the notional
   check passes. Otherwise close any opened leg immediately.

## 5. Exit rules

- At the first new host D1 bar strictly after package entry, close every owned
  leg before entry filters or news gating.
- If elapsed calendar time reaches three days, close every owned leg with a
  time-stop reason.
- Broker hard stops and the framework Friday close at hour 21 are emergency
  exits, not alpha exits.

## 6. Filters (no-trade module)

- Fail closed outside `XAUUSD.DWX` D1 slot 0 or if any locked input changes.
- Require both symbols tradable in the intended directions, positive point,
  contract, tick, and volume metadata, synchronized current D1 bars, valid
  completed ATR data, and acceptable spreads.
- Apply framework news controls to both symbols. The Q02 preset freezes both
  news axes off for deterministic historical testing.
- One persisted attempt plus position/deal-history scans prevents retry after
  restart, rejection, news block, partial-package repair, or same-day reload.

## 7. Trade management rules

- Every tick, validate exactly two owned positions: XAU BUY in slot 0 and XAG
  SELL in slot 1, each with a hard stop.
- Recalculate actual entry notional from volume, contract size, and open
  price. Close both legs if mismatch exceeds 20%.
- Treat zero, one, or more than two owned legs, wrong symbol/direction/magic,
  or a missing stop as a broken package and flatten it.
- No discretionary management or cross-package netting is authorized.

## Parameters to test

| parameter | default | authorized values |
|---|---:|---|
| `strategy_entry_dow` | 1 | [1] |
| `strategy_entry_grace_minutes` | 15 | [15] |
| `strategy_atr_period_d1` | 20 | [20] |
| `strategy_atr_sl_mult` | 3.0 | [3.0] |
| `strategy_notional_ratio` | 1.0 | [1.0] |
| `strategy_max_notional_error_pct` | 20.0 | [20.0] |
| `strategy_max_hold_days` | 3 | [3] |
| `strategy_xau_max_spread_pts` | 1500 | [1500] |
| `strategy_xag_max_spread_pts` | 500 | [500] |

All Q02 values and both directions are locked. A different weekday, holding
interval, direction, hedge, stop, or price filter requires a new source-backed
card.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and portfolio weight 1.
Both legs share that single budget; `RISK_FIXED` is not applied per leg.
Q02 must evaluate combined basket net PnL only. Equal notional reduces but
does not eliminate precious-metal, USD, volatility, gap, basis, or liquidity
risk.

The source sample ends in 2002. COMEX/CFD boundaries, roll construction,
weekend-gap omission, spread, slippage, financing, two-leg execution, lot
granularity, multiple testing, and post-publication decay are binding risks.

## Non-duplicate decision

The deterministic tool returned CLEAN for the final slug, strategy identity,
authors, and exact mechanic. Repository-wide searches found no Monday-D1-open
XAU-long/XAG-short package closed at Tuesday's D1 boundary.

`QM5_20019_xauxag-wkend` owns the preceding Friday 21:00 to first-Monday-H1
interval and is flat when this card becomes eligible. Ratio, threshold,
return-spread, breakout, and monthly cross-sectional baskets require price
state or formation windows. Distinct mechanics do not guarantee low realized
correlation; the unchanged Q09/portfolio gate decides that later.

## Kill criteria

- Retire below five completed packages/year or on zero trades.
- Fail on non-Monday entry, failure to flatten at the next D1 boundary,
  duplicate attempts, nondeterminism, wrong leg/magic, partial-basket
  persistence, aggregate-risk breach, or notional mismatch.
- Retire on governed PF/DD failure. Do not rescue failure by changing the
  weekday, direction, holding interval, hedge, stop, or filters.

## Strategy allowability check

- [x] R1: one fully reviewed peer-reviewed source lineage, tier B.
- [x] R2: deterministic entry, exit, sizing, stop, state, and repair rules.
- [x] R3: registered XAU/XAG D1 symbols and multi-symbol tester recipe.
- [x] R4: calendar arithmetic and ATR risk only; no banned or ML indicator.
- [x] Exact-mechanic deterministic dedup check is CLEAN.

## Framework alignment

- no_trade: exact host/timeframe/slot, locked constants, synchronized symbols.
- trade_entry: broker Monday, persisted attempt, atomic repairable basket.
- trade_management: composition/notional repair, next-D1 and stale closure.
- trade_close: combined ATR budget, deterministic pair close, Friday safety.

## Safety boundary

This approval covers the card, deterministic allocation, build, strict
compile, one `RISK_FIXED` backtest setfile, basket manifest, and one paced Q02
enqueue. It does not authorize a live setfile, AutoTrading, T_Live, a deploy
or T_Live manifest, portfolio admission, or a portfolio-gate change.

## Pipeline history

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-24 | new OWNER commodity-sleeve card | Q02 | PENDING |
