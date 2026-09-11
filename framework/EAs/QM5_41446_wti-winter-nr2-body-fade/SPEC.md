# QM5_41446_wti-winter-nr2-body-fade - Strategy Spec

**EA ID:** QM5_41446  
**Strategy ID:** `BURAKOV-CRABEL-YANG-WTI-WINTER-NR2-BODY-FADE-20260911_S01`

## 1. Strategy Logic

At the first tradable `XTIUSD.DWX` D1 bar of each November-May normalized broker week,
aggregate the two immediately completed consecutive weeks. Require the newest full range to be
strictly narrower. Sell when that week's final close is strictly above its chronological first open;
buy when it is strictly below. Range equality, expansion, or body equality is flat. Range
containment is irrelevant. Consume the
decision week before fallible gates and never retry.

Hold at most one long or short position through the decision week. Use one frozen
`3.5*ATR(20,D1)` hard stop, no target, next-week closure, and ten-calendar-day stale repair.

## 2. Parameters

| Parameter | Locked value |
|---|---:|
| `strategy_symbol` | setfile-bound `XTIUSD.DWX` |
| `strategy_label_offset_seconds` | 86400 |
| `strategy_entry_grace_minutes` | 180 |
| `strategy_history_bars` | 30 |
| `strategy_winter_month_1..7` | 11 / 12 / 1 / 2 / 3 / 4 / 5 |
| `strategy_required_weeks` | 2 |
| `strategy_min_week_bars` / `strategy_max_week_bars` | 3 / 5 |
| `strategy_atr_period_d1` / `strategy_atr_sl_mult` | 20 / 3.5 |
| `strategy_max_hold_days` | 10 |
| `strategy_max_spread_points` | 1500 |

Only `strategy_*`, `qm_ea_id`, `qm_magic_slot_offset`, and the backtest risk mode are locked.
Framework RNG, news, Friday-close, and stress inputs remain configurable. Stress rejection is
checked only for finiteness and inclusive `0..1`. Backtest mode requires finite
`RISK_FIXED>0` and `RISK_PERCENT=0`.

## 3. Symbol Universe And Timeframe

Exact setfile-configured `XTIUSD.DWX` D1 carrier, slot zero, magic `414460000`. Runtime uses native
D1 OHLC/timestamps, quotes, spread, ATR, symbol properties, positions, deals, and persistent
attempt state only. No external weather, inventory, curve, volume, file, API, trained output,
optimizer, or portfolio state is read.

## 4. Expected Behaviour And Falsification

Expected cadence is twelve to twenty-two positions per full post-warm-up year. Q02 retires on
zero trades, fewer than five in a full scored year, nonpositive governed economics, or any clock,
signal, risk, stop, attempt, or lifecycle mismatch. Thresholds are not tuned after Q02. Q09 alone
may establish realized correlation.

## 5. Source And Non-Duplicate Boundary

The approved packet is
`strategy-seeds/sources/BURAKOV-CRABEL-YANG-WTI-WINTER-NR2-BODY-FADE-20260911/source.md`. It
combines peer-reviewed WTI November-May seasonality, academic commodity-futures reversal,
and governed reputable Crabel range-state lineage. The exact weekly rule is an untested QM translation.

The rule differs from `QM5_12567` (two-day XNG oscillator pullback), `QM5_41444` (opposite
range-expansion body fade), `QM5_41445` (the same contraction/body predicate with continuation),
and `QM5_41441` (contracting-week later-close breakout).

## 6. Framework Alignment

| Contract | Implementation |
|---|---|
| no-trade | exact identity/risk/locked-strategy checks; framework inputs unpinned |
| entry | November-May calendar, two completed weeks, strict range contraction, own-body reversion, attempt, spread, ATR stop |
| management | long/short integrity, next-week closure, stale repair |
| close | framework reason mapping and broker hard stop |

## 7. Risk And Safety Boundary

Backtest: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`. Gaps, slippage, roll/basis,
financing, winter instability, weekly-horizon translation, and overlap with WTI candidates can
dominate. No manual backtest, optimization, portfolio-gate edit, admission, deploy/live manifest,
`T_Live`, AutoTrading, terminal control, or live operation is authorized.

## Revision History

| Version | Date | Change |
|---|---|---|
| v1 | 2026-09-11 | Initial governed build from approved card |
| v1-q01 | 2026-09-11 | T3 governed compile and strict build check PASS; Q02 pending deterministic intake |
