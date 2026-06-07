# QM5_11087_laguerre-cross - Strategy Spec

**EA ID:** QM5_11087
**Slug:** laguerre-cross
**Source:** 0693c604-4f96-56ef-be79-15efe9f48b86
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA computes the EarnForex Laguerre RSI from completed H4 closes using Gamma 0.70. It opens long when the oscillator crosses upward through 0.20 after being at or below 0.20 on the prior completed bar. It opens short when the oscillator crosses downward through 0.80 after being at or above 0.80 on the prior completed bar. Open positions close on the opposite Laguerre cross or after 20 H4 bars; each entry uses a 2.5 ATR(14) catastrophic stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_gamma | 0.70 | 0.00-0.99 | Laguerre smoothing factor from the source indicator. |
| strategy_lower_level | 0.20 | 0.00-1.00 | Lower level for completed-bar long crosses and short exits. |
| strategy_upper_level | 0.80 | 0.00-1.00 | Upper level for completed-bar short crosses and long exits. |
| strategy_atr_period | 14 | 1-200 | ATR period used for the catastrophic stop. |
| strategy_atr_sl_mult | 2.50 | 0.10-20.00 | ATR multiple used to place the catastrophic stop. |
| strategy_max_hold_bars | 20 | 1-200 | Maximum holding period measured in H4 bars. |
| strategy_laguerre_warmup | 160 | 8-1000 | Number of completed closes used to warm up the Laguerre recursion. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card primary basket forex major with DWX data available.
- GBPUSD.DWX - Card primary basket forex major with DWX data available.
- USDJPY.DWX - Card primary basket forex major with DWX data available.
- XAUUSD.DWX - Card primary basket metal CFD with DWX data available.

**Explicitly NOT for:**
- Non-DWX symbols - Build and backtest artifacts require canonical `.DWX` symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 24 |
| Typical hold time | Up to 20 H4 bars, with earlier opposite-cross exits |
| Expected drawdown profile | Mean-reversion oscillator entries with ATR catastrophic loss containment |
| Regime preference | Mean-reversion swing regimes |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 0693c604-4f96-56ef-be79-15efe9f48b86
**Source type:** public indicator repository
**Pointer:** EarnForex Laguerre GitHub repository and MQL5 source, https://github.com/EarnForex/Laguerre
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11087_laguerre-cross.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV to mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-07 | Initial build from card | 6ab53482-caf3-4a51-b698-68093d832fc5 |
