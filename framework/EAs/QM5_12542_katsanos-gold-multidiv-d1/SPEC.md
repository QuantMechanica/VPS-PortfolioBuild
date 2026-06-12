# QM5_12542_katsanos-gold-multidiv-d1 - Strategy Spec

**EA ID:** QM5_12542
**Slug:** `katsanos-gold-multidiv-d1`
**Source:** `katsanos-intermarket-2008-ch11` (see `D:/QM/strategy_farm/source_cache/katsanos_intermarket_2008.txt`)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

This EA trades XAUUSD.DWX on D1 closed bars when gold diverges from silver and a USD-index proxy. It computes 15-day percentage yields, a fixed 300-day regression divergence for XAGUSD.DWX and the DXY proxy, then normalizes each divergence through a 200-day IMO-style oscillator and averages both oscillators. It opens long when the combined oscillator reverses down from the 80 extreme, stochastic(5) crosses above its 3-day average, XAG ROC(10) is positive, DXY-proxy ROC(10) is negative, and combined divergence is positive; short is the mirror at the 20 extreme. It exits on the opposite oscillator reversal or after 50 D1 bars, with an initial 2.5x ATR(14) disaster stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_yield_lookback` | 15 | 1-60 | Bars used for base and partner percentage yields. |
| `strategy_regression_lookback` | 300 | 50-600 | Fixed window for the regression-divergence slope. |
| `strategy_imo_lookback` | 200 | 50-400 | Normalization window for the IMO oscillator. |
| `strategy_imo_ma_period` | 3 | 1-10 | Averaging period in the IMO numerator and denominator. |
| `strategy_upper_extreme` | 80.0 | 50-100 | Upper oscillator reversal level for long entries and short exits. |
| `strategy_lower_extreme` | 20.0 | 0-50 | Lower oscillator reversal level for short entries and long exits. |
| `strategy_alert_valid_bars` | 3 | 1-10 | Number of bars an extreme reversal remains valid. |
| `strategy_stoch_k_period` | 5 | 2-30 | Stochastic confirmation lookback. |
| `strategy_stoch_ma_period` | 3 | 1-10 | Stochastic signal average period. |
| `strategy_roc_period` | 10 | 1-60 | Partner direction filter lookback. |
| `strategy_atr_period` | 14 | 2-100 | ATR period for the disaster stop. |
| `strategy_atr_sl_mult` | 2.5 | 0.5-10.0 | ATR multiple for the disaster stop. |
| `strategy_time_exit_bars` | 50 | 1-200 | Maximum holding period in D1 bars. |
| `strategy_history_bars` | 620 | 540-1000 | D1 bars loaded for fixed-window intermarket math. |
| `strategy_base_symbol` | XAUUSD.DWX | DWX symbol | Tradeable base symbol. |
| `strategy_xag_symbol` | XAGUSD.DWX | DWX symbol | Positive intermarket partner. |
| `strategy_eurusd_symbol` | EURUSD.DWX | DWX symbol | DXY proxy component. |
| `strategy_usdjpy_symbol` | USDJPY.DWX | DWX symbol | DXY proxy component. |
| `strategy_gbpusd_symbol` | GBPUSD.DWX | DWX symbol | DXY proxy component. |
| `strategy_usdcad_symbol` | USDCAD.DWX | DWX symbol | DXY proxy component. |
| `strategy_usdchf_symbol` | USDCHF.DWX | DWX symbol | DXY proxy component. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` - the card's tradeable base gold symbol and the only registered execution symbol for this EA.

**Read-only intermarket inputs:**
- `XAGUSD.DWX` - positive silver partner used in the regression divergence.
- `EURUSD.DWX` - DXY proxy component.
- `USDJPY.DWX` - DXY proxy component.
- `GBPUSD.DWX` - DXY proxy component.
- `USDCAD.DWX` - DXY proxy component.
- `USDCHF.DWX` - DXY proxy component.

**Explicitly NOT for:**
- `SP500.DWX` - unrelated equity index exposure.
- `NDX.DWX` - unrelated equity index exposure.
- `WS30.DWX` - unrelated equity index exposure.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default skeleton gate) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 6 |
| Typical hold time | up to 50 D1 bars |
| Expected drawdown profile | approximately 10 percent card expectation, capped by framework risk controls |
| Regime preference | intermarket mean-reversion / divergence reversal in the gold complex |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `katsanos-intermarket-2008-ch11`
**Source type:** book
**Pointer:** `D:/QM/strategy_farm/source_cache/katsanos_intermarket_2008.txt`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12542_katsanos-gold-multidiv-d1.md`

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
| v1 | 2026-06-12 | Initial build from card | 9682a8d5-4986-410e-8e0c-03eadd1b7f17 |
