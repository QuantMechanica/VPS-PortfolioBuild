# QM5_1624_ehlers-adaptive-cg-h4 — Strategy Spec

**EA ID:** QM5_1624
**Slug:** `ehlers-adaptive-cg-h4`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Codex
**Last revised:** 2026-08-22

---

## 1. Strategy Logic

This EA mechanizes the approved Ehlers Adaptive Center of Gravity strategy on H4 bars. It estimates the dominant cycle period P using a 48-bar autocorrelation periodogram, sets the CG oscillator length to half the dominant cycle (N = P / 2), and computes the Center of Gravity oscillator on close prices with a 1-bar lagged trigger line. Long entries fire when the CG oscillator crosses above its trigger line in agreement with a positive D1 EMA(200) slope. Short entries fire on downward CG crossings with a negative D1 EMA(200) slope. Trades use a 2.0 ATR stop loss, exit on CG-trigger re-crossings or daily EMA slope reversals, and close on an adaptive 2.0 * P bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_period_min` | 6 | >=4 | Minimum dominant cycle period bound in H4 bars. |
| `strategy_period_max` | 48 | <=64 | Maximum dominant cycle period bound in H4 bars. |
| `strategy_autocorr_lookback` | 48 | >=20 | Lookback window for autocorrelation periodogram calculation. |
| `strategy_d1_ema_period` | 200 | >=10 | D1 EMA period for macro trend slope filter. |
| `strategy_atr_period` | 14 | >=2 | ATR period for stop loss sizing and spread filter. |
| `strategy_sl_atr_mult` | 2.0 | >0.0 | Stop loss distance in ATR multiples. |
| `strategy_spread_atr_mult` | 0.3 | >0.0 | Maximum allowed spread as a fraction of ATR(14). |
| `strategy_time_stop_mult` | 2.0 | >0.0 | Multiplier on detected dominant period P for maximum trade hold time. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid FX major with full H4 and D1 price history.
- `GBPUSD.DWX` — liquid FX major with strong cyclical behavior.
- `USDJPY.DWX` — liquid FX major suitable for adaptive cycle oscillators.
- `AUDUSD.DWX` — liquid commodity currency pair.
- `USDCAD.DWX` — liquid North American currency pair.
- `USDCHF.DWX` — liquid European currency pair.
- `NZDUSD.DWX` — liquid Pacific currency pair.
- `NDX.DWX` — liquid US tech equity index CFD.
- `WS30.DWX` — liquid US broad equity index CFD.
- `SP500.DWX` — liquid US large-cap equity index CFD.
- `GDAXI.DWX` — liquid European equity index CFD.
- `UK100.DWX` — liquid UK equity index CFD.
- `XAUUSD.DWX` — liquid precious metals CFD.
- `XTIUSD.DWX` — liquid energy CFD.

**Explicitly NOT for:**
- Symbols outside `dwx_symbol_matrix.csv` — unsupported by broker data feeds.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | `D1` close EMA(200) slope |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `100` |
| Typical hold time | `12 to 48 H4 bars depending on detected dominant cycle period P` |
| Expected drawdown profile | `ATR-bounded oscillator reversal trades aligned with daily macro trend` |
| Regime preference | `Cyclical mean-reversion and turning-point momentum within daily trend` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** `book / trade-press`
**Pointer:** `John F. Ehlers — Cybernetic Analysis for Stocks and Futures (Wiley 2004) ch. 7 & Cycle Analytics for Traders (Wiley 2013) ch. 9`
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_1624_ehlers-adaptive-cg-h4.md`

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
| v1 | 2026-08-22 | Initial build from card | 02da6437-8c76-42c5-82df-ed307ce12628 |
