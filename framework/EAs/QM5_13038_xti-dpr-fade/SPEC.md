# QM5_13038_xti-dpr-fade - Strategy Spec

**EA ID:** QM5_13038
**Slug:** `xti-dpr-fade`
**Source:** `EIA-DPR-XTI-MOM-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-07

## 1. Strategy Logic

This EA implements a low-frequency WTI monthly shale-production information
window on `XTIUSD.DWX`. On each new D1 bar it inspects the previous completed
D1 bar and checks whether that bar was inside the EIA Drilling Productivity
Report proxy window, broker-calendar days 12 through 16 by default.

The implementation is a failed-breakout fade, not the existing DPR momentum
logic. It requires an ATR-sized proxy bar to breach the prior Donchian channel,
close back inside that channel, print a reversal body and tail, and remain
stretched on the far side of the SMA. The EA then enters the next D1 bar in the
opposite direction and exits on ATR stop/target, SMA mean reversion, max-hold,
standard V5 news, and Friday-close controls. No external runtime data is read.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_event_start_day` | 12 | 11-13 | First broker-calendar day eligible for the DPR proxy window |
| `strategy_event_end_day` | 16 | 15-17 | Last broker-calendar day eligible for the DPR proxy window |
| `strategy_breakout_lookback` | 20 | 10-30 | Prior D1 Donchian window excluding the DPR proxy bar |
| `strategy_trend_period` | 80 | 50-120 | SMA mean/stretch period |
| `strategy_atr_period` | 20 | 14-30 | ATR period for event sizing and stop/target |
| `strategy_min_range_atr` | 1.00 | 0.80-1.20 | Minimum event-bar high-low range in ATR units |
| `strategy_min_body_atr` | 0.30 | 0.20-0.45 | Minimum absolute event-bar body in ATR units |
| `strategy_min_tail_atr` | 0.20 | 0.00-0.35 | Minimum failed-breakout tail in ATR units |
| `strategy_atr_sl_mult` | 2.5 | 2.0-3.0 | ATR stop distance |
| `strategy_atr_tp_mult` | 2.0 | 1.5-3.0 | ATR target distance |
| `strategy_max_hold_days` | 6 | 4-8 | Calendar-day stale-position exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 3-7.
- Typical hold: several D1 bars, capped by stale-position and SMA
  mean-reversion guards.
- Regime preference: monthly U.S. shale/tight-oil production information
  window where a channel breach is rejected rather than continued.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

U.S. Energy Information Administration, Drilling Productivity Report and DPR
FAQ:

- https://www.eia.gov/petroleum/drilling/
- https://www.eia.gov/petroleum/drilling/faqs.php

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.
