# QM5_41272_turn-of-month-index-long-restart-r1 — Strategy Spec

**EA ID:** QM5_41272  
**Slug:** `turn-of-month-index-long-restart-r1`  
**Source:** faithful new-identity recovery of OWNER-approved QM5_20004  
**Authority:** task `2e0bc944-0f47-47e2-b6c2-e7b83db89147`  
**Last revised:** 2026-09-01

## Mechanics

On the new-month D1 calendar edge, enter one long `NDX.DWX` position at the
first available price when the prior D1 close is at or above SMA(50). Use the
unchanged ATR(20) × 3 protective stop, no fixed take profit, and exit after
three completed D1 trading-day transitions. Framework news blackout and Friday
close controls remain authoritative.

## Restart invariant

When initialization finds an inherited owned position, the EA reads its
`POSITION_TIME`, locates its containing `NDX.DWX` D1 bar with `iBarShift`, and
sets the held-day counter to that bar's current shift. Current D1 is shift zero;
therefore this reconstructs completed trading-day transitions without counting
weekends or holidays. Failure to locate the entry bar fails initialization.
The EA never adopts today's day key as though an inherited position opened
today.

This is the only implementation change from QM5_20004. Entry, filter, stop,
sizing, news, Friday-close, and exit thresholds are unchanged. Old QM5_20004
evidence is immutable and is not rebound to this identity.

## Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_exit_day_n` | 3 | Completed D1 transitions before exit |
| `strategy_trend_filter_enabled` | true | Require prior close at/above SMA |
| `strategy_trend_sma_period` | 50 | D1 trend SMA |
| `strategy_atr_period` | 20 | D1 ATR period |
| `strategy_sl_atr_mult` | 3.0 | Initial stop distance |

Backtests use `RISK_FIXED=1000` and `RISK_PERCENT=0`. The stale-news ceiling is
336 hours. This build grants no live authorization.
