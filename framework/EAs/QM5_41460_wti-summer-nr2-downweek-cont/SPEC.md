# QM5_41460_wti-summer-nr2-downweek-cont - Strategy Spec

**EA ID:** QM5_41460  
**Strategy ID:** `BURAKOV-CRABEL-MOP-WTI-SUMMER-NR2-DOWNWEEK-CONT-20260912_S01`

## 1. Strategy Logic

At the first tradable `XTIUSD.DWX` D1 bar of each June-October normalized broker week,
aggregate the two immediately completed consecutive weeks. Require the newest full range to be
strictly narrower. Sell only when that week's final close is strictly below its chronological
first open. Range equality, expansion, or a zero/positive body is flat. Consume the decision
week before fallible gates and never retry.

Hold at most one short position through the decision week. Use one frozen `3.5*ATR(20,D1)` hard
stop, no target, next-week closure, and ten-calendar-day stale repair.

## 2. Parameters

| Parameter | Locked value |
|---|---:|
| `strategy_symbol` | setfile-bound `XTIUSD.DWX` |
| `strategy_label_offset_seconds` | 0 |
| `strategy_entry_grace_minutes` | 180 |
| `strategy_history_bars` | 30 |
| `strategy_summer_month_1..5` | 6 / 7 / 8 / 9 / 10 |
| `strategy_required_weeks` | 2 |
| `strategy_min_week_bars` / `strategy_max_week_bars` | 3 / 5 |
| `strategy_atr_period_d1` / `strategy_atr_sl_mult` | 20 / 3.5 |
| `strategy_max_hold_days` | 10 |
| `strategy_max_spread_points` | 1500 |

Only `strategy_*`, `qm_ea_id`, `qm_magic_slot_offset`, and the backtest risk mode are locked.
Framework RNG, news, Friday-close, and stress inputs remain configurable. Stress rejection is
checked only for finiteness and inclusive `0..1`. Backtest mode requires finite
`RISK_FIXED>0` and `RISK_PERCENT=0`.

## 3. Symbol Universe

Exact setfile-configured `XTIUSD.DWX` D1 carrier, slot zero, magic `414600000`. Runtime uses native
D1 OHLC/timestamps, quotes, spread, ATR, symbol properties, positions, deals, and persistent
attempt state only. No external weather, inventory, curve, volume, file, API, trained output,
optimizer, or portfolio state is read.

## 4. Timeframe

Base and decision timeframe are both D1. The EA evaluates only on the first tradable D1 bar of a
new normalized Monday-anchored broker week and uses only completed prior-week packages.

## 5. Expected Behaviour

Expected cadence is five to eight positions per full post-warm-up year. Q02 retires on zero
trades, fewer than five in a full scored year, nonpositive governed economics, or any clock,
signal, risk, stop, attempt, or lifecycle mismatch. Thresholds are not tuned after Q02. Q09 alone
may establish realized correlation.

## 6. Source Citation

The approved packet is
`strategy-seeds/sources/BURAKOV-CRABEL-MOP-WTI-SUMMER-NR2-DOWNWEEK-CONT-20260912/source.md`. It
combines peer-reviewed WTI June-October seasonality, peer-reviewed commodity-futures momentum, and
governed reputable Crabel range-state lineage. The exact weekly rule is an untested QM
translation.

The rule differs from `QM5_12567` (two-day XNG oscillator pullback), `QM5_20093`
(unconditional summer short), `QM5_41406`/`QM5_41407` (two-sign summer rules without a
range state), and the November-May NR2 family. Closest sibling `QM5_41459` requires strict range expansion, while this candidate requires strict
contraction, so their volatility predicates are mutually exclusive. `QM5_41457` shares range
contraction but requires a positive body and fades it; this candidate requires a negative body
and continues it.

## 7. Risk Model

Backtest mode is locked to `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. One frozen `3.5*ATR(20,D1)` broker hard stop bounds each package; there
is no target, scale-in, pyramid, grid, martingale, or second position for the magic.

## 8. Framework Alignment

| Contract | Implementation |
|---|---|
| no-trade | exact identity/risk/locked-strategy checks; framework inputs unpinned |
| entry | June-October calendar, two completed weeks, strict range contraction, negative-body short continuation, attempt, spread, ATR stop |
| management | short-only integrity, next-week closure, stale repair |
| close | framework reason mapping and broker hard stop |

## 9. Safety Boundary

Gaps, slippage, roll/basis, financing, summer instability, weekly-horizon translation, and overlap
with WTI candidates can dominate. No manual backtest, optimization, portfolio-gate edit,
admission, deploy/live manifest, `T_Live`, AutoTrading, terminal control, or live operation is
authorized.

## Revision History

| Version | Date | Change |
|---|---|---|
| v1 | 2026-09-12 | Initial governed build from approved card |
