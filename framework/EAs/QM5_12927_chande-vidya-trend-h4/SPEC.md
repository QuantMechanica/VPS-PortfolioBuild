# QM5_12927_chande-vidya-trend-h4 — Strategy Spec

**EA ID:** QM5_12927
**Slug:** chande-vidya-trend-h4
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Author of this spec:** Gemini
**Last revised:** 2026-08-21

---

## 1. Strategy Logic

Implements the Chande VIDYA (Variable Index Dynamic Average) volatility-adaptive trend cross strategy on H4 bars (Tushar Chande, *The New Technical Trader*, Wiley 1994).

- **Indicator Construction**:
  - **CMO(9)**: Chande Momentum Oscillator over 9 H4 bars: `100 * (SU - SD) / (SU + SD)`.
  - **VIDYA(14)**: Fast adaptive EMA modulated by `|CMO| / 100`.
  - **VIDYA(50)**: Slow adaptive EMA modulated by `|CMO| / 100`.
  - **EMA(200)**: Outer macro trend filter.
  - **ATR(14)**: Volatility cushion for dynamic stop loss sizing.
- **Entry Signals**:
  - **BUY**: Fast VIDYA(14) crosses above Slow VIDYA(50) on closed bar 1, with `CMO(9) > 20`, `Close > EMA(200)`, and bullish bar close (`Close > Open`). Requires re-armed state.
  - **SELL**: Fast VIDYA(14) crosses below Slow VIDYA(50) on closed bar 1, with `CMO(9) < -20`, `Close < EMA(200)`, and bearish bar close (`Close < Open`). Requires re-armed state.
- **Position Management & Exits**:
  - **Hard SL**: BUY stop at `min(Low[1..4]) - 1.0 * ATR(14, H4)`, SELL stop at `max(High[1..4]) + 1.0 * ATR(14, H4)`, capped at `3.5 * ATR(14, H4)`.
  - **Opposite VIDYA cross**: Exits BUY when Fast VIDYA < Slow VIDYA; exits SELL when Fast VIDYA > Slow VIDYA.
  - **CMO momentum-flip exit**: Exits BUY if CMO(9) < 0 for 2 consecutive closes; exits SELL if CMO(9) > 0 for 2 consecutive closes.
  - **EMA-200 macro-bias flip**: Exits BUY if Close crosses below EMA(200); exits SELL if Close crosses above EMA(200).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_cmo_period` | 9 | 7-14 | Chande Momentum Oscillator lookback period |
| `strategy_cmo_threshold` | 20.0 | 15.0-35.0 | Minimum momentum threshold for entry gate |
| `strategy_vidya_fast_period` | 14 | 10-25 | Fast VIDYA baseline smoothing period |
| `strategy_vidya_slow_period` | 50 | 30-80 | Slow VIDYA baseline smoothing period |
| `strategy_ema_period` | 200 | 100-300 | Outer macro bias EMA period on H4 |
| `strategy_atr_period` | 14 | 10-30 | ATR period on H4 for stop loss cushion |
| `strategy_atr_sl_mult` | 1.0 | 0.5-2.0 | ATR multiplier for swing stop cushion |
| `strategy_max_sl_atr_mult` | 3.5 | 2.0-5.0 | Cap on maximum initial stop loss distance |
| `strategy_tp_atr_mult` | 0.0 | 0.0-10.0 | Optional Take Profit ATR multiple (0.0 = no fixed TP) |
| `strategy_max_spread_mult` | 1.5 | 1.0-3.0 | Spread filter ceiling multiplier vs 20-bar median spread |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

Which `.DWX` symbols this EA is designed for.

**Designed for:**
- FX majors: `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `USDCHF.DWX`, `AUDUSD.DWX`, `USDCAD.DWX`, `NZDUSD.DWX`
- Metals: `XAUUSD.DWX`
- Index CFDs: `GDAXI.DWX`, `NDX.DWX`, `SP500.DWX`, `UK100.DWX`, `WS30.DWX`

**Explicitly NOT for:**
- Illiquid exotic pairs without regular H4 momentum continuity.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_H4)` |

---

## 5. Expected Behaviour

How this EA should behave in production.

| Metric | Expected |
|---|---|
| Trades / year / symbol | 20 - 45 |
| Typical hold time | 2 - 8 days |
| Expected drawdown profile | Smooth intermediate trend participation bounded by swing ATR stop |
| Regime preference | High-momentum trending market regimes |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** book / publication
**Pointer:** Tushar Chande, *The New Technical Trader* (Wiley, 1994, ISBN 978-0471597803) + *Stocks & Commodities* March 1993
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12927_chande-vidya-trend-h4.md`

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
| v1 | 2026-08-21 | Initial build from approved card | 718716e3-087b-478c-ab26-fd2e49eb8d3e |
