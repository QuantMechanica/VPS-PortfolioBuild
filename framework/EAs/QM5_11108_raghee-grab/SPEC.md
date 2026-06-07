# QM5_11108_raghee-grab - Strategy Spec

**EA ID:** QM5_11108
**Slug:** `raghee-grab`
**Source:** `0693c604-4f96-56ef-be79-15efe9f48b86` (see `strategy-seeds/sources/0693c604-4f96-56ef-be79-15efe9f48b86/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA trades completed H4 GRaB candle state changes around Raghee Horner's 34 EMA wave. It computes EMA(34) on high, close, and low; a completed candle is bullish when it sits above the high EMA, bearish when it sits below the low EMA, and neutral when it overlaps the wave. It opens long when the completed candle changes from neutral or bearish to bullish and the close EMA has risen for the last three completed H4 bars. It opens short on the inverse bearish transition with a falling close EMA, then exits when the completed candle is no longer in the trade direction or after 20 H4 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_period` | 34 | 2-200 | EMA wave period for high, close, and low. |
| `strategy_atr_period` | 14 | 1-100 | ATR period used for baseline stop placement. |
| `strategy_wave_atr_buffer` | 0.5 | 0.0-5.0 | ATR buffer beyond the opposite side of the EMA wave. |
| `strategy_stop_atr_cap` | 2.5 | 0.1-10.0 | Maximum stop distance in ATR multiples. |
| `strategy_max_hold_h4_bars` | 20 | 1-100 | Safety time stop measured in H4 bars. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - primary liquid FX major from the card's R3 basket.
- `GBPUSD.DWX` - liquid FX major from the card's R3 basket.
- `USDJPY.DWX` - liquid FX major from the card's R3 basket.
- `XAUUSD.DWX` - liquid metal symbol from the card's R3 basket.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - not available in the DWX backtest universe.

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
| Trades / year / symbol | `36` |
| Typical hold time | Up to `20` H4 bars by card time stop; earlier exit on neutral or opposite GRaB state. |
| Expected drawdown profile | Trend-state strategy with ATR-capped stop; drawdown clusters during sideways wave overlaps. |
| Regime preference | Trend-following H4 GRaB candle state changes after neutral filtering. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `0693c604-4f96-56ef-be79-15efe9f48b86`
**Source type:** GitHub indicator source
**Pointer:** `https://github.com/EarnForex/RagheeHorner`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11108_raghee-grab.md`

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
| v1 | 2026-06-07 | Initial build from card | 92520ca8-90d4-4350-a738-5026599e59f0 |
