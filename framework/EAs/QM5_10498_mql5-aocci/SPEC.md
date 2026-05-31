# QM5_10498_mql5-aocci — Strategy Spec

**EA ID:** QM5_10498
**Slug:** `mql5-aocci`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-28

---

## 1. Strategy Logic

The EA evaluates once per new H1 bar. It buys when the Awesome Oscillator is positive, CCI is non-negative, current ask is above the previous D1 pivot, and at least one prior confirmation was adverse. It sells the symmetric inverse: negative AO, non-positive CCI, bid below the pivot, and at least one previous upside condition. Open trades use an ATR-normalized hard stop, a fixed 1.5R target, and close early when the opposite AO/CCI state appears.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_cci_period` | 55 | 1+ | CCI lookback used for entry and opposite-signal exit. |
| `strategy_ao_fast_period` | 5 | 1+ | Fast SMA period on median price for AO approximation. |
| `strategy_ao_slow_period` | 34 | greater than fast | Slow SMA period on median price for AO approximation. |
| `strategy_pivot_tf` | PERIOD_D1 | MT5 timeframe | Higher timeframe used for the previous-bar pivot. |
| `strategy_atr_period` | 14 | 1+ | ATR lookback for stop distance. |
| `strategy_atr_sl_mult` | 1.5 | >0 | ATR multiple for initial stop loss. |
| `strategy_tp_r_mult` | 1.5 | >0 | Take-profit distance expressed as R multiple. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — card R3 primary FX basket member with DWX data available.
- `GBPUSD.DWX` — card R3 primary FX basket member with DWX data available.
- `USDCAD.DWX` — card R3 primary FX basket member with DWX data available.
- `USDJPY.DWX` — card R3 primary FX basket member with DWX data available.

**Explicitly NOT for:**
- Non-DWX symbols — V5 backtests require the registered `.DWX` symbol universe.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | previous `D1` OHLC pivot; previous `H1` close confirmation |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `160` |
| Typical hold time | H1 fixed SL/TP momentum trades; expected hours to a few days |
| Expected drawdown profile | ATR-normalized fixed-risk losses during choppy AO/CCI state changes |
| Regime preference | AO/CCI momentum with pivot confirmation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** MQL5 CodeBase
**Pointer:** `https://www.mql5.com/en/code/21345`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10498_mql5-aocci.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-05-28 | Initial build from card | 228c4faa-5980-46f1-87da-5580d0e2ca96 |
