# QM5_11814_carter-m5-s1-macd1-stoch-ema5oc-m5 - Strategy Spec

**EA ID:** QM5_11814
**Slug:** carter-m5-s1-macd1-stoch-ema5oc-m5
**Source:** f4430cee-7efb-592e-bf0f-e469ef156b2d
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

The EA trades Thomas Carter's five-minute strategy on closed M5 bars. It buys when MACD(12,26,1) main value is above zero, Stochastic(5,3,3) %K is below 80, and EMA(5, close) is above EMA(5, open). It sells when MACD(12,26,1) is below zero, Stochastic %K is above 20, and EMA(5, close) is below EMA(5, open). Each trade uses a 20-pip stop and a 2R fixed take profit, and positions also exit when EMA(5, close) crosses back through EMA(5, open) against the position direction.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_macd_fast | 12 | 1-200 | Fast EMA period for MACD momentum. |
| strategy_macd_slow | 26 | 2-300 | Slow EMA period for MACD momentum. |
| strategy_macd_signal | 1 | 1-100 | MACD signal period; card uses 1 so main line is the momentum side. |
| strategy_stoch_k | 5 | 1-100 | Stochastic %K period. |
| strategy_stoch_d | 3 | 1-100 | Stochastic %D period. |
| strategy_stoch_slow | 3 | 1-100 | Stochastic slowing period. |
| strategy_stoch_long_max | 80.0 | 0-100 | Long filter: %K must be below this level. |
| strategy_stoch_short_min | 20.0 | 0-100 | Short filter: %K must be above this level. |
| strategy_ema_period | 5 | 1-200 | EMA period for open/close candle bias and exit cross. |
| strategy_sl_pips | 20 | 1-500 | Fixed stop-loss distance in pips. |
| strategy_tp_rr | 2.0 | 0-10 | Fixed take-profit multiple of stop distance; 2.0 equals 40 pips with the default stop. |
| strategy_allow_shorts | true | true/false | Enables the symmetric short entry from the card. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - the card's stated target symbol and confirmed available in `framework/registry/dwx_symbol_matrix.csv` for M5 tests.

**Explicitly NOT for:**
- Non-EURUSD symbols - the approved card's R3 row only passes EURUSD.DWX, so no broader portable basket is registered for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | Framework `QM_IsNewBar()` gate in `OnTick`; all strategy indicators read closed bars at shift 1. |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 200 |
| Typical hold time | Intraday M5 holds; exit by fixed 2R target, EMA-bias reversal, stop, or Friday close. |
| Expected drawdown profile | Frequent small fixed-risk losses with bounded 20-pip stops. |
| Regime preference | Short-term trend-following / momentum continuation. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** f4430cee-7efb-592e-bf0f-e469ef156b2d
**Source type:** book / local PDF
**Pointer:** Thomas Carter, `20 Forex Trading Strategies (5 Minute Time Frame)`, 2014, Strategy 1; local PDF `367145560-20-forex-trading-strategies-5-minute-time-frame-pdf.pdf`.
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11814_carter-m5-s1-macd1-stoch-ema5oc-m5.md`.

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
| v1 | 2026-06-23 | Initial build from card | fb115bd8-ef2c-4f1d-b487-5f4a8330e8ae |
