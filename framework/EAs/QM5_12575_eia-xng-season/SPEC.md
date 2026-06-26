# QM5_12575_eia-xng-season - Strategy Spec

**EA ID:** QM5_12575
**Slug:** `eia-xng-season`
**Source:** `706222b7-2d60-5fdb-8dab-d722d3c96f92`
**Author of this spec:** Codex
**Last revised:** 2026-06-26

## 1. Strategy Logic

This EA implements a low-frequency structural natural-gas sleeve on `XNGUSD.DWX`.
On the first new D1 bar of each calendar month, it maps the active month to a
seasonal direction: long during winter/summer demand-peak months, short during
spring/autumn shoulder months, and flat in transition months. Entry requires the
prior closed D1 close to confirm the direction versus SMA(63). Risk is controlled
with a fixed ATR(20) * 3.0 hard stop.

The strategy is intentionally not a duplicate of `QM5_12567_cum-rsi2-commodity`:
it does not use RSI or short-horizon pullback logic.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_trend_period` | 63 | 42-126 | D1 SMA confirmation period |
| `strategy_atr_period` | 20 | 14-30 | ATR stop period |
| `strategy_atr_sl_mult` | 3.0 | 2.0-5.0 | Stop distance multiplier |
| `strategy_max_spread_points` | 800 | 500-1200 | Entry spread cap |

## 3. Symbol Universe

- `XNGUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 6.
- Typical hold: weeks to months.
- Regime preference: natural-gas seasonal demand/trend alignment.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

U.S. Energy Information Administration, "Natural gas consumption, production
respond to seasonal changes", Today in Energy, 2015-09-24, URL
https://www.eia.gov/todayinenergy/detail.php?id=22892.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest or `T_Live` file is touched by this build.
