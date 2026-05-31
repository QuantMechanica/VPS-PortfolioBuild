# QM5_10586_mql5-cycleper - Strategy Spec

**EA ID:** QM5_10586
**Slug:** mql5-cycleper
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Author of this spec:** Codex
**Last revised:** 2026-05-29

---

## 1. Strategy Logic

The EA computes the CyclePeriod oscillator from closed OHLC bars on the chart timeframe. It opens long when the latest closed CyclePeriod value turns upward after the prior value was falling, and opens short when the latest closed value turns downward after the prior value was rising. An opposite CyclePeriod reversal closes an existing position and may reverse the position. Each entry uses an ATR(14) hard stop at 2.0 times ATR and a 1.5R target.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_cycle_alpha | 0.07 | 0.0-1.0 exclusive | CyclePeriod smoothing coefficient from the source indicator. |
| strategy_cycle_calc_bars | 160 | 40+ | Number of closed bars used to warm up and compute the CyclePeriod series. |
| strategy_atr_period | 14 | 1+ | ATR period used for the hard stop. |
| strategy_atr_sl_mult | 2.0 | >0 | ATR multiple for the stop loss. |
| strategy_rr_target | 1.5 | >0 | Take-profit distance in R multiples from the ATR stop. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- USDJPY.DWX - source test used USDJPY H4 and the logic is OHLC-based.
- EURUSD.DWX - liquid FX major with DWX history and portable closed-bar oscillator behaviour.
- GBPJPY.DWX - liquid FX cross with DWX history and enough volatility for H4 cycle reversals.
- XAUUSD.DWX - liquid metal with DWX history and cycle-like swings suited to oscillator direction changes.

**Explicitly NOT for:**
- Non-DWX symbols - the V5 pipeline requires `.DWX` research and backtest symbols.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no broker or custom-symbol data source is registered.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through framework `OnTick` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 40 |
| Typical hold time | several H4 bars to several days |
| Expected drawdown profile | moderate oscillator reversal whipsaw risk in choppy markets |
| Regime preference | cyclical reversal / mean-revert swings |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** MQL5 CodeBase
**Pointer:** https://www.mql5.com/en/code/13538
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10586_mql5-cycleper.md`

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
| v1 | 2026-05-29 | Initial build from card | ba5a4e33-055f-43d4-a931-7437d8405710 |
