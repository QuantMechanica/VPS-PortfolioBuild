# QM5_41376_wti-wmom42 - Strategy Spec

**EA ID:** QM5_41376  
**Slug:** `wti-wmom42`  
**Strategy ID:** `KWON-KANG-YUN-WTI-WMOM42-2026_S01`  
**Source:** `KWON-KANG-YUN-WTI-WMOM42-2026`  
**Last revised:** 2026-09-07

## Strategy

At the first tradable `XTIUSD.DWX` D1 bar of broker week `t`, reconstruct four
consecutive completed three-to-five-session weeks. Exclude week `t-1` and
compute `ln(final_close[t-2] / first_open[t-4])`. Buy a strictly positive
return, sell a strictly negative return, and stay flat on exact zero or invalid
history. There is no volatility, magnitude, body/range, calendar, or event
signal filter.

Consume the normalized Monday anchor before fallible gates and never retry in
the same week. Hold at most one position until the next normalized week. A ten-
day limit repairs stale state only. Risk uses a frozen `3.5*ATR(20,D1)` hard
stop, no target, and the Q02 preset is fixed-dollar.

## Locked Strategy Parameters

| Parameter | Value |
|---|---:|
| `strategy_symbol` | `XTIUSD.DWX` |
| `strategy_label_offset_seconds` | 86400 |
| `strategy_entry_grace_minutes` | 180 |
| `strategy_history_bars` | 40 |
| `strategy_formation_weeks` | 3 |
| `strategy_skip_recent_weeks` | 1 |
| `strategy_min_week_bars` | 3 |
| `strategy_max_week_bars` | 5 |
| `strategy_return_epsilon` | 0 |
| `strategy_atr_period_d1` | 20 |
| `strategy_atr_sl_mult` | 3.5 |
| `strategy_max_hold_days` | 10 |
| `strategy_max_spread_points` | 1500 |

Framework random seed, news, Friday-close, stress rejection, and portfolio
weight are not default-pinned. Stress rejection is accepted only when finite
and in inclusive `0..1`. Risk requires `RISK_PERCENT=0` and finite
`RISK_FIXED>0`.

## Identity And Source Boundary

Kwon, Kang, and Yun (2020), “Weekly Momentum in the Commodity Futures Market,”
defines cross-sectional `CMOM4,2` and includes light sweet crude oil. It does
not establish this standalone WTI time-series port, CFD basis, ATR stop, or
decorrelation. The paper also reports that `CMOM4,2` is largely spanned by its
one-week signal; Q02 owns economics and Q09 alone owns realized correlation.

The source packet is
`strategy-seeds/sources/KWON-KANG-YUN-WTI-WMOM42-2026/source.md`; the approved
card is `strategy-seeds/cards/approved/QM5_41376_wti-wmom42_card.md`.

The load-bearing distinction from `QM5_41375` is the exact `t-4..t-2`
formation and complete exclusion of `t-1`. The monthly skip-one system uses a
twelve-month clock, not this weekly formation/hold contract.

## Scope

- Exact preset-bound host/traded symbol: `XTIUSD.DWX`, D1, slot 0, magic
  `413760000`.
- One fixed-risk backtest preset only.
- No optimization, stress, demo, shadow, or live preset.
- No manual terminal operation, AutoTrading, deploy manifest, T_Live change,
  portfolio admission, gate change, or correlation waiver.

## Revision History

| Version | Date | Gate | Status |
|---|---|---|---|
| v0 | 2026-09-07 | G0 | approved source and card |
| v1 | 2026-09-07 | Q01 | implementation and deterministic reference validation |
| v2 | 2026-09-07 | Q01/Q02 | governed compile/build-check PASS; Q02 stopped before enqueue at CPU ceiling |
