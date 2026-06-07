# QM5_11190_ft-umacd - Strategy Spec

**EA ID:** QM5_11190
**Slug:** `ft-umacd`
**Source:** `1580128f-e465-5454-bb97-a7572a6cfd6d` (see `strategy-seeds/sources/1580128f-e465-5454-bb97-a7572a6cfd6d/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA trades long on M5 closed bars when the ratio `(EMA12 / EMA26) - 1` sits inside the source buy band from -0.01416 to -0.01176. It enters at market on the next bar through the V5 framework. The baseline stop is ATR(14) times 2.0, and discretionary exits occur when the same ratio is inside the normalized source exit interval from -0.02323 to -0.00707 or when the source ROI ladder threshold is met.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_fast` | 12 | 10-14 | Fast EMA period used in the UMACD ratio. |
| `strategy_ema_slow` | 26 | 22-30 | Slow EMA period used in the UMACD ratio. |
| `strategy_buy_umacd_min` | -0.01416 | -0.02000 to -0.01000 | Lower bound of the long-entry UMACD band. |
| `strategy_buy_umacd_max` | -0.01176 | -0.01400 to -0.00800 | Upper bound of the long-entry UMACD band. |
| `strategy_exit_umacd_min` | -0.02323 | fixed source value | Lower normalized bound of the source exit band. |
| `strategy_exit_umacd_max` | -0.00707 | fixed source value | Upper normalized bound of the source exit band. |
| `strategy_atr_period` | 14 | fixed baseline | ATR period for baseline stop distance. |
| `strategy_atr_stop_mult` | 2.0 | 1.5-2.5 | ATR multiplier for baseline stop distance. |
| `strategy_max_spread_stop_frac` | 0.08 | fixed baseline | Maximum spread as a fraction of planned stop distance. |
| `strategy_warmup_bars` | 30 | fixed baseline | Minimum closed-bar warmup before trading. |
| `strategy_roi_0m_pct` | 21.3 | source value | Immediate ROI threshold in percent. |
| `strategy_roi_27m_pct` | 9.9 | source value | ROI threshold after 27 minutes. |
| `strategy_roi_60m_pct` | 3.0 | source value | ROI threshold after 60 minutes. |
| `strategy_roi_164m_pct` | 0.0 | source value | ROI threshold after 164 minutes. |

Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid major FX pair in the card's portable P2 basket.
- `GBPUSD.DWX` - liquid major FX pair in the card's portable P2 basket.
- `USDJPY.DWX` - liquid major FX pair in the card's portable P2 basket.
- `XAUUSD.DWX` - liquid metal symbol in the card's portable P2 basket.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - the build only registers broker-available DWX symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `110` |
| Typical hold time | `minutes to a few hours, bounded by source ROI ladder` |
| Expected drawdown profile | `medium risk; ATR stop controls adverse moves` |
| Regime preference | `EMA-ratio momentum pullback / mean reversion` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `1580128f-e465-5454-bb97-a7572a6cfd6d`
**Source type:** `GitHub strategy source`
**Pointer:** `https://github.com/freqtrade/freqtrade-strategies/blob/main/user_data/strategies/UniversalMACD.py`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11190_ft-umacd.md`

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
| v1 | 2026-06-07 | Initial build from card | dd987eb7-8176-4839-a534-2b07f5db46cc |
