# QM5_41436_wti-hurr-nr2-sign-cont - Strategy Spec

**EA ID:** QM5_41436

**Slug:** `wti-hurr-nr2-sign-cont`

**Strategy ID:** `EIA-CRABEL-MOP-WTI-HURR-NR2-SIGN-CONT-20260911_S01`

## 1. Strategy Logic

At the first tradable `XTIUSD.DWX` D1 bar of an August-October normalized broker week, aggregate
the two immediately completed consecutive weeks. Trade only when the newest full range is
strictly narrower than the prior range. Buy when the newest week's final close is above its
chronologically earliest open; sell when it is below. Zero body and range ties are flat. Every
decision week is consumed before fallible gates.

Hold one position at most through the decision week. Use a frozen `3.5*ATR(20,D1)` hard stop, no
target, next-week closure, and ten-day stale repair.

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
| `strategy_atr_period_d1` / `strategy_atr_sl_mult` | 20 / 3.5 |
| `strategy_max_hold_days` | 10 |
| `strategy_max_spread_points` | 1500 |

Framework RNG, news, Friday-close, stress rejection, and portfolio weight are not equality-pinned.
Stress rejection is checked only for finiteness and inclusive `0..1`. The backtest risk contract
requires finite `RISK_FIXED>0` and `RISK_PERCENT=0`.

## 3. Symbol Universe

Exact configured `XTIUSD.DWX` D1 carrier, slot zero, magic `414360000`. The symbol is an input;
no executable symbol literal is embedded in the EA and no external market data is read.

## 4. Timeframe

The host, signal, ATR, and execution timeframe is D1. Normalized labels group completed sessions
into Monday-anchored weeks. The decision must occur within 180 elapsed session minutes of the
first tradable D1 bar.

## 5. Expected Behaviour

Only August, September, and October Monday anchors qualify. Each of the two immediately completed
weeks must have three to five valid unique sessions. A strict contraction follows the newest
week's body sign on either side; range equality and zero body are flat. Expected cadence is four
to nine positions per full year, with retirement below four in any full scored year.

## 6. Source Citation

The source packet is
`strategy-seeds/sources/EIA-CRABEL-MOP-WTI-HURR-NR2-SIGN-CONT-20260911/source.md`. It combines
official EIA hurricane-risk context with governed Crabel range-state and peer-reviewed
Moskowitz-Ooi-Pedersen momentum lineage. The exact rule, CFD efficacy, and book correlation are
not source claims.

| Contract | Implementation |
|---|---|
| no-trade | exact identity/risk/locked strategy checks; framework inputs unpinned |
| entry | hurricane calendar, two completed weeks, strict contraction, body sign, attempt, spread, ATR stop |
| management | symmetric position integrity, next-week closure, stale repair |
| close | framework reason mapping and broker hard stop |

## 7. Risk Model

Backtest: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`. Gaps, slippage, roll/basis,
financing, sparse seasonal sampling, and false continuation can exceed modeled risk. No live set,
deployment, portfolio admission, `T_Live`, or AutoTrading action is authorized.

## Revision History

| Version | Date | Change | Task |
|---|---|---|---|
| v1 | 2026-09-11 | Initial build from approved card | OWNER pacer mission |
| v1-q01 | 2026-09-11 | Governed compile and strict build check PASS (`bc0fe3d3-68a6-45ee-83b4-1c3341ee4ee6`) | OWNER pacer mission |
| v1-q02 | 2026-09-11 | CPU-admitted fixed-risk Q02 enqueued (`ae5f4df7-e2ac-437d-b736-b99e5b635c6c`) | OWNER pacer mission |
| v1-q02-result | 2026-09-11 | Q02 returned `ZERO_TRADES`; valid harness/setup identity, zero strategy-state markers, recovery triage required; no retry or mechanics change | OWNER pacer mission |
