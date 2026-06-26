# QM5_12592_eia-wti-prewpsr - Strategy Spec

**EA ID:** QM5_12592
**Slug:** `eia-wti-prewpsr`
**Source:** `EIA-WTI-WPSR-PRE-2026`
**Author of this spec:** Codex
**Last revised:** 2026-06-27

## 1. Strategy Logic

This EA implements a low-frequency structural WTI sleeve on `XTIUSD.DWX`.
On each new D1 bar, it permits entries only when the current broker-calendar
day is Wednesday or Thursday, matching the regular EIA Weekly Petroleum Status
Report day plus holiday-shift tolerance. It uses only prior completed D1 bars:
recent high-low ranges must be compressed versus ATR(20), and the prior close
must align with SMA(50) and 5-bar momentum. The EA holds through the pre/post
report window and exits on SMA failure or a short max-hold timer.

The strategy is intentionally not a duplicate of `QM5_12579_eia-wti-aftershock`
or `QM5_12590_eia-wti-wpsr-fade`: those EAs wait for the WPSR event-day bar to
close and then follow/fade that reaction. This EA enters before the event-day
reaction is known.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 20 | 14-30 | ATR period for compression and stop |
| `strategy_trend_period` | 50 | 34-84 | SMA trend anchor |
| `strategy_momentum_period` | 5 | 3-8 | Prior-close momentum comparison |
| `strategy_compression_lookback` | 3 | 2-5 | Prior completed bars used for range compression |
| `strategy_compression_atr_mult` | 0.90 | 0.75-1.05 | Maximum average range versus ATR |
| `strategy_atr_sl_mult` | 2.75 | 2.0-3.5 | Stop distance multiplier |
| `strategy_max_hold_days` | 2 | 1-3 | Calendar-day time exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 8-16.
- Typical hold: 1-2 D1 bars.
- Regime preference: pre-WPSR positioning after D1 compression.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

U.S. Energy Information Administration, "Weekly Petroleum Status Report", URL
https://www.eia.gov/petroleum/supply/weekly/. Release schedule URL
https://www.eia.gov/petroleum/supply/weekly/schedule.php.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest or `T_Live` file is touched by this build.
