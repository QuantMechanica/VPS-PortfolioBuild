# QM5_12589_eia-rbob-shoulder - Strategy Spec

**EA ID:** QM5_12589
**Slug:** `eia-rbob-shoulder`
**Source:** `EIA-RBOB-CRACK-SEASON-2025`
**Author of this spec:** Codex / Claude
**Last revised:** 2026-07-05

## 1. Strategy Logic

This EA implements a low-frequency structural WTI sleeve on `XTIUSD.DWX`.
It trades short-only during the post-summer gasoline crack-spread shoulder:
September 1 through November 15. Entry requires a recent gasoline-season high
inside the setup window, a failed D1 trend state below a falling SMA, and a
break below a short trigger low. Positions exit on date-window expiry, trend
recovery, recovery-channel break, max-hold timeout, or the ATR stop.

The strategy is intentionally not a duplicate of:

- `QM5_12567_cum-rsi2-commodity`: short-horizon RSI pullback.
- `QM5_12576_eia-wti-season`: monthly WTI SMA/ROC seasonality.
- `QM5_12579_eia-wti-aftershock`: weekly WPSR aftershock.
- `QM5_12581_eia-rbob-crack`: two-sided seasonal channel breakout/breakdown.
- `QM5_12585_eia-rbob-pullback`: gasoline-window long pullback continuation.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_setup_lookback` | 42 | 30-63 | Bars searched for the failed gasoline-season high |
| `strategy_peak_recent_bars` | 15 | 10-21 | Max age of setup-window peak |
| `strategy_trend_period` | 63 | 42-100 | D1 SMA trend-failure period |
| `strategy_sma_slope_shift` | 10 | 5-15 | Bars for falling-SMA confirmation |
| `strategy_trigger_lookback` | 5 | 3-8 | Previous-bar low trigger for short entry |
| `strategy_exit_lookback` | 8 | 5-13 | Previous-bar high recovery exit |
| `strategy_atr_period` | 20 | 14-30 | ATR stop period |
| `strategy_atr_sl_mult` | 3.0 | 2.0-4.0 | Stop distance multiplier |
| `strategy_max_hold_days` | 25 | 15-35 | Calendar-day max hold |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 3-7.
- Typical hold: several days to a few weeks.
- Regime preference: post-summer crude shoulder after gasoline crack support fades.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

U.S. Energy Information Administration, "Gasoline crack spreads rise ahead of
the summer driving season", This Week in Petroleum, 2025-03-12, URL
https://www.eia.gov/petroleum/weekly/archive/2025/250312/includes/analysis_print.php.

The source is used only for structural lineage; the EA uses Darwinex MT5 OHLC
at runtime and no external EIA, RBOB, refinery, inventory, or futures-spread feed.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest or `T_Live` file is touched by this build.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-26 | Initial build from card | 86fdf89e1 |
| v1.1 | 2026-07-05 | Pre-smoke correctness fix on the same build task (f2146adf-d9c9-47dc-b5d4-03d8b7d10396): reordered `OnTick` so the news blackout gate sits below `Strategy_ManageOpenPosition`/`Strategy_ExitSignal` per the 2026-07-02 audit finding (management/exit must keep enforcing through news windows), removed a forbidden per-EA `g_last_signal_day_key` bar-gate variable (redundant with the framework `QM_IsNewBar()` gate), and moved all discretionary-close logic into `Strategy_ExitSignal` (was living in `Strategy_ManageOpenPosition`, leaving `Strategy_ExitSignal` a permanent no-op). Regenerated the setfile via `gen_setfile.ps1` (prior one predated several framework inputs). Ran the deferred Q01 smoke: 3 deterministic trades on XTIUSD.DWX 2024, within the card's own 3-7/yr estimate. | this build |
| v1.2 | 2026-07-06 | Same build task (f2146adf-d9c9-47dc-b5d4-03d8b7d10396), rework wake: `Strategy_EntrySignal` computed the SL via `QM_StopATR(...)`, which internally opens a raw `iATR()` handle and `CopyBuffer`+`IndicatorRelease`s it in the same call — the confirmed root cause (2026-07-05/06, QM5_12852/12616/12594/12591) of a WTI/D1 ATR-stop defect class that produces exactly 1 (or occasionally a handful of lucky-warm-cache) trades then permanent silence. Swapped to the pooled `QM_ATR(...)` reader + `QM_StopATRFromValue(...)`. Also found the officially-recorded `build_result.json` for this task had regressed to the stale June-26 `deferred_p2_smoke` content (duplicate-dispatch class per memory) — this build supersedes it with a fresh honest result. | this build |
