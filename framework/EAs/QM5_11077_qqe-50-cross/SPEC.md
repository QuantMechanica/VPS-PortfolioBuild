# QM5_11077_qqe-50-cross - Strategy Spec

**EA ID:** QM5_11077
**Slug:** `qqe-50-cross`
**Source:** `0693c604-4f96-56ef-be79-15efe9f48b86` (see `strategy-seeds/sources/0693c604-4f96-56ef-be79-15efe9f48b86/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA computes the EarnForex QQE line from RSI(14), smooths it with smoothing factor 5, and builds the QQE slow trailing line from the smoothed RSI volatility. A long setup starts when the QQE RSI MA line crosses above the slow trailing line, then a long entry fires when that QQE line crosses above level 50 on a closed H4 bar. A short setup starts when the QQE RSI MA line crosses below the slow trailing line, then a short entry fires when it crosses below level 50. Long positions close when the QQE line crosses below the slow trailing line or below level 50; shorts close on the inverse conditions.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_rsi_period` | 14 | 2+ | RSI period used by the QQE calculation. |
| `strategy_smoothing_factor` | 5 | 1+ | EMA smoothing factor applied to RSI. |
| `strategy_alert_level` | 50.0 | >0 | QQE level-cross threshold used for entries and exits. |
| `strategy_qqe_factor` | 4.236 | >0 | Multiplier for the smoothed RSI volatility trailing line. |
| `strategy_atr_period` | 14 | 1+ | ATR period used for the hard stop. |
| `strategy_atr_sl_mult` | 2.5 | >0 | ATR multiple for stop-loss distance. |
| `strategy_qqe_lookback` | 240 | 40+ | Closed-bar warmup depth for the QQE recursive trailing line. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card-listed DWX forex major with native OHLC data for RSI-derived QQE.
- `GBPUSD.DWX` - Card-listed DWX forex major with native OHLC data for RSI-derived QQE.
- `USDJPY.DWX` - Card-listed DWX forex major with native OHLC data for RSI-derived QQE.
- `XAUUSD.DWX` - Card-listed DWX gold symbol with native OHLC data for RSI-derived QQE.

**Explicitly NOT for:**
- Symbols outside the card R3 basket - not registered for this EA and not part of the approved portable baseline.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default framework gate) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `45` |
| Typical hold time | Not specified in card frontmatter; exits on opposite QQE/level cross, expected to hold several H4 bars to multiple days. |
| Expected drawdown profile | ATR(14) * 2.5 hard stop limits adverse moves; no averaging or martingale. |
| Regime preference | Momentum / oscillator-cross regime. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `0693c604-4f96-56ef-be79-15efe9f48b86`
**Source type:** GitHub repository / public indicator source
**Pointer:** `https://github.com/EarnForex/QQE` and `artifacts/cards_approved/QM5_11077_qqe-50-cross.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11077_qqe-50-cross.md`

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
| v1 | 2026-06-07 | Initial build from card | d81e949c-6895-48e3-be54-d02e9758acbd |
