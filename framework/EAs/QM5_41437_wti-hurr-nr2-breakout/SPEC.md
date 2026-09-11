# QM5_41437_wti-hurr-nr2-breakout - Strategy Spec

**EA ID:** QM5_41437

**Slug:** `wti-hurr-nr2-breakout`

**Strategy ID:** `EIA-CRABEL-WTI-HURR-NR2-BREAKOUT-20260911_S01`

## 1. Strategy Logic

During an August-October normalized broker week, aggregate the two immediately completed
consecutive weeks. Require the newest full range to be strictly narrower than the preceding range,
then freeze its high-low box. Enter in the direction of the first current-week completed D1 close
strictly outside that box. Range and breakout equality are flat; range containment is irrelevant.
Consume the week only after a valid breakout is fully known and before fallible gates.

Hold one position at most through the entry week. Use a frozen `3.5*ATR(20,D1)` hard stop, no
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

Exact configured `XTIUSD.DWX` D1 carrier, slot zero, magic `414370000`. The symbol is an input;
no executable symbol literal is embedded in the EA and no external market data is read.

## 4. Timeframe

The host, signal, ATR, and execution timeframe is D1. Normalized labels group completed sessions
into Monday-anchored weeks. The trigger uses the just-completed current-week D1 close and must be
processed within 180 elapsed minutes of the new D1 bar.

## 5. Expected Behaviour

Only August, September, and October Monday anchors qualify. Each of the two immediately completed
weeks must have three to five valid unique sessions. After strict contraction, the first completed
close above/below the newest completed-week box enters long/short. Expected cadence is three to
eight positions per full year, with retirement below three in any full scored year.

## 6. Source Citation

The source packet is
`strategy-seeds/sources/EIA-CRABEL-WTI-HURR-NR2-BREAKOUT-20260911/source.md`. It combines official
EIA hurricane-risk context with governed Crabel range-state lineage. The exact rule, CFD efficacy,
and book correlation are not source claims.

| Contract | Implementation |
|---|---|
| no-trade | exact identity/risk/locked strategy checks; framework inputs unpinned |
| entry | hurricane calendar, two completed weeks, contraction, completed-close breakout, attempt, spread, ATR stop |
| management | symmetric position integrity, next-week closure, stale repair |
| close | framework reason mapping and broker hard stop |

## 7. Risk Model

Backtest: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`. Gaps, slippage, roll/basis,
financing, sparse seasonal sampling, delayed confirmation, and false breakouts can exceed modeled
risk. No live set, deployment, portfolio admission, `T_Live`, or AutoTrading action is authorized.

## Revision History

| Version | Date | Change | Task |
|---|---|---|---|
| v1 | 2026-09-11 | Initial build from approved card | OWNER pacer mission |
| v1-q01 | 2026-09-11 | Governed compile and strict build check PASS (`27ca36d0-4048-42b9-8322-cce59d692de4`) | OWNER pacer mission |
| v1-q02 | 2026-09-11 | CPU-admitted fixed-risk Q02 enqueued (`e29b85e8-c31d-42a5-a3d2-3abb5ed8ecae`) | OWNER pacer mission |
