# QM5_10478_mql5-bago_v2 ? Strategy Spec

**EA ID:** QM5_10478
**Slug:** mql5-bago
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Author of this spec:** Codex
**Last revised:** 2026-05-29

---

## 1. Strategy Logic

This EA trades a closed-bar EMA and RSI confirmation signal on H1. It opens long when EMA(5) crosses above EMA(12), RSI(21) crosses above 50 on the same signal bar, and the close is above both EMA(144) and EMA(169). It opens short on the inverse signal below the slow tunnel. Exits are broker SL/TP, an opposite confirmed EMA/RSI signal, the framework Friday close, or a five-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_fast_ema_period | 5 | 1+ | Fast EMA period for the cross signal. |
| strategy_slow_ema_period | 12 | 1+ | Slow EMA period for the cross signal. |
| strategy_rsi_period | 21 | 1+ | RSI period used for midline confirmation. |
| strategy_rsi_midline | 50.0 | 0-100 | RSI threshold crossed with the EMA signal. |
| strategy_tunnel_ema_fast | 144 | 1+ | First slow EMA in the Vegas tunnel context filter. |
| strategy_tunnel_ema_slow | 169 | 1+ | Second slow EMA in the Vegas tunnel context filter. |
| strategy_atr_period | 14 | 1+ | ATR period for stop distance. |
| strategy_atr_sl_mult | 1.2 | 0+ | Minimum ATR stop multiplier. |
| strategy_swing_lookback | 5 | 1+ | Recent swing lookback for structure stop distance. |
| strategy_atr_sl_cap_mult | 2.5 | 0+ | ATR cap on the final stop distance. |
| strategy_take_profit_rr | 2.0 | 0+ | Take-profit distance as R multiple. |
| strategy_time_stop_bars | 5 | 0+ | Bars after which an open trade is closed if still active. |
| strategy_max_spread_points | 0 | 0+ | Optional spread guard; 0 disables the EA-specific cap. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX ? liquid FX major with H1 EMA, RSI, ATR, and OHLC coverage.
- GBPUSD.DWX ? liquid FX major with H1 EMA, RSI, ATR, and OHLC coverage.
- USDJPY.DWX ? liquid FX major with H1 EMA, RSI, ATR, and OHLC coverage.
- USDCHF.DWX ? liquid FX major with H1 EMA, RSI, ATR, and OHLC coverage.
- USDCAD.DWX ? liquid FX major with H1 EMA, RSI, ATR, and OHLC coverage.
- AUDUSD.DWX ? liquid FX major with H1 EMA, RSI, ATR, and OHLC coverage.
- NZDUSD.DWX ? liquid FX major with H1 EMA, RSI, ATR, and OHLC coverage.
- XAUUSD.DWX ? liquid metals symbol explicitly covered by the card's R3 indicator availability.
- XTIUSD.DWX ? liquid oil symbol explicitly covered by the card's baseline universe.
- SP500.DWX ? liquid US index custom symbol available for backtest coverage.
- NDX.DWX ? liquid US index CFD with the required indicator and OHLC data.
- WS30.DWX ? liquid US index CFD with the required indicator and OHLC data.
- GDAXI.DWX ? liquid European index CFD with the required indicator and OHLC data.
- UK100.DWX ? liquid European index CFD with the required indicator and OHLC data.

**Explicitly NOT for:**
- Symbols absent from framework/registry/dwx_symbol_matrix.csv ? no broker or custom-symbol data guarantee.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 90 |
| Typical hold time | Up to 5 H1 bars unless SL, TP, or opposite signal fires first |
| Expected drawdown profile | Fixed-risk trend-following losses clustered during choppy EMA/RSI midline whipsaws |
| Regime preference | trend-following |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** MQL5 CodeBase
**Pointer:** MQL5 CodeBase, "Bago EA - expert for MetaTrader 5", published 2018-12-28, updated 2019-01-22, https://www.mql5.com/en/code/22870
**R1?R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10478_mql5-bago_v2.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 ? Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% ? 0.5%) |

ENV?mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-05-29 | Initial build from card | 79b9675b-acb6-469d-b278-041979b34bdf |

