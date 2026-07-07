# QM5_11806_carter-h1-s18-ema510-stoch-rsi-h1 - Strategy Spec

**EA ID:** QM5_11806
**Slug:** carter-h1-s18-ema510-stoch-rsi-h1
**Source:** 529382f8-fbd1-5c17-ba62-fbe56990ebcd (see `sources/thomas-carter-20-h1-trading-strategies-376863900`)
**Author of this spec:** Codex
**Last revised:** 2026-07-07

---

## 1. Strategy Logic

This EA trades the H1 close after EMA(5) crosses EMA(10). A long entry requires the EMA(5) to cross above EMA(10), Stochastic(14,3,3) %K to be above %D while %K is below 80, and RSI(14) to be above 50. A short entry requires the opposite EMA cross, Stochastic %K below %D while %K is above 20, and RSI(14) below 50. Each trade uses a 2 ATR(14) stop, a 4 ATR(14) target, and exits early if the EMA cross reverses against the open position.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_ema_fast_period | 5 | 1-100 | Fast EMA period used for the cross trigger. |
| strategy_ema_slow_period | 10 | 2-200 | Slow EMA period used for the cross trigger. |
| strategy_stoch_k_period | 14 | 1-100 | Stochastic %K period. |
| strategy_stoch_d_period | 3 | 1-50 | Stochastic %D period. |
| strategy_stoch_slowing | 3 | 1-50 | Stochastic slowing value. |
| strategy_stoch_overbought | 80.0 | 0-100 | Long entries require %K below this level. |
| strategy_stoch_oversold | 20.0 | 0-100 | Short entries require %K above this level. |
| strategy_rsi_period | 14 | 1-100 | RSI period. |
| strategy_rsi_midline | 50.0 | 0-100 | RSI long/short confirmation threshold. |
| strategy_atr_period | 14 | 1-100 | ATR period for stop and target sizing. |
| strategy_atr_sl_mult | 2.0 | >0 | Stop distance in ATR multiples. |
| strategy_atr_tp_mult | 4.0 | >0 | Target distance in ATR multiples. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - listed in the Carter card body and present in the DWX matrix for H1 FX testing.
- GBPUSD.DWX - listed in the Carter card body and present in the DWX matrix for H1 FX testing.
- AUDUSD.DWX - listed in the Carter card body/R3 reasoning and present in the DWX matrix for H1 FX testing.
- USDJPY.DWX - listed in the Carter card body/R3 reasoning and present in the DWX matrix for H1 FX testing.

**Explicitly NOT for:**
- Non-DWX symbols - build and backtest artifacts must use the `.DWX` research suffix.
- Non-H1 charts - the card defines the strategy on the 1 hour time frame.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework `OnTick` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 100 |
| Typical hold time | not specified in card |
| Expected drawdown profile | not specified in card |
| Regime preference | trend-following |
| Win rate target (qualitative) | not specified in card |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 529382f8-fbd1-5c17-ba62-fbe56990ebcd
**Source type:** book/PDF
**Pointer:** `376863900-20-Forex-Trading-Strategies-Collection.pdf`, Strategy S18
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11806_carter-h1-s18-ema510-stoch-rsi-h1.md`

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
|---|---|---|
| v1 | 2026-07-07 | Initial build from card | 772aa594-6c5a-413a-8144-de38b6272362 |
