# QM5_11780_tc-tf-s18-ema613-macd-psar-h4 - Strategy Spec

**EA ID:** QM5_11780
**Slug:** tc-tf-s18-ema613-macd-psar-h4
**Source:** 3afb28d0-5993-527a-b039-5eef9c0e62e8
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

This EA trades H4 trend-following signals on GBP forex pairs. A long signal occurs when EMA(6) crosses above EMA(13), MACD(12,26,9) main is above zero, and PSAR(0.02,0.20) is below the closed-bar price. A short signal uses the opposite EMA cross, MACD below zero, and PSAR above price. Open positions close when EMA(6/13) reverses against the trade or PSAR flips to the opposite side; protective exits are 2 x ATR(14) stop loss and 4 x ATR(14) take profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ema_fast_period` | 6 | `>= 2` | Fast EMA period used for the crossover trigger. |
| `strategy_ema_slow_period` | 13 | `> strategy_ema_fast_period` | Slow EMA period used for the crossover trigger. |
| `strategy_macd_fast` | 12 | `>= 2` | MACD fast EMA period. |
| `strategy_macd_slow` | 26 | `> strategy_macd_fast` | MACD slow EMA period. |
| `strategy_macd_signal` | 9 | `>= 1` | MACD signal EMA period. |
| `strategy_psar_step` | 0.02 | `> 0` | Parabolic SAR acceleration step. |
| `strategy_psar_maximum` | 0.20 | `> strategy_psar_step` | Parabolic SAR maximum acceleration. |
| `strategy_atr_period` | 14 | `>= 2` | ATR period for stop and target sizing. |
| `strategy_atr_sl_mult` | 2.0 | `> 0` | Stop-loss distance in ATR multiples. |
| `strategy_atr_tp_mult` | 4.0 | `> 0` | Take-profit distance in ATR multiples. |
| `strategy_spread_pct_of_stop` | 15.0 | `>= 0` | Blocks entries only when modeled spread exceeds this percent of ATR stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- `GBPUSD.DWX` - card target pair with DWX H4 forex history.
- `GBPJPY.DWX` - card target pair with DWX H4 forex history.

**Explicitly NOT for:**
- Non-GBP `.DWX` symbols - the approved card names only GBPUSD and GBPJPY, so this build does not expand the basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 30 |
| Typical hold time | H4 trend-following holds; expected hours to days until reverse EMA state, PSAR flip, SL, TP, or Friday close |
| Expected drawdown profile | Trend-following drawdowns from whipsaw and failed continuation signals |
| Regime preference | trend-following |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 3afb28d0-5993-527a-b039-5eef9c0e62e8
**Source type:** book / PDF
**Pointer:** Thomas Carter, *Strategy #18*, in *20 Trend Following Systems*, 2014, pages 43-44.
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11780_tc-tf-s18-ema613-macd-psar-h4.md`

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
| v1 | 2026-06-25 | Initial build from card | 2fc5bb79-48ea-43ce-b49c-d3d4451d6bec |
