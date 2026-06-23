# QM5_11724_tc-m5-s11-mtf-h4-ema-macd-stoch - Strategy Spec

**EA ID:** QM5_11724
**Slug:** `tc-m5-s11-mtf-h4-ema-macd-stoch`
**Source:** `40a4454c-64ff-5015-8538-9f7b32abc0e9` (see `sources/tc-20-forex-strategies-m5-367145560`)
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

The EA trades the M5 chart only when the same symbol is aligned with the H4 trend. A long entry requires H4 EMA(5) above EMA(10), an M5 EMA(5) cross above EMA(10), RSI(14) above 50, Stochastic K rising and below 80, and MACD(12,26,9) histogram rising per the card formula. A short entry mirrors those rules with H4 EMA(5) below EMA(10), an M5 bearish EMA cross, RSI below 50, Stochastic K falling and above 20, and a falling MACD histogram. Exits are the fixed 25-pip stop loss or fixed 25-pip take profit, plus framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_h4_fast_ema` | 5 | `> 0` | Fast H4 EMA trend period. |
| `strategy_h4_slow_ema` | 10 | `> 0` | Slow H4 EMA trend period. |
| `strategy_m5_fast_ema` | 5 | `> 0` | Fast M5 EMA cross period. |
| `strategy_m5_slow_ema` | 10 | `> 0` | Slow M5 EMA cross period. |
| `strategy_rsi_period` | 14 | `> 0` | M5 RSI period. |
| `strategy_rsi_midline` | 50.0 | `0-100` | RSI long/short split level. |
| `strategy_stoch_k` | 5 | `> 0` | Stochastic K period. |
| `strategy_stoch_d` | 3 | `> 0` | Stochastic D period. |
| `strategy_stoch_slowing` | 3 | `> 0` | Stochastic slowing period. |
| `strategy_stoch_overbought` | 80.0 | `0-100` | Long entries require K below this level. |
| `strategy_stoch_oversold` | 20.0 | `0-100` | Short entries require K above this level. |
| `strategy_macd_fast` | 12 | `> 0` | MACD fast EMA period. |
| `strategy_macd_slow` | 26 | `> 0` | MACD slow EMA period. |
| `strategy_macd_signal` | 9 | `> 0` | MACD signal EMA period. |
| `strategy_sl_pips` | 25 | `> 0` | Fixed stop loss in pips. |
| `strategy_tp_pips` | 25 | `> 0` | Fixed take profit in pips. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card target symbol; standard DWX major FX pair with M5 and H4 data.
- `GBPUSD.DWX` - Card target symbol; standard DWX major FX pair with M5 and H4 data.
- `USDJPY.DWX` - Card target symbol; standard DWX major FX pair with M5 and H4 data.
- `AUDUSD.DWX` - Card target symbol; standard DWX major FX pair with M5 and H4 data.

**Explicitly NOT for:**
- Non-FX `.DWX` symbols - The approved card names only major FX pairs and uses 25-pip FX stops.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `PERIOD_H4` EMA(5/10) trend filter on the same symbol |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `150` |
| Typical hold time | Not specified in card frontmatter; expected intraday minutes to hours from M5 entry and 25-pip SL/TP. |
| Expected drawdown profile | Not specified in card frontmatter; fixed 1:1 SL/TP confluence strategy. |
| Regime preference | Not specified in card frontmatter; trend-aligned M5 momentum continuation. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `40a4454c-64ff-5015-8538-9f7b32abc0e9`
**Source type:** book
**Pointer:** `Thomas Carter, '20 Forex Trading Strategies (5 Minute Time Frame)', self-published (367145560), 2014. Strategy #11.`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11724_tc-m5-s11-mtf-h4-ema-macd-stoch.md`

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
| v1 | 2026-06-23 | Initial build from card | 5edc2c23-a34d-4087-b4b2-a6c2b910de14 |
