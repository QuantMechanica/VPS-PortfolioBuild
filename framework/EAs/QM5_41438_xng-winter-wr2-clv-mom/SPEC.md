# QM5_41438_xng-winter-wr2-clv-mom - Strategy Spec

**EA ID:** QM5_41438  
**Strategy ID:** `EIA-CRABEL-MOP-XNG-WINTER-WR2-CLV-MOM-20260911_S01`

## 1. Strategy Logic

At the first tradable `XNGUSD.DWX` D1 bar of each November-March normalized broker week,
aggregate the two immediately completed consecutive weeks. Continue only when the newest full
range is strictly wider. Buy after a strict upper-quartile settlement (`CLV>0.75`) and sell after
a strict lower-quartile settlement (`CLV<0.25`); equality and the interior are flat, and weekly
body sign is irrelevant. Consume the decision week before fallible gates and never retry.

Hold at most one position through the decision week. Use one frozen `3.5*ATR(20,D1)` hard stop,
no target, next-week closure, and ten-calendar-day stale repair.

## 2. Parameters

| Parameter | Locked value |
|---|---:|
| `strategy_symbol` | setfile-bound `XNGUSD.DWX` |
| `strategy_label_offset_seconds` | 86400 |
| `strategy_entry_grace_minutes` | 180 |
| `strategy_history_bars` | 30 |
| `strategy_winter_month_1..5` | 11 / 12 / 1 / 2 / 3 |
| `strategy_required_weeks` | 2 |
| `strategy_min_week_bars` / `strategy_max_week_bars` | 3 / 5 |
| `strategy_clv_upper` / `strategy_clv_lower` | 0.75 / 0.25 |
| `strategy_atr_period_d1` / `strategy_atr_sl_mult` | 20 / 3.5 |
| `strategy_max_hold_days` | 10 |
| `strategy_max_spread_points` | 1500 |

Only `strategy_*`, `qm_ea_id`, `qm_magic_slot_offset`, and the backtest risk mode are locked.
Framework RNG, news, Friday-close, and stress inputs remain configurable. Stress rejection is
checked only for finiteness and inclusive `0..1`. Backtest mode requires finite
`RISK_FIXED>0` and `RISK_PERCENT=0`.

## 3. Symbol Universe And Timeframe

Exact configured `XNGUSD.DWX` D1 carrier, slot zero, magic `414380000`. Runtime uses only native
D1 OHLC/timestamps, quotes, spread, ATR, symbol properties, positions, deals, and persistent
attempt state. No external weather, storage, curve, volume, file, API, trained output, optimizer,
or portfolio state is read.

## 4. Expected Behaviour And Falsification

Expected cadence is five to twelve positions per full post-warm-up year. Q02 retires on zero
trades, fewer than five in a full scored year, nonpositive governed economics, or any clock,
signal, risk, stop, attempt, or lifecycle mismatch. Thresholds are not tuned after Q02. Q09 alone
may establish realized correlation.

## 5. Source And Non-Duplicate Boundary

The approved packet is
`strategy-seeds/sources/EIA-CRABEL-MOP-XNG-WINTER-WR2-CLV-MOM-20260911/source.md`. It combines
official EIA winter-demand context, complete-read peer-reviewed MOP momentum lineage, and governed
reputable Crabel range-state lineage. The exact rule is an untested QM translation.

The rule differs from `QM5_12567` (two-day long-only oscillator pullback), `QM5_41081`
(return-sign plus outer-fifth CLV without range expansion or winter conditioning), `QM5_41395`
(one-week winter return sign), `QM5_41402` (two agreeing winter return signs), `QM5_41063`
(all-year NR7 then current-week breakout), and `QM5_41434` (WTI hurricane, upper-only, long-only).

## 6. Framework Alignment

| Contract | Implementation |
|---|---|
| no-trade | exact identity/risk/locked-strategy checks; framework inputs unpinned |
| entry | winter calendar, two completed weeks, strict range/CLV, both sides, attempt, spread, ATR stop |
| management | symmetric integrity, next-week closure, stale repair |
| close | framework reason mapping and broker hard stop |

## 7. Risk And Safety Boundary

Backtest: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`. Gaps, slippage, roll/basis,
financing, winter instability, source translation, and overlap with the incumbent XNG sleeve can
dominate. No manual backtest, optimization, portfolio-gate edit, admission, deploy/live manifest,
`T_Live`, AutoTrading, terminal control, or live operation is authorized.

## Revision History

| Version | Date | Change |
|---|---|---|
| v1 | 2026-09-11 | Initial governed build from approved card |
| v2 | 2026-09-11 | Q01 `COMPILE_OK`; repaired empty generated `strategy_symbol`; guardrails passed; first Q02 enqueued as `17c3e39a-6818-4ef5-90ca-ecae9cb5af25` below CPU ceiling |
