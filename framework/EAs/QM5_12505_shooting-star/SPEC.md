# QM5_12505_shooting-star - Strategy Spec

**EA ID:** QM5_12505
**Slug:** shooting-star
**Source:** 46758070-d6b1-52ef-a3ee-ffcbffb7bb54
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades only short after a confirmed shooting-star candle on completed bars. A candidate candle must be bearish, have a small body relative to the 60-bar mean body, a small lower shadow, an upper shadow at least twice the body, and appear after two rising closes. The next completed bar must stay below the shooting-star high and close no higher than the shooting-star close; the EA then enters short at market on the following bar. Exits are a symmetric 5 percent take-profit/stop threshold, with the stop tightened to 3.0 x ATR(20) when that is closer, or a 7-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| lower_bound | 0.2 | 0.1-0.3 | Maximum lower shadow as a fraction of the candle body. |
| body_size | 0.5 | 0.4-0.8 | Maximum body size as a fraction of the warmup mean body. |
| stop_threshold_pct | 5.0 | 2.0-5.0 | Symmetric percentage threshold for profit target and source stop. |
| holding_period_bars | 7 | 3-10 | Maximum holding period in chart bars. |
| warmup_bars | 60 | 60 fixed | Bars used for mean body warmup. |
| atr_period | 20 | 20 fixed | ATR period used for the V5 hard-stop overlay. |
| atr_stop_mult | 3.0 | 3.0 fixed | ATR multiple used when tighter than the percentage stop. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-targeted liquid major FX pair with native DWX OHLC data.
- GBPUSD.DWX - card-targeted liquid major FX pair with native DWX OHLC data.
- USDJPY.DWX - card-targeted liquid major FX pair with native DWX OHLC data.
- XAUUSD.DWX - card-targeted gold CFD with native DWX OHLC data.
- NDX.DWX - card-targeted US index CFD with native DWX OHLC data.
- WS30.DWX - card-targeted US index CFD with native DWX OHLC data.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - not registered because the broker/test matrix has no canonical DWX data for them.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 8 |
| Typical hold time | up to 7 D1 bars |
| Expected drawdown profile | medium risk; reversal entries can cluster during trending extensions |
| Regime preference | short mean-reversion after an extended upward candle pattern |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 46758070-d6b1-52ef-a3ee-ffcbffb7bb54
**Source type:** public GitHub strategy script
**Pointer:** je-suis-tm quant-trading `Shooting Star backtest.py`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12505_shooting-star.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-11 | Initial build from card | 9d62d561-a83f-48bc-8646-07d8070dc65b |
