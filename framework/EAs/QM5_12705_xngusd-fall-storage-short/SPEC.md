# QM5_12705_xngusd-fall-storage-short - Strategy Spec

**EA ID:** QM5_12705
**Slug:** `xngusd-fall-storage-short`
**Source:** `706222b7-2d60-5fdb-8dab-d722d3c96f92`
**Author of this spec:** Codex
**Last revised:** 2026-06-29

## 1. Strategy Logic

This EA implements a low-frequency structural natural-gas sleeve on
`XNGUSD.DWX`. It trades only from the D1 chart. On the first D1 bar of each
new broker-calendar week, it enters short if the month is September or October
and the prior completed close is below SMA(`strategy_trend_period`).

It exits on season end, SMA recovery, max hold, framework Friday close, or the
hard ATR stop. Runtime uses MT5 OHLC and broker calendar state only.

The strategy is intentionally not a duplicate of `QM5_12567_cum-rsi2-commodity`
because it uses no RSI or oscillator logic. It is also not the broad
`QM5_12575` dual-peak/shoulder-season map, not the spring-only `QM5_12703`
sleeve, not the winter/summer long sleeves `QM5_12702` and `QM5_12704`, and
not XNG storage-report/event/fade/weekend-gap logic.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_trend_period` | 42 | 21-84 | SMA confirmation and trend-recovery exit |
| `strategy_atr_period` | 20 | 14-30 | ATR stop period |
| `strategy_atr_sl_mult` | 3.0 | 2.0-4.0 | Stop distance multiplier |
| `strategy_max_hold_days` | 21 | 14-28 | Calendar-day stale-position exit |
| `strategy_max_spread_points` | 2500 | 1500-3500 | Entry spread cap |

## 3. Symbol Universe

- `XNGUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 4-8.
- Typical hold: up to 21 calendar days, segmented by Friday close when applicable.
- Regime preference: fall shoulder/storage window with negative D1 trend confirmation.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

U.S. Energy Information Administration, "Natural gas use features two seasonal
peaks per year", Today in Energy, 2015-09-11, captured under
`strategy-seeds/sources/706222b7-2d60-5fdb-8dab-d722d3c96f92/source.md`.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, portfolio-admission artifact, AutoTrading setting, or live-terminal
file is touched by this build.
