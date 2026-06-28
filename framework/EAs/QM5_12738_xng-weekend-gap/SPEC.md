# QM5_12738_xng-weekend-gap - Strategy Spec

**EA ID:** QM5_12738
**Slug:** `xng-weekend-gap`
**Source:** `EIA-XNG-WEEKEND-GAP-2026`
**Author of this spec:** Codex
**Last revised:** 2026-06-28

## 1. Strategy Logic

This EA implements a low-frequency structural natural-gas sleeve on
`XNGUSD.DWX`. It inspects each completed Monday D1 bar. If Monday opens with an
ATR-normalized gap from the previous trading-day close and then closes in the
gap direction with a minimum body, the EA enters continuation on the next D1
bar. It exits by max-hold timeout, signal-close invalidation, framework Friday
close, or the hard ATR stop.

The strategy is intentionally not a duplicate of `QM5_12567_cum-rsi2-commodity`
because it uses no RSI or oscillator logic. It is also not broad XNG
seasonality, storage aftershock, freeze-fade, hurricane breakout,
shoulder-season fade, prestorage, injection, or XTI/XNG basket logic.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 20 | 14-30 | ATR normalization and stop period |
| `strategy_min_gap_atr` | 0.35 | 0.25-0.75 | Minimum Monday open gap as ATR fraction |
| `strategy_min_body_atr` | 0.20 | 0.10-0.30 | Minimum same-day body as ATR fraction |
| `strategy_atr_sl_mult` | 2.75 | 2.0-3.5 | Stop distance multiplier |
| `strategy_max_hold_days` | 4 | 2-6 | Calendar-day time exit |
| `strategy_max_spread_points` | 2500 | 1500-3500 | Entry spread cap |

## 3. Symbol Universe

- `XNGUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 6-14.
- Typical hold: 1-4 calendar days, segmented by Friday close when applicable.
- Regime preference: natural-gas repricing after weekend weather/demand forecast shocks.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

U.S. Energy Information Administration natural-gas price/weather demand source
packet captured under `EIA-XNG-WEEKEND-GAP-2026`.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, portfolio-admission artifact, or live-terminal file is touched by this build.
