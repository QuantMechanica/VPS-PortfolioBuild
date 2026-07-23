# QM5_20053 XCU Weekend Premium

**EA ID:** QM5_20053  
**Slug:** xcu-weekend-prem  
**Source:** BOROWSKI-LUKASIK-METALS-2017  
**Date:** 2026-07-23

## 1. Strategy Logic

On the broker Friday 21:00 H1 boundary, the EA makes one restart-safe attempt
to buy XCUUSD.DWX with a fixed-risk ATR stop. It closes the position at the
first Monday H1 boundary or after four calendar days.

## 2. Parameters

| Parameter | Baseline | Purpose |
|---|---:|---|
| strategy_entry_dow | 5 | Friday entry |
| strategy_entry_hour_broker | 21 | Broker-hour boundary |
| strategy_entry_grace_minutes | 5 | Late-tick tolerance |
| strategy_atr_period_d1 | 20 | D1 ATR stop basis |
| strategy_atr_sl_mult | 3.0 | Hard-stop distance |
| strategy_max_hold_days | 4 | Stale-position guard |
| strategy_max_spread_points | 1000 | Entry spread cap |

## 3. Symbol Universe

- `XCUUSD.DWX`: direct copper CFD expression of the source-reported effect.

## 4. Timeframe

H1 host/decision timeframe with D1 ATR used only for the protective stop.

## 5. Expected Behaviour

Approximately 48 weekly attempts per year before framework filters. Typical
hold is Friday evening through the first Monday bar. The effect is expected to
be vulnerable to weekend gaps, financing, and broker-boundary differences.

## 6. Source Citation

`BOROWSKI-LUKASIK-METALS-2017`; see
`strategy-seeds/sources/BOROWSKI-LUKASIK-METALS-2017/source.md`. R1-R4 are
approved in `strategy-seeds/cards/approved/QM5_20053_xcu-weekend-prem_card.md`.

## 7. Risk Model

| Environment | Active risk | Inactive risk |
|---|---|---|
| Backtest | RISK_FIXED=1000 | RISK_PERCENT=0 |
| Live | Not authorized | No live setfile |

One position per magic, fixed server-side ATR stop, portfolio weight 1.0.

## Revision History

| Version | Date | Change | Task |
|---|---|---|---|
| v1 | 2026-07-23 | Initial build from approved card | 10c28272-d6c3-4c80-9325-1d7758d8acd0 |
