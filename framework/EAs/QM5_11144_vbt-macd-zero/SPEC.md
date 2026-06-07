# QM5_11144_vbt-macd-zero - Strategy Spec

**EA ID:** QM5_11144
**Slug:** `vbt-macd-zero`
**Source:** `3f3833d9-8676-52e4-a822-2c5fc87bbe20` (see `strategy-seeds/sources/3f3833d9-8676-52e4-a822-2c5fc87bbe20/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

This EA trades a daily MACD momentum rule on the close of each completed D1 bar. It enters long when MACD is above zero and above its signal line after the prior completed bar did not satisfy that same long condition. It enters short when MACD is below zero and below its signal line after the prior completed bar did not satisfy that same short condition. Long positions close when MACD falls below zero or below signal; short positions close when MACD rises above zero or above signal. A fixed safety stop is placed at 2.5 times ATR(14) from entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_macd_fast` | 12 | 2-50 | Fast EMA window used by MACD. |
| `strategy_macd_slow` | 26 | 3-100 | Slow EMA window used by MACD; must exceed the fast window. |
| `strategy_macd_signal` | 9 | 2-20 | Signal EMA window used by MACD. |
| `strategy_atr_period` | 14 | 2-100 | ATR lookback for the fixed safety stop. |
| `strategy_atr_sl_mult` | 2.5 | 0.5-10.0 | ATR multiple used to place the entry stop loss. |
| `strategy_exit_on_either` | true | true/false | True closes on either zero-line breach or signal-line breach; false requires both. |
| `strategy_allow_long` | true | true/false | Enables the long side of the symmetric baseline. |
| `strategy_allow_short` | true | true/false | Enables the short side of the symmetric DWX port. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-documented here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - R3-approved major FX symbol with daily close data suitable for MACD and ATR.
- `GBPUSD.DWX` - R3-approved major FX symbol with daily close data suitable for MACD and ATR.
- `USDJPY.DWX` - R3-approved major FX symbol with daily close data suitable for MACD and ATR.
- `XAUUSD.DWX` - R3-approved metal symbol with daily close data suitable for MACD and ATR.
- `NDX.DWX` - R3-approved index symbol with daily close data suitable for MACD and ATR.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - the broker/tester data source is not available for unregistered symbols.

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
| Trades / year / symbol | `12` |
| Typical hold time | days to weeks |
| Expected drawdown profile | Whipsaw risk in sideways markets and delayed exits after volatility shocks. |
| Regime preference | trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `3f3833d9-8676-52e4-a822-2c5fc87bbe20`
**Source type:** GitHub notebook
**Pointer:** Oleg Polakow / vectorbt, `examples/MACDVolume.ipynb`, https://github.com/polakowo/vectorbt/blob/master/examples/MACDVolume.ipynb
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11144_vbt-macd-zero.md`

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
| v1 | 2026-06-07 | Initial build from card | e2f56c4d-1832-4a69-ad76-a14920949c37 |
