# QM5_41434_wti-hurr-wr2-clv-cont - Strategy Spec

**EA ID:** QM5_41434

**Slug:** `wti-hurr-wr2-clv-cont`

**Strategy ID:** `EIA-CRABEL-WTI-HURR-WR2-CLV-CONT-20260911_S01`

## 1. Strategy Logic

At the first tradable `XTIUSD.DWX` D1 bar of an August-October normalized broker week, aggregate
the two immediately completed consecutive weeks. Buy only when the newest full range is strictly
wider than the prior range and its final close is strictly above 0.75 of its own range. The body
sign is irrelevant. Every decision week is consumed before fallible gates.

Hold one long position at most through the decision week. Use a frozen `3.5*ATR(20,D1)` hard
stop, no target, next-week closure, and ten-day stale repair.

## 2. Parameters

| Parameter | Value |
|---|---:|
| `strategy_symbol` | setfile-bound `XTIUSD.DWX` |
| `strategy_label_offset_seconds` | 86400 |
| `strategy_entry_grace_minutes` | 180 |
| `strategy_history_bars` | 30 |
| `strategy_hurricane_month_1..3` | 8 / 9 / 10 |
| `strategy_required_weeks` | 2 |
| `strategy_min_week_bars` / `strategy_max_week_bars` | 3 / 5 |
| `strategy_clv_upper` | 0.75 |
| `strategy_atr_period_d1` / `strategy_atr_sl_mult` | 20 / 3.5 |
| `strategy_max_hold_days` | 10 |
| `strategy_max_spread_points` | 1500 |

Framework RNG, news, Friday-close, stress rejection, and portfolio weight are not equality-pinned.
Stress rejection is checked only for finiteness and inclusive `0..1`. The backtest risk contract
requires finite `RISK_FIXED>0` and `RISK_PERCENT=0`.

## 3. Symbol Universe

Exact configured `XTIUSD.DWX` D1 carrier, slot zero, magic `414340000`. No external market data is
read at runtime.

## 4. Timeframe

The host, signal, ATR, and execution timeframe is D1. Normalized labels group completed sessions
into Monday-anchored weeks. The decision must occur within 180 elapsed session minutes of the
first tradable D1 bar.

## 5. Expected Behaviour

Only August, September, and October Monday anchors qualify. Each of the two immediately completed
weeks must have three to five valid unique sessions. Range equality and `CLV==0.75` are flat.
Upper-quartile range expansion buys regardless of weekly body sign; there is no short branch.
Expected cadence is three to seven positions per full year, with retirement below three in any
full scored year.

## 6. Source Citation

The source packet is
`strategy-seeds/sources/EIA-CRABEL-WTI-HURR-WR2-CLV-CONT-20260911/source.md`. It combines official
EIA hurricane-risk context with governed Crabel range-state and Moskowitz-Ooi-Pedersen momentum
lineage. The exact rule, CFD efficacy, and book correlation are not source claims.

| Contract | Implementation |
|---|---|
| no-trade | exact identity/risk/locked strategy checks; framework inputs unpinned |
| entry | hurricane calendar, two completed weeks, strict range/CLV, long side, attempt, spread, ATR stop |
| management | long-only integrity, next-week closure, stale repair |
| close | framework reason mapping and broker hard stop |

## 7. Risk Model

Backtest: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`. Gaps, slippage, roll/basis,
financing, sparse seasonal sampling, and false continuation can exceed modeled risk. No live set,
deployment, portfolio admission, `T_Live`, or AutoTrading action is authorized.

## Revision History

| Version | Date | Change | Task |
|---|---|---|---|
| v1 | 2026-09-11 | Initial build from approved card | OWNER pacer mission |
