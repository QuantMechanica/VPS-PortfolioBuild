# QM5_12591_eia-wti-hurr-brk - Strategy Spec

**EA ID:** QM5_12591
**Slug:** `eia-wti-hurr-brk`
**Source:** `EIA-WTI-HURRICANE-2025`
**Author of this spec:** Claude
**Last revised:** 2026-07-05

## 1. Strategy Logic

This EA implements a low-frequency structural WTI hurricane-season sleeve on
`XTIUSD.DWX`. During the EIA-documented Atlantic hurricane-season petroleum-risk
window, it buys only after the prior closed D1 bar breaks above a short channel,
closes strong in its range, expands versus ATR, and remains above a slow D1 SMA.
It exits on season end, a failed breakout channel close, SMA failure, fixed max
hold, or the entry ATR stop.

The strategy is intentionally not a duplicate of `QM5_12563`: it is long-only,
single-symbol XTI, hurricane-season gated, and time-bounded rather than a
full-year symmetric Turtle trend across commodity symbols. It is also distinct
from WTI monthly seasonality, RBOB crack-spread, and WPSR inventory-event EAs.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_entry_channel` | 12 | 8-20 | Prior D1 high channel for upside breakout |
| `strategy_exit_channel` | 6 | 4-10 | Prior D1 low channel for failed-breakout exit |
| `strategy_trend_period` | 50 | 34-84 | D1 SMA trend confirmation and exit |
| `strategy_atr_period` | 20 | 14-30 | ATR period for range filter and stop |
| `strategy_min_range_atr` | 0.80 | 0.60-1.25 | Minimum signal-bar range versus ATR |
| `strategy_min_close_location` | 0.65 | 0.60-0.75 | Minimum signal-bar close location |
| `strategy_atr_sl_mult` | 3.0 | 2.0-4.0 | Stop distance multiplier |
| `strategy_max_hold_days` | 12 | 6-20 | Calendar-day time exit |
| `strategy_start_month` | 6 | 6-8 | First eligible calendar month |
| `strategy_end_month` | 11 | 9-11 | Last eligible calendar month |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 5-10.
- Typical hold: several D1 bars up to about two weeks.
- Regime preference: hurricane-season WTI supply-risk upside breakouts.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

U.S. Energy Information Administration, "Refining industry risks from 2025
hurricane season", Today in Energy, URL
https://www.eia.gov/todayinenergy/detail.php?id=65304.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest or `T_Live` file is touched by this build.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-27 | Initial build from card | task fb9242d4-5cab-41f7-aa3b-ea2b3de38349 (prior smoke attempts: INFRA_FAIL/ONINIT_FAILED family) |
| v2 | 2026-07-05 | Rebuild in place: OnTick reordered so the two-axis news gate sits below `Strategy_ManageOpenPosition`/`Strategy_ExitSignal` and gates only entries (2026-07-02 binding audit fix); replaced hand-rolled `iTime`+`TimeToStruct` season-month key with `QM_CalendarPeriodKey(PERIOD_MN1)`; per-bar channel/ATR/SMA state now computed once per closed bar via `Strategy_AdvanceCachedState()` and cached, removing duplicate `CopyRates` calls. No change to Entry/Exit/Stop mechanics vs the card. | task fb9242d4-5cab-41f7-aa3b-ea2b3de38349 |
