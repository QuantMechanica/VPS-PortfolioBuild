# QM5_41375_wti-wmom1 - Strategy Spec

**EA ID:** QM5_41375  
**Slug:** `wti-wmom1`  
**Strategy ID:** `KWON-KANG-YUN-WTI-WMOM1-2026_S01`  
**Source:** `KWON-KANG-YUN-WTI-WMOM1-2026`  
**Last revised:** 2026-09-07

## Strategy

At the first tradable `XTIUSD.DWX` D1 bar of a new normalized broker week,
read only the immediately completed adjacent three-to-five-session week.
Compute `ln(final_close / first_open)`. Buy a strictly positive return, sell
a strictly negative return, and remain flat on exact zero or invalid history.
There is no volatility, body/range, magnitude, calendar, event, or other signal
filter.

Consume the normalized Monday anchor before fallible gates and never retry in
the same week. Hold at most one position until the next normalized week.
A ten-calendar-day limit repairs stale state only. Risk uses a frozen
`3.5*ATR(20,D1)` hard stop, no target, and the Q02 preset is fixed-dollar.

## Locked Strategy Parameters

| Parameter | Value |
|---|---:|
| `strategy_symbol` | `XTIUSD.DWX` |
| `strategy_label_offset_seconds` | 86400 |
| `strategy_entry_grace_minutes` | 180 |
| `strategy_history_bars` | 16 |
| `strategy_required_weeks` | 1 |
| `strategy_min_week_bars` | 3 |
| `strategy_max_week_bars` | 5 |
| `strategy_return_epsilon` | 0 |
| `strategy_atr_period_d1` | 20 |
| `strategy_atr_sl_mult` | 3.5 |
| `strategy_max_hold_days` | 10 |
| `strategy_max_spread_points` | 1500 |

Framework random-seed, news, Friday-close, stress-rejection, and portfolio-
weight values are not default-pinned by strategy validation. Stress rejection
is accepted only when finite and within inclusive `0..1`. The risk-mode
contract requires `RISK_PERCENT=0` and finite `RISK_FIXED>0`.

## Identity And Source Boundary

The source is Kwon, Kang, and Yun (2020), “Weekly Momentum in the Commodity
Futures Market,” *Finance Research Letters* 35, 101306,
DOI `10.1016/j.frl.2019.101306`. It establishes a cross-sectional
`CMOM1,1` commodity-futures result and includes light sweet crude oil. It
does not establish this standalone WTI time-series sign translation,
continuous-CFD basis, ATR stop, or portfolio decorrelation.

The source-of-record packet is
`strategy-seeds/sources/KWON-KANG-YUN-WTI-WMOM1-2026/source.md`.
The approved card is
`strategy-seeds/cards/approved/QM5_41375_wti-wmom1_card.md`.

This identity is distinct from `QM5_13049`, whose low-volatility filter is
load-bearing, and `QM5_41092`, whose two-thirds body/range gate is
load-bearing. Q02 owns activity and economics; Q09 alone may establish
realized correlation.

## Scope

- Exact host/traded symbol: `XTIUSD.DWX`, D1, slot 0, magic `413750000`.
- One fixed-risk backtest preset only.
- No optimization, stress, demo, shadow, or live preset.
- No manual terminal operation, AutoTrading, deploy manifest, T_Live change,
  portfolio admission, gate change, or correlation waiver.

## Revision History

| Version | Date | Gate | Status |
|---|---|---|---|
| v0 | 2026-09-07 | G0 | approved source and card |
| v1 | 2026-09-07 | Q01 | implementation awaiting validation |
