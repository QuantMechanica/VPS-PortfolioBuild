# QM5_12602_eia-xng-frzfade - Strategy Spec

**EA ID:** QM5_12602
**Slug:** `eia-xng-frzfade`
**Source:** `EIA-XNG-FREEZE-2026`
**Author of this spec:** Codex
**Last revised:** 2026-06-27

## 1. Strategy Logic

This EA implements a low-frequency XNGUSD.DWX winter freeze-off spike fade.
On each new D1 bar, it evaluates only the prior closed bar. Entries are
allowed only in January-February. A short trade opens only after XNGUSD.DWX
prints an extreme upside winter spike that reaches a recent high, remains
stretched above SMA, has ATR-normalized range, and closes as a bearish
rejection candle.

The strategy is intentionally not a duplicate of the existing XNG family:
storage aftershock, broad seasonality, spring calendar, winter withdrawal
breakout, injection-season breakdown, summer power squeeze, shoulder fade,
hurricane breakout, and commodity RSI pullback all use different timing or
entry logic.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_reject_lookback` | 20 | 15-30 | Prior completed D1 bars for spike high test |
| `strategy_exit_channel` | 10 | 7-15 | Prior completed D1 bars for short invalidation |
| `strategy_trend_period` | 63 | 42-84 | SMA mean reference |
| `strategy_atr_period` | 20 | 14-30 | ATR period for stop/range/stretch filters |
| `strategy_min_range_atr` | 1.10 | 0.90-1.50 | Prior-bar range floor as ATR multiple |
| `strategy_min_stretch_atr` | 1.75 | 1.25-2.25 | Signal close stretch above SMA |
| `strategy_min_upper_wick_ratio` | 0.30 | 0.25-0.40 | Minimum upper wick share of signal-bar range |
| `strategy_atr_sl_mult` | 3.25 | 2.5-4.0 | ATR stop distance multiplier |
| `strategy_max_hold_days` | 8 | 5-12 | Calendar-day stale-position guard |
| `strategy_max_spread_points` | 2500 | 1500-3500 | Entry spread cap |

## 3. Symbol Universe

- `XNGUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 2-6.
- Typical hold: several D1 bars; capped at 8 calendar days by default.
- Regime preference: January-February natural-gas winter weather spike risk.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

U.S. Energy Information Administration, "U.S. natural gas prices spiked in
February 2021, then generally increased through October", Today in Energy,
2022-01-06, URL https://www.eia.gov/todayinenergy/detail.php?id=50778.
Supplement: EIA, "February 2021 weather triggers largest monthly decline in
U.S. natural gas production", Today in Energy, 2021-05-10, URL
https://www.eia.gov/todayinenergy/detail.php?id=47896.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.
