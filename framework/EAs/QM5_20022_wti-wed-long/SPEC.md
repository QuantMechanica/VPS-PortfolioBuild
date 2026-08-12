# QM5_20022_wti-wed-long - Strategy Spec

**EA ID:** QM5_20022  
**Slug:** wti-wed-long  
**Source:** LI-WTI-DOW-2022  
**Last revised:** 2026-07-21

## Logic

At a genuine new `XTIUSD.DWX` D1 bar timestamped Wednesday
(`day_of_week == 3`, Sunday=0), consume one daily decision and attempt one BUY.
Close at the first following D1 bar, with a one-calendar-day stale retry guard.

The attempt is persisted before news, spread, ATR, price and order checks.
Attaching more than five minutes after Wednesday's bar open consumes the
missed initialization edge rather than entering late.

## Locked parameters

| Parameter | Value |
|---|---:|
| `strategy_entry_dow` | 3 |
| `strategy_atr_period` | 20 |
| `strategy_atr_sl_mult` | 2.75 |
| `strategy_max_hold_days` | 1 |
| `strategy_max_spread_points` | 2500 |

The host is `XTIUSD.DWX` D1, magic slot 0. No other symbol, timeframe,
weekday, direction, hold, stop or price filter is authorized.

## Expected behavior and risk

- Expected cadence: about 45-52 packages/year; Q02 floor is five/year.
- Entry: Wednesday BUY at market with prior-completed-bar ATR(20) hard stop.
- Exit: next D1 boundary, one-day stale guard, broker stop or framework Friday
  close at broker hour 21.
- Backtest: `RISK_FIXED=1000`, `RISK_PERCENT=0`, weight 1.
- No TP, trailing, break-even, scale, pyramid, grid, martingale, ML, banned
  indicator or external runtime data.

Li, Zhu, Wen and Nor (2022), *Energy Economics* 106, 105817, DOI
`10.1016/j.eneco.2022.105817`, report an abnormal positive Wednesday WTI
return associated with the scheduled inventory-information shock and also
report time-varying market efficiency. Q02 must falsify post-2021 persistence,
costs, continuous-CFD basis and broker-session mapping.

This build provides no live or portfolio authority and changes no portfolio
gate or deployment manifest.

## Revision history

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-07-21 | Initial source-backed WTI Wednesday Q02 candidate |
