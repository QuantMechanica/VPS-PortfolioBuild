# QM5_10278_whc-roc-stoch - Strategy Spec

**EA ID:** QM5_10278
**Slug:** whc-roc-stoch
**Source:** 1b906e79-c619-5a61-90db-ee19ac95a19f (see `sources/github-topic-algorithmic-trading`)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

The EA trades long-only on D1 bars. It enters when the 12-period close momentum is positive, implemented as `QM_Momentum(12) > 100`, which is equivalent to ROC(12) > 0, and the Stochastic %K value from Stochastic(14,3,3) is below 20. It closes the long when the 12-period momentum turns negative and Stochastic %K is above 80. The source has no explicit stop, so the EA attaches the card-required catastrophic stop at 2.0 times ATR(14).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_D1` | `PERIOD_M1`-`PERIOD_MN1` | Timeframe used for ROC/Momentum and Stochastic reads. |
| `strategy_roc_period` | `12` | `1`-`252` | Lookback period for the ROC sign test, implemented through `QM_Momentum`. |
| `strategy_stoch_k_period` | `14` | `1`-`100` | Stochastic %K lookback period. |
| `strategy_stoch_d_period` | `3` | `1`-`20` | Stochastic %D period used by the framework Stochastic reader. |
| `strategy_stoch_slowing` | `3` | `1`-`20` | Stochastic %K smoothing period. |
| `strategy_entry_roc_level` | `0.0` | `-100.0`-`100.0` | Long entry requires ROC above this level. |
| `strategy_entry_stoch_max` | `20.0` | `0.0`-`100.0` | Long entry requires Stochastic %K below this level. |
| `strategy_exit_roc_level` | `0.0` | `-100.0`-`100.0` | Exit requires ROC below this level. |
| `strategy_exit_stoch_min` | `80.0` | `0.0`-`100.0` | Exit requires Stochastic %K above this level. |
| `strategy_atr_period` | `14` | `1`-`100` | ATR period for the catastrophic stop. |
| `strategy_atr_sl_mult` | `2.0` | `0.1`-`10.0` | ATR multiple for the catastrophic stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - Nasdaq 100 index exposure fits the card's preferred index momentum/pullback behavior.
- `WS30.DWX` - Dow 30 index exposure fits the card's preferred index momentum/pullback behavior.
- `SP500.DWX` - S&P 500 custom symbol fits the card's preferred index momentum/pullback behavior for backtests.
- `XAUUSD.DWX` - Gold is the card's named metal target and supports daily OHLC momentum logic.
- `EURUSD.DWX` - Major FX pair available in the DWX matrix for the card's major-FX extension.
- `GBPUSD.DWX` - Major FX pair available in the DWX matrix for the card's major-FX extension.
- `USDJPY.DWX` - Major FX pair available in the DWX matrix for the card's major-FX extension.
- `AUDUSD.DWX` - Major FX pair available in the DWX matrix for the card's major-FX extension.
- `USDCAD.DWX` - Major FX pair available in the DWX matrix for the card's major-FX extension.
- `USDCHF.DWX` - Major FX pair available in the DWX matrix for the card's major-FX extension.
- `NZDUSD.DWX` - Major FX pair available in the DWX matrix for the card's major-FX extension.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - they are not broker-backed for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `10` |
| Trade frequency | low; approximately 10 entries per year per symbol |
| Typical hold time | daily swing holds, expected to last days to weeks |
| Expected drawdown profile | pullback entries can cluster during momentum reversals; drawdown bounded by 2.0 x ATR(14) stop |
| Regime preference | momentum with mean-reversion pullback confirmation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `1b906e79-c619-5a61-90db-ee19ac95a19f`
**Source type:** GitHub repository
**Pointer:** `https://github.com/whchien/ai-trader/blob/main/ai_trader/backtesting/strategies/classic/roc.py`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10278_whc-roc-stoch.md`

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
| v1 | 2026-06-12 | Initial build from card | 58f93daf-60b4-4069-a3c2-00a9f2832ad9 |
