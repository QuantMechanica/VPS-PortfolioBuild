# QM5_11819_carter-m5-s8-bb50-rsi3-stoch-reversal-m5 - Strategy Spec

**EA ID:** QM5_11819
**Slug:** `carter-m5-s8-bb50-rsi3-stoch-reversal-m5`
**Source:** `f4430cee-7efb-592e-bf0f-e469ef156b2d` (see `sources/20-forex-trading-strategies-5min-carter-367145560`)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

The EA trades the Carter Strategy 8 M5 mean-reversion setup. A long signal occurs when the last closed M5 bar closes below the lower BB(50,2) band while RSI(3) is below 20 and Stochastic(6,3,3) %K is below 20. A short signal occurs when the last closed M5 bar closes above the upper BB(50,2) band while RSI(3) is above 80 and Stochastic %K is above 80. Entries are market orders with a 2x ATR(14) stop and a take-profit at the BB(50) middle band.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_bb_period` | 50 | 10-200 | Bollinger Band lookback period. |
| `strategy_bb_deviation` | 2.0 | 1.0-4.0 | Bollinger Band deviation used for the entry band. |
| `strategy_rsi_period` | 3 | 2-30 | RSI period used for overbought and oversold confirmation. |
| `strategy_rsi_long_level` | 20.0 | 1.0-50.0 | Long signal requires RSI below this level. |
| `strategy_rsi_short_level` | 80.0 | 50.0-99.0 | Short signal requires RSI above this level. |
| `strategy_stoch_k` | 6 | 2-30 | Stochastic %K period. |
| `strategy_stoch_d` | 3 | 1-20 | Stochastic %D period. |
| `strategy_stoch_slow` | 3 | 1-20 | Stochastic slowing period. |
| `strategy_stoch_long_level` | 20.0 | 1.0-50.0 | Long signal requires Stochastic %K below this level. |
| `strategy_stoch_short_level` | 80.0 | 50.0-99.0 | Short signal requires Stochastic %K above this level. |
| `strategy_atr_period` | 14 | 2-100 | ATR lookback period for stop placement. |
| `strategy_sl_atr_mult` | 2.0 | 0.5-10.0 | Stop-loss distance as an ATR multiple. |
| `strategy_spread_cap_pips` | 5 | 1-100 | Blocks only genuinely wide positive spreads above this cap. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed major forex pair with M5 DWX data.
- `GBPUSD.DWX` - card-listed major forex pair with M5 DWX data.
- `USDJPY.DWX` - card-listed major forex pair with M5 DWX data.
- `USDCHF.DWX` - card-listed major forex pair with M5 DWX data.
- `AUDUSD.DWX` - card-listed major forex pair with M5 DWX data.

**Explicitly NOT for:**
- Non-DWX symbols - research and backtest naming must retain the `.DWX` suffix.
- Non-forex symbols - the approved card names a forex M5 basket only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `100` |
| Typical hold time | Not specified in card frontmatter; expected to hold until BB(50) midline, ATR SL, or Friday close. |
| Expected drawdown profile | Not specified in card frontmatter; ATR-based single-position losses. |
| Regime preference | Mean-reversion after Bollinger overextension. |
| Win rate target (qualitative) | Not specified in card frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `f4430cee-7efb-592e-bf0f-e469ef156b2d`
**Source type:** `book/pdf`
**Pointer:** `367145560-20-forex-trading-strategies-5-minute-time-frame-pdf.pdf`, Strategy 8
**R1-R4 verdict (Q00):** frontmatter marks all R1-R4 PASS and `g0_status: APPROVED`; see `artifacts/cards_approved/QM5_11819_carter-m5-s8-bb50-rsi3-stoch-reversal-m5.md`

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
| v1 | 2026-06-25 | Initial build from card | c69ad62e-7b33-43b7-8b8a-9caf61e912d4 |
