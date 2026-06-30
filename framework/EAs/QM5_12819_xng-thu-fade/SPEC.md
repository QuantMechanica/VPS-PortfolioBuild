# QM5_12819_xng-thu-fade - Strategy Spec

**EA ID:** QM5_12819
**Slug:** `xng-thu-fade`
**Source:** `MEEK-HOELSCHER-XNG-DOW-2023`
**Author of this spec:** Codex
**Last revised:** 2026-06-30

## 1. Strategy Logic

This EA implements a low-frequency structural Natural Gas weekday-seasonality
sleeve on `XNGUSD.DWX`. On each new D1 bar, it permits a short entry only when
the current broker-calendar day is Thursday. The position is flattened on the
first subsequent non-Thursday D1 bar or by a one-calendar-day stale-position
guard. The only price-derived input is ATR for the hard stop.

The strategy is intentionally not a duplicate of the existing XNG family:
`QM5_12818_xng-tue-prem` trades Tuesday long only, while this EA trades
Thursday short only. It also uses no RSI, storage-report timing, weather event
trigger, month-of-year window, 52-week anchor, month-open breakout,
volatility-shock fade, XTI/XNG basket, or medium-term trend/reversal logic.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 20 | 14-30 | ATR period for the hard stop |
| `strategy_atr_sl_mult` | 2.75 | 2.0-3.5 | ATR stop distance multiplier |
| `strategy_max_hold_days` | 1 | 1-2 | Calendar-day stale-position guard |
| `strategy_entry_dow` | 4 | 4 | Broker-calendar Thursday, where Sunday=0 |
| `strategy_max_spread_points` | 2500 | 1500-3500 | Entry spread cap |

## 3. Symbol Universe

- `XNGUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 45-52.
- Typical hold: one D1 bar.
- Regime preference: Natural Gas Thursday calendar-fade seasonality.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

Meek, H. and Hoelscher, S. A., "Day-of-the-week effect: Petroleum and
petroleum products", Cogent Economics and Finance 11(1), 2023, DOI
https://doi.org/10.1080/23322039.2023.2213876.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.
