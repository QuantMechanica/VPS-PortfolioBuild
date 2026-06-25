# QM5_11827_carter-m5-s17-ema38-macd-stoch-psar-sd-m5 - Strategy Spec

**EA ID:** QM5_11827
**Slug:** carter-m5-s17-ema38-macd-stoch-psar-sd-m5
**Source:** f4430cee-7efb-592e-bf0f-e469ef156b2d (see approved card source citation)
**Author of this spec:** Codex
**Last revised:** 2026-06-26

---

## 1. Strategy Logic

This EA trades the Strategy 17 M5 forex setup from the Carter source. A long entry is allowed when EMA(3) crosses above EMA(8), MACD(12,26,9) histogram is positive, Stochastic(10,15,15) %K is above %D but below 80, PSAR is below price, and StdDev(20) is above its prior 20-bar average. A short entry mirrors the rule with EMA(3) crossing below EMA(8), negative MACD histogram, Stochastic %K below %D but above 20, PSAR above price, and the same expanding-volatility filter. Initial exits are a 2x ATR(14) stop and 4x ATR(14) take profit, with PSAR trailing applied after the position is profitable.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_fast_ema_period | 3 | >=1 | Fast EMA period for the primary cross trigger. |
| strategy_slow_ema_period | 8 | > fast EMA | Slow EMA period for the primary cross trigger. |
| strategy_macd_fast | 12 | >=1 | MACD fast EMA period. |
| strategy_macd_slow | 26 | > fast | MACD slow EMA period. |
| strategy_macd_signal | 9 | >=1 | MACD signal period. |
| strategy_stoch_k | 10 | >=1 | Stochastic %K period. |
| strategy_stoch_d | 15 | >=1 | Stochastic %D period. |
| strategy_stoch_slowing | 15 | >=1 | Stochastic slowing period. |
| strategy_stoch_long_ceiling | 80.0 | 0-100 | Long entries require %K below this level. |
| strategy_stoch_short_floor | 20.0 | 0-100 | Short entries require %K above this level. |
| strategy_psar_step | 0.02 | >0 | PSAR acceleration step. |
| strategy_psar_maximum | 0.20 | > step | PSAR maximum acceleration. |
| strategy_stddev_period | 20 | >=1 | Standard deviation period. |
| strategy_stddev_avg_bars | 20 | >=1 | Number of prior StdDev values used as the volatility threshold. |
| strategy_atr_period | 14 | >=1 | ATR period for stop and target placement. |
| strategy_atr_sl_mult | 2.0 | >0 | Initial stop distance in ATR multiples. |
| strategy_atr_tp_mult | 4.0 | >0 | Initial target distance in ATR multiples. |
| strategy_psar_trail_enabled | true | true/false | Enables PSAR stop trailing after a position is profitable. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card target forex major with M5 DWX data available.
- GBPUSD.DWX - Card target forex major with M5 DWX data available.
- USDJPY.DWX - Card target forex major with M5 DWX data available.
- USDCHF.DWX - Card target forex major with M5 DWX data available.
- AUDUSD.DWX - Card target forex major with M5 DWX data available.

**Explicitly NOT for:**
- Non-DWX symbols - V5 research and backtest artifacts must use canonical `.DWX` symbols.
- Non-forex symbols - The approved card targets only the listed forex majors.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 100 |
| Expected trade frequency | Not specified in card frontmatter; M5 signal stack implies intraday opportunities. |
| Typical hold time | Not specified in card frontmatter; exits are ATR target/stop plus PSAR trailing. |
| Expected drawdown profile | Not specified in card frontmatter; per-trade risk follows V5 fixed/percent risk convention. |
| Regime preference | Volatility-expansion momentum after EMA cross confirmation. |
| Win rate target (qualitative) | Not specified in card frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** f4430cee-7efb-592e-bf0f-e469ef156b2d
**Source type:** local PDF / retail strategy source
**Pointer:** Thomas Carter, `367145560-20-forex-trading-strategies-5-minute-time-frame-pdf.pdf`, Strategy 17
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11827_carter-m5-s17-ema38-macd-stoch-psar-sd-m5.md`

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
| v1 | 2026-06-26 | Initial build from card | 889f6a7c-63df-4af4-8f75-c7e5eec7b637 |
