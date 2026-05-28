# QM5_10434_mql5-dom-d1 - Strategy Spec

**EA ID:** QM5_10434
**Slug:** `mql5-dom-d1`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-27

---

## 1. Strategy Logic

At the start of each D1 bar, the EA skips Mondays and counts bullish versus bearish H1 candles from the previous completed trading day. It buys when bullish H1 candles outnumber bearish candles and the previous day's final H1 close is above the SMA(50); it sells when bearish candles dominate and the final H1 close is below the SMA(50). The stop is placed beyond the previous day's low or high by 1.0 ATR(14,D1), the target is 2R, and any open trade is closed at the next daily decision if neither stop nor target has fired.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ma_period` | 50 | 1-500 | H1 SMA period used to confirm the previous day's final H1 close. |
| `strategy_atr_period` | 14 | 1-200 | D1 ATR period used for stop expansion and stop-distance cap. |
| `strategy_atr_multiplier` | 1.0 | 0.1-10.0 | ATR multiplier added beyond the previous day's high or low for SL placement. |
| `strategy_tp_multiplier` | 2.0 | 0.1-10.0 | Take-profit distance as a multiple of initial stop distance. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Primary liquid FX major from the card's R3 basket.
- `GBPUSD.DWX` - Liquid FX major from the card's R3 basket.
- `USDJPY.DWX` - Liquid FX major from the card's R3 basket.
- `XAUUSD.DWX` - Liquid gold symbol from the card's R3 basket.

**Explicitly NOT for:**
- `SP500.DWX` - Not part of the card's FX/XAU R3 basket.
- `NDX.DWX` - Not part of the card's FX/XAU R3 basket.
- `WS30.DWX` - Not part of the card's FX/XAU R3 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | `H1` candle counts and SMA(50); `D1` ATR(14) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `120` |
| Typical hold time | `intraday to one trading day; time stop at next daily decision` |
| Expected drawdown profile | `Fixed-risk trend-confirming daily-bias system with ATR-bounded stops` |
| Regime preference | `trend-following / daily-bias` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase`
**Pointer:** `https://www.mql5.com/en/code/71195`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10434_mql5-dom-d1.md`

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
| v1 | 2026-05-27 | Initial build from card | 3047fdee-14ee-4c3d-8772-92503d7c5cec |
