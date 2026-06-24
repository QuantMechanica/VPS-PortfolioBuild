# QM5_11729_tc-m5-s17-ema-macd-psar-stddev - Strategy Spec

**EA ID:** QM5_11729
**Slug:** tc-m5-s17-ema-macd-psar-stddev
**Source:** 40a4454c-64ff-5015-8538-9f7b32abc0e9 (see `strategy-seeds/sources/40a4454c-64ff-5015-8538-9f7b32abc0e9/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-24

---

## 1. Strategy Logic

The EA trades the M5 Thomas Carter Strategy #17 six-indicator confluence. A long setup requires EMA(3) above EMA(8), Parabolic SAR below the last closed price, MACD(12,26,9) main line above zero, Stochastic(10,15,15) %K above %D, and StdDev(20) at or above the card's medium threshold for the symbol family. A short setup mirrors those rules. The stop is based on the recent M5 swing high or low with the card's 8-12 pip convention, and the hard take profit is 2R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_signal_tf | PERIOD_M5 | M5 intended | Signal timeframe from the card. |
| strategy_ema_fast | 3 | >0 and < strategy_ema_slow | Fast EMA period. |
| strategy_ema_slow | 8 | > strategy_ema_fast | Slow EMA period. |
| strategy_macd_fast | 12 | >0 and < strategy_macd_slow | MACD fast EMA period. |
| strategy_macd_slow | 26 | > strategy_macd_fast | MACD slow EMA period. |
| strategy_macd_signal | 9 | >0 | MACD signal period. |
| strategy_stoch_k | 10 | >0 | Stochastic %K period. |
| strategy_stoch_d | 15 | >0 | Stochastic %D period. |
| strategy_stoch_slowing | 15 | >0 | Stochastic slowing period. |
| strategy_psar_step | 0.02 | >0 and < strategy_psar_maximum | Parabolic SAR acceleration step. |
| strategy_psar_maximum | 0.20 | > strategy_psar_step | Parabolic SAR maximum acceleration. |
| strategy_stddev_period | 20 | >0 | Standard deviation lookback on close. |
| strategy_stddev_override | 0.0 | >=0 | Optional explicit StdDev threshold; 0 uses card symbol-family thresholds. |
| strategy_swing_lookback | 5 | >0 | Closed bars scanned for recent swing high or low. |
| strategy_min_sl_pips | 8 | >0 | Minimum stop distance from the card's 8-12 pip convention. |
| strategy_max_sl_pips | 12 | >= strategy_min_sl_pips | Maximum stop distance from the card's 8-12 pip convention. |
| strategy_tp_rr | 2.0 | >0 | Hard take profit as R multiple of the stop. |
| strategy_max_spread_pips | 3.0 | >=0 | Maximum real spread in pips; zero modeled spread passes. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card target symbol; major forex pair with M5 DWX data.
- GBPUSD.DWX - Card target symbol; major forex pair with M5 DWX data.
- USDJPY.DWX - Card target symbol; JPY threshold branch applies.
- USDCHF.DWX - Card target symbol; major forex pair with M5 DWX data.
- AUDUSD.DWX - Card target symbol; AUD/NZD threshold branch applies.
- NZDUSD.DWX - Card target symbol; AUD/NZD threshold branch applies.

**Explicitly NOT for:**
- Index and commodity .DWX symbols - The card targets forex M5 pairs and gives forex-specific StdDev thresholds.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) via framework entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 150 |
| Expected trade frequency | Not specified in card frontmatter; inferred intraday M5 scalp cadence from card body. |
| Typical hold time | Not specified in card frontmatter; exits on EMA reversal, SAR flip, SL, or 2R TP. |
| Expected drawdown profile | Not specified in card frontmatter; fixed-risk intraday trend-confluence profile. |
| Regime preference | Trend-following with volatility filter; concepts include trend-following and volatility-filter. |
| Win rate target (qualitative) | Not specified in card frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 40a4454c-64ff-5015-8538-9f7b32abc0e9
**Source type:** book/pdf
**Pointer:** `367145560-20-forex-trading-strategies-5-minute-time-frame-pdf.pdf`, Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)", Strategy #17, 2013.
**R1-R4 verdict (Q00):** all R1-R4 PASS per card frontmatter and `artifacts/cards_approved/QM5_11729_tc-m5-s17-ema-macd-psar-stddev.md`.

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
| v1 | 2026-06-24 | Initial build from card | 8f1cddbc-ee4b-417c-b045-a47517c2db98 |
