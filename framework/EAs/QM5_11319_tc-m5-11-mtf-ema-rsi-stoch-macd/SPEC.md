# QM5_11319_tc-m5-11-mtf-ema-rsi-stoch-macd - Strategy Spec

**EA ID:** QM5_11319
**Slug:** tc-m5-11-mtf-ema-rsi-stoch-macd
**Source:** e78a9f1f-4e6a-563c-a080-915133d6ed28 (see local PDF citation in the approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-26

---

## 1. Strategy Logic

The EA trades the Thomas Carter 5-minute System #11 as a multi-timeframe momentum entry. A long setup requires the last closed H4 EMA(5) to be above H4 EMA(10), then a closed-bar execution-timeframe EMA(5) cross above EMA(10), RSI(14) above 50, rising Stochastic %K below 80, and MACD histogram turning or improving from negative territory. A short setup mirrors those rules with the H4 EMA(5) below EMA(10), an execution-timeframe bearish EMA cross, RSI below 50, falling Stochastic %K above 20, and bearish or weakening positive MACD histogram. The EA has no indicator exit; positions use fixed 25-pip stop loss and 25-pip profit target plus framework exits.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_h4_ema_fast` | 5 | `> 0` | Fast EMA period for the H4 trend-bias filter. |
| `strategy_h4_ema_slow` | 10 | `> 0` | Slow EMA period for the H4 trend-bias filter. |
| `strategy_m5_ema_fast` | 5 | `> 0` | Fast EMA period for the execution-timeframe crossover trigger. |
| `strategy_m5_ema_slow` | 10 | `> 0` | Slow EMA period for the execution-timeframe crossover trigger. |
| `strategy_rsi_period` | 14 | `> 0` | RSI lookback for the momentum confirmation. |
| `strategy_rsi_midline` | 50.0 | `0-100` | RSI threshold: longs above, shorts below. |
| `strategy_stoch_k` | 5 | `> 0` | Stochastic %K period. |
| `strategy_stoch_d` | 3 | `> 0` | Stochastic %D period. |
| `strategy_stoch_slowing` | 3 | `> 0` | Stochastic slowing period. |
| `strategy_stoch_long_cap` | 80.0 | `0-100` | Longs require rising %K below this cap. |
| `strategy_stoch_short_floor` | 20.0 | `0-100` | Shorts require falling %K above this floor. |
| `strategy_macd_fast` | 12 | `> 0` | MACD fast EMA period. |
| `strategy_macd_slow` | 26 | `> 0` | MACD slow EMA period. |
| `strategy_macd_signal` | 9 | `> 0` | MACD signal period. |
| `strategy_stop_pips` | 25 | `> 0` | Fixed stop loss in pips. |
| `strategy_take_pips` | 25 | `> 0` | Fixed profit target in pips. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-approved DWX FX baseline symbol for liquid major-pair testing.
- `GBPUSD.DWX` - card-approved DWX FX baseline symbol for liquid major-pair testing.
- `USDJPY.DWX` - card-approved DWX FX baseline symbol for liquid major-pair testing.

**Explicitly NOT for:**
- Non-FX `.DWX` index and commodity symbols - the card source states broad FX use and the approved P2 basket is FX-only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | H4 EMA(5/10) trend bias from the last fully closed H4 bar |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the framework skeleton entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 90 |
| Typical hold time | Intraday scalp; minutes to a few hours, bounded by fixed SL/TP and Friday close |
| Expected drawdown profile | Frequent small fixed-risk losses when the momentum stack fails to follow through |
| Regime preference | Trend-following intraday momentum with higher-timeframe directional bias |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** e78a9f1f-4e6a-563c-a080-915133d6ed28
**Source type:** book / local PDF
**Pointer:** `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\367145560-20-forex-trading-strategies-5-minute-time-frame-pdf.pdf`, Thomas Carter, 20 Forex Trading Strategies (5 Minute Time Frame), System #11, pages 28-29
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11319_tc-m5-11-mtf-ema-rsi-stoch-macd.md`

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
| v1 | 2026-06-26 | Initial build from card | 2128020b-f95d-406a-b64c-314929065b96 |
