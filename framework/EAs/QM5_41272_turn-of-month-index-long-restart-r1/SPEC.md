# QM5_41272_turn-of-month-index-long-restart-r1 — Strategy Spec

**EA ID:** QM5_41272  
**Slug:** `turn-of-month-index-long-restart-r1`  
**Source:** faithful new-identity recovery of OWNER-approved QM5_20004  
**Authority:** task `2e0bc944-0f47-47e2-b6c2-e7b83db89147`  
**Last revised:** 2026-09-01

## 1. Strategy Logic

On the new-month D1 calendar edge, enter one long `NDX.DWX` position at the
first available price when the prior D1 close is at or above SMA(50). Use the
unchanged ATR(20) × 3 protective stop, no fixed take profit, and exit after
three completed D1 trading-day transitions. Framework news blackout and Friday
close controls remain authoritative.

### Restart invariant

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

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_exit_day_n` | 3 | Completed D1 transitions before exit |
| `strategy_trend_filter_enabled` | true | Require prior close at/above SMA |
| `strategy_trend_sma_period` | 50 | D1 trend SMA |
| `strategy_atr_period` | 20 | D1 ATR period |
| `strategy_sl_atr_mult` | 3.0 | Initial stop distance |

## 3. Symbol Universe

The authorized universe is exactly `NDX.DWX`. This recovery does not broaden
the parent strategy to another index, CFD, currency, commodity, or basket.

## 4. Timeframe

The strategy operates on completed `D1` bars. The new-month edge, trend SMA,
ATR stop, restart reconstruction, and held-day transitions all use the same
broker `D1` stream. No lower-timeframe or look-ahead input is used.

## 5. Expected Behaviour

The card expects approximately 12 long entry events per year. A trade may be
filtered when the prior close is below SMA(50), and an open trade exits after
three completed trading-day transitions or earlier through its hard stop or a
framework safety exit. Restarting the EA must not extend the holding period:
an inherited position reconstructs elapsed D1 transitions from
`POSITION_TIME`. The strategy never pyramids, grids, martingales, or shorts.

## 6. Source Citation

This is the faithful new-identity recovery of the OWNER-approved
`QM5_20004_turn-of-month-index-long` card. The economic rule is sourced to
McConnell and Xu (2008), DOI `10.2469/faj.v64.n2.11`, with the earlier
turn-of-month evidence of Lakonishok and Smidt (1988). Recovery authority is
OWNER task `2e0bc944-0f47-47e2-b6c2-e7b83db89147` dated 2026-09-01.

## 7. Risk Model

Backtests use `RISK_FIXED=1000` and `RISK_PERCENT=0`. The stale-news ceiling is
336 hours. Every entry carries the fixed ATR(20) × 3 hard stop; the V5
framework retains the mandatory news blackout, Friday close, daily and total
drawdown controls, and one-position ownership. This build grants no live,
deployment, T_Live, or AutoTrading authorization.
