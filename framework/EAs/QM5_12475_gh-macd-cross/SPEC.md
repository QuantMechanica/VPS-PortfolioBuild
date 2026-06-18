# QM5_12475_gh-macd-cross - Strategy Spec

**EA ID:** QM5_12475
**Slug:** gh-macd-cross
**Source:** af7930c8-6c65-52d1-9c01-040490b5ad39 (see GitHub source citation below)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

The EA trades a long-only moving-average comparison on H1 close data. It computes a short SMA and a long SMA from close prices, with baseline periods 10 and 21. When the short SMA is greater than or equal to the long SMA and no position is open, it enters long with a market order. It exits the long when the short SMA falls below the long SMA; each entry also carries a protective stop at 2.0 times ATR(14) from entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_signal_tf | PERIOD_H1 | H1 baseline | Timeframe used for SMA and ATR reads. |
| strategy_short_period | 10 | 1 to less than strategy_long_period | Short close-price SMA period. |
| strategy_long_period | 21 | greater than strategy_short_period | Long close-price SMA period. |
| strategy_atr_period | 14 | 1 or higher | ATR period for protective stop placement. |
| strategy_atr_sl_mult | 2.0 | greater than 0 | ATR multiple for the protective stop. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed DWX forex pair for close-price SMA momentum.
- GBPUSD.DWX - card-listed DWX forex pair for close-price SMA momentum.
- XAUUSD.DWX - card-listed DWX metal symbol for close-price SMA momentum.
- NDX.DWX - card-listed DWX index symbol for close-price SMA momentum.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - not available for the DWX backtest baseline.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework `OnTick` gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 35 |
| Typical hold time | Card does not provide a numeric hold-time estimate; hold lasts until `SMA(10) < SMA(21)` or ATR stop. |
| Expected drawdown profile | Bounded per-trade downside through 2.0 x ATR(14) protective stop. |
| Regime preference | Momentum / moving-average trend regime. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** af7930c8-6c65-52d1-9c01-040490b5ad39
**Source type:** GitHub repository script
**Pointer:** https://github.com/je-suis-tm/quant-trading/blob/master/MACD%20Oscillator%20backtest.py
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_12475_gh-macd-cross.md`

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
| v1 | 2026-06-18 | Initial build from card | 454982c6-90b9-4eea-9280-5bb259a14b6f |
