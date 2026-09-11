# QM5_41441_wti-winter-nr2-breakout - Strategy Spec

**EA ID:** QM5_41441

**Slug:** `wti-winter-nr2-breakout`

**Strategy ID:** `BURAKOV-CRABEL-WTI-WINTER-NR2-BREAKOUT-20260911_S01`

## 1. Strategy Logic

During a November-May normalized broker week, aggregate the two immediately completed consecutive
weeks. Require the newest full range to be strictly narrower than the preceding range, then freeze
its high-low box. Enter in the direction of the first current-week completed D1 close strictly
outside that box. Range and breakout equality are flat; range containment is irrelevant. Consume
the week only after a valid breakout is fully known and before fallible gates.

Hold one position at most through the entry week. Use a frozen `3.5*ATR(20,D1)` hard stop, no
target, next-week closure, and ten-day stale repair.

## 2. Parameters

| Parameter | Value |
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
Framework RNG, news, Friday-close, stress rejection, and portfolio weight are not equality-pinned.
Stress rejection is checked only for finiteness and inclusive `0..1`. The backtest risk contract
requires finite `RISK_FIXED>0` and `RISK_PERCENT=0`.

## 3. Symbol Universe

Exact configured `XTIUSD.DWX` D1 carrier, slot zero, magic `414410000`. The symbol is an input;
no executable symbol literal is embedded in the EA and no external market data is read.

## 4. Timeframe

The host, signal, ATR, and execution timeframe is D1. Normalized labels group completed sessions
into Monday-anchored weeks. The trigger uses the just-completed current-week D1 close and must be
processed within 180 elapsed minutes of the new D1 bar.

## 5. Expected Behaviour

Only November through May Monday anchors qualify. Each of the two immediately completed weeks
must have three to five valid unique sessions. After strict contraction, the first completed close
above or below the newest completed-week box enters long or short. Expected cadence is five to
fifteen positions per full year, with retirement below five in any full scored year.

## 6. Source Citation And Non-Duplicate Boundary

The source packet is
`strategy-seeds/sources/BURAKOV-CRABEL-WTI-WINTER-NR2-BREAKOUT-20260911/source.md`. It combines
peer-reviewed WTI November-May seasonality with governed reputable Crabel range-state lineage.
The exact rule, CFD efficacy, and book correlation are not source claims.

`QM5_41439` uses the same chronology on XNG and only during November-March. `QM5_41437` uses the
WTI carrier only in August-October. `QM5_41440` uses WTI November-May but requires range expansion,
an immediate upper-quartile close, and a long-only entry. Certified `QM5_12567` is an XNG
cumulative-RSI pullback.

## Framework Alignment

| Contract | Implementation |
|---|---|
| no-trade | exact identity/risk/locked strategy checks; framework inputs unpinned |
| entry | winter calendar, two completed weeks, contraction, completed-close breakout, attempt, spread, ATR stop |
| management | symmetric position integrity, next-week closure, stale repair |
| close | framework reason mapping and broker hard stop |

## 7. Risk Model

Backtest: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`. Gaps, slippage, roll/basis,
financing, sparse seasonal sampling, delayed confirmation, false breakouts, and overlap with other
WTI candidates can exceed modeled risk. No live set, deployment, portfolio admission, `T_Live`,
or AutoTrading action is authorized.

## Revision History

| Version | Date | Change | Task |
|---|---|---|---|
| v1 | 2026-09-11 | Initial build from approved card | OWNER pacer mission |
