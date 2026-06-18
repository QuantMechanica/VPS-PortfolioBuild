# QM5_11888_lien-perfect-order-sma-stack - Strategy Spec

**EA ID:** QM5_11888
**Slug:** lien-perfect-order-sma-stack
**Source:** b840c053-5cd2-5e17-b25b-d495e73a33ab
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

This EA trades the D1 Perfect Order setup from Lien: SMA(10), SMA(20), SMA(50), SMA(100), and SMA(200) must be stacked in strict directional order on the last closed D1 bar. A long opens when the stack is SMA10 > SMA20 > SMA50 > SMA100 > SMA200 and that same bullish stack was not present during the prior 60 D1 bars; shorts mirror the rule. The initial stop is 25 pips beyond SMA50, there is no fixed take-profit, and open trades are trailed to SMA20. The strategy exit closes the position once the relevant Perfect Order stack breaks.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_sma_10 | 10 | >= 1 | Fast SMA in the Perfect Order stack. |
| strategy_sma_20 | 20 | >= 1 | Second SMA in the stack and the trailing-stop line. |
| strategy_sma_50 | 50 | >= 1 | Medium-term SMA used for initial stop placement. |
| strategy_sma_100 | 100 | >= 1 | Fourth SMA in the stack. |
| strategy_sma_200 | 200 | >= 1 | Slow SMA in the Perfect Order stack. |
| strategy_fresh_lookback_bars | 60 | >= 1 | Number of prior D1 bars that must not already show the same Perfect Order state. |
| strategy_sl_sma50_buffer_pips | 25 | >= 1 | Pip buffer below SMA50 for longs and above SMA50 for shorts. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - G7-major FX pair named in the card universe and available in the DWX matrix.
- GBPUSD.DWX - G7-major FX pair named in the card universe and available in the DWX matrix.
- USDJPY.DWX - G7-major FX pair named in the card universe and available in the DWX matrix.
- USDCAD.DWX - Major FX pair named in the card universe and available in the DWX matrix.
- USDCHF.DWX - Major FX pair named in the card universe and available in the DWX matrix.
- AUDUSD.DWX - Major FX pair named in the card universe and available in the DWX matrix.
- NZDUSD.DWX - Major FX pair named in the card universe and available in the DWX matrix.
- EURJPY.DWX - Liquid yen cross named in the card universe and available in the DWX matrix.
- GBPJPY.DWX - Liquid yen cross named in the card universe and available in the DWX matrix.
- AUDJPY.DWX - Liquid yen cross named in the card universe and available in the DWX matrix.

**Explicitly NOT for:**
- Non-FX `.DWX` symbols - the approved card is a Lien FX-major D1 Perfect Order setup.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 6 |
| Typical hold time | days to weeks, until Perfect Order break or SMA20 trailing stop |
| Expected drawdown profile | trend-following whipsaw risk when the SMA stack forms late in an extended move |
| Regime preference | trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b840c053-5cd2-5e17-b25b-d495e73a33ab
**Source type:** book
**Pointer:** Lien, K. (2011), Battle Tested Forex Trading Strategies, Perfect Order chapter slides 37-42; local PDF archive.
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11888_lien-perfect-order-sma-stack.md`

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
| v1 | 2026-06-18 | Initial build from card | 9951ede4-0a97-41bc-b834-9268c0b80de3 |
