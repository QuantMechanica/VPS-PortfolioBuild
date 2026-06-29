# QM5_12806_xng-rev-weekend - Strategy Spec

**EA ID:** QM5_12806
**Slug:** `xng-rev-weekend`
**Source:** `TGIF-XNG-WEEKEND-2017`
**Author of this spec:** Codex
**Last revised:** 2026-06-29

## 1. Strategy Logic

This EA implements a low-frequency structural natural-gas reverse-weekend
sleeve on `XNGUSD.DWX`. On each new D1 bar, it buys Monday bars and sells
Friday bars, then flattens on the first subsequent D1 bar or by a one-calendar
day stale-position guard. The only price-derived input is ATR for the hard
stop.

The strategy is intentionally not a duplicate of `QM5_12567_cum-rsi2-commodity`
because it uses no RSI or oscillator logic. It is also not the existing
`QM5_12738_xng-weekend-gap` continuation card because it does not require a
weekend gap, same-day body confirmation, weather-event proxy, or gap-direction
trigger.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 20 | 14-30 | ATR period for the hard stop |
| `strategy_atr_sl_mult` | 2.50 | 2.0-3.0 | ATR stop distance multiplier |
| `strategy_max_hold_days` | 1 | 1-2 | Calendar-day stale-position guard |
| `strategy_max_spread_points` | 2500 | 1500-3500 | Entry spread cap |
| `strategy_enable_monday_long` | true | true/false | Enable Monday long leg |
| `strategy_enable_friday_short` | true | true/false | Enable Friday short leg |

## 3. Symbol Universe

- `XNGUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 85-105.
- Typical hold: one D1 bar.
- Regime preference: natural-gas reverse weekend effect.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

Hoelscher, S. A., Mbanga, C. L., and Nelson, G. S., "TGIF? The Weekend
Effect in Energy Commodities", Journal of Finance Issues, URL
https://jfi-aof.org/index.php/jfi/article/view/2264.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.
