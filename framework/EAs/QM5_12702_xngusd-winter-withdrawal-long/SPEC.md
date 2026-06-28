# QM5_12702_xngusd-winter-withdrawal-long - Strategy Spec

**EA ID:** QM5_12702
**Slug:** `xngusd-winter-withdrawal-long`
**Source:** `706222b7-2d60-5fdb-8dab-d722d3c96f92`
**Author of this spec:** Codex
**Last revised:** 2026-06-28

## 1. Strategy Logic

This EA implements a low-frequency structural natural-gas sleeve on
`XNGUSD.DWX`. It trades only from the D1 chart. On the first D1 bar of each
new broker-calendar month, it enters long if the month is November through
March and the prior completed close is above SMA(`strategy_trend_period`).

It exits on season end, trend failure, max hold, framework Friday close, or
the hard ATR stop. Runtime uses MT5 OHLC and broker calendar state only.

The strategy is intentionally not a duplicate of `QM5_12567_cum-rsi2-commodity`
because it uses no RSI or oscillator logic. It is also not the broad
`QM5_12575` dual-peak/shoulder-season map and not the winter breakout/event
or weekend-gap XNG family.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_trend_period` | 42 | 21-84 | SMA confirmation and trend-failure exit |
| `strategy_atr_period` | 20 | 14-30 | ATR stop period |
| `strategy_atr_sl_mult` | 3.0 | 2.0-4.0 | Stop distance multiplier |
| `strategy_max_hold_days` | 35 | 21-45 | Calendar-day stale-position exit |
| `strategy_max_spread_points` | 2500 | 1500-3500 | Entry spread cap |

## 3. Symbol Universe

- `XNGUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 3-5.
- Typical hold: up to 35 calendar days, segmented by Friday close when applicable.
- Regime preference: winter heating/withdrawal demand with positive D1 trend confirmation.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

U.S. Energy Information Administration, "Natural gas consumption, production
respond to seasonal changes", Today in Energy, 2015-09-24, captured under
`strategy-seeds/sources/706222b7-2d60-5fdb-8dab-d722d3c96f92/source.md`.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, portfolio-admission artifact, AutoTrading setting, or live-terminal
file is touched by this build.
