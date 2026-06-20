# QM5_9268_mql5-fractal-fail-swing - Strategy Spec

**EA ID:** QM5_9268
**Slug:** `mql5-fractal-fail-swing`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (see `strategy-seeds/sources/ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

The EA trades a failed break of a confirmed Bill Williams fractal on H4. A long signal requires a confirmed fractal low three closed bars back, a sweep below that fractal low on the next bar by at least 0.05 ATR(14), and a close back above the fractal bar high on the latest closed bar. Shorts use the inverse fractal high sweep and close-back rule. Exits occur at the initial SL/TP, after 18 H4 bars, on a close back through the swept fractal level, or on the opposite confirmed fractal close condition.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 14 | 1+ | ATR period used for the sweep threshold and stop buffer. |
| `strategy_stop_atr_mult` | 0.4 | >0 | ATR multiple placed beyond the sweep extreme for the initial stop. |
| `strategy_take_rr` | 2.3 | >0 | Initial take-profit multiple of stop risk. |
| `strategy_sweep_min_atr_mult` | 0.05 | 0+ | Minimum sweep distance as an ATR multiple. |
| `strategy_max_hold_bars` | 18 | 1+ | Failsafe exit after this many H4 bars. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card target; liquid forex major with H4 OHLC, fractals, and ATR available.
- `GBPJPY.DWX` - card target; volatile forex cross suitable for H4 sweep reversals.
- `XAUUSD.DWX` - card target; liquid metal symbol with DWX H4 history and sweep behaviour.

**Explicitly NOT for:**
- `SP500.DWX` - not listed in the approved card target universe.
- `NDX.DWX` - not listed in the approved card target universe.
- `WS30.DWX` - not listed in the approved card target universe.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `32` |
| Typical hold time | `Low-medium frequency; failed fractal sweeps on H4 should trigger roughly 18-45 trades per year per symbol.` |
| Expected drawdown profile | Reversal strategy with ATR-defined stop and 2.3R target. |
| Regime preference | Mean-reversion / reversal around support-resistance fractals. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** `MQL5 article`
**Pointer:** `https://www.mql5.com/en/articles/17334`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9268_mql5-fractal-fail-swing.md`

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
| v1 | 2026-06-20 | Initial build from card | 39cd3796-4ed3-48e6-a973-221984053f76 |
