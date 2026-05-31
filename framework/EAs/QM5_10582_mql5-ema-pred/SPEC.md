# QM5_10582_mql5-ema-pred - Strategy Spec

**EA ID:** QM5_10582
**Slug:** `mql5-ema-pred`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-29

---

## 1. Strategy Logic

The EA trades the EMA_Prediction semaphore rule on the chart timeframe. A long entry is opened when the latest closed bar has the fast EMA crossing above the slow EMA and that bar closed bullish. A short entry is opened when the fast EMA crosses below the slow EMA and that bar closed bearish. An open long closes on the opposite bearish signal, and an open short closes on the opposite bullish signal; hard stop, target, news, Friday close, and kill-switch exits remain framework-managed.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fast_ema_period` | 1 | 1-200 | Fast EMA period from EMA_Prediction. |
| `strategy_slow_ema_period` | 2 | 2-400 | Slow EMA period from EMA_Prediction; must be greater than fast. |
| `strategy_atr_period` | 14 | 1-200 | ATR period for the hard stop calculation. |
| `strategy_atr_sl_mult` | 2.0 | 0.1-10.0 | Stop distance in ATR multiples. |
| `strategy_take_profit_rr` | 1.5 | 0.1-10.0 | Take-profit distance as reward/risk multiple. |
| `strategy_max_spread_points` | 80 | 0-10000 | Skip new entries when current spread exceeds this point limit; 0 disables this gate. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - they are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `GBPJPY.DWX` - primary source test family includes GBPJPY H6 and it is present in the DWX matrix.
- `EURUSD.DWX` - liquid FX major suitable for EMA crossover semaphore logic.
- `USDJPY.DWX` - liquid JPY major suitable for the same closed-bar EMA rule.
- `XAUUSD.DWX` - liquid metal listed by the card as portable and present in the DWX matrix.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - not available for DWX backtest registration.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H6` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `35` |
| Typical hold time | `hours to days; opposite closed-bar arrow or ATR bracket exit` |
| Expected drawdown profile | `Moderate trend-following drawdown from alternating EMA-cross signals on H6.` |
| Regime preference | `trend` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase`
**Pointer:** `https://www.mql5.com/en/code/13589` and `https://www.mql5.com/en/code/1905`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10582_mql5-ema-pred.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-05-29 | Initial build from card | 2b497b0f-b2db-4a66-bb78-afc7a5d8c9ba |
