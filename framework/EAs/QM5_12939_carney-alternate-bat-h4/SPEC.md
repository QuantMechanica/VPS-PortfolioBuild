# QM5_12939_carney-alternate-bat-h4 — Strategy Spec

**EA ID:** QM5_12939
**Slug:** carney-alternate-bat-h4
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Author of this spec:** Gemini
**Last revised:** 2026-08-21

---

## 1. Strategy Logic

The Carney Alternate-Bat pattern operates on H4 bars. It identifies a 5-pivot harmonic structure (X-A-B-C-D) where D extends beyond X to 1.130 * XA with a precise 0.382 B-pivot constraint.

A bullish entry occurs at pivot D when:
- AB/XA = 0.382 (+/- 5%)
- BC/AB in [1.130, 2.618]
- CD/BC in [2.000, 3.618]
- D/XA = 1.130 (+/- 5%, extending beyond X)
- D1 RSI(14) in [25, 75] range
- Closed H4 confirmation candle closes above the D-pivot bar high.

A bearish entry occurs on the inverted pattern.

Risk management enforces an ATR-based stop loss (1.27x ATR beyond D), take profit target at 38.2% retracement of the AD leg, and a 30-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_fractal_wing_bars | 2 | 2-4 | Swing pivot wing bars |
| strategy_scan_bars | 96 | 60-150 | Swing pivot search depth |
| strategy_ratio_tolerance | 0.05 | 0.03-0.08 | Harmonic ratio tolerance fraction (5%) |
| strategy_ab_xa_ratio | 0.382 | 0.382 fixed | Alternate Bat B-pivot constraint |
| strategy_bc_ab_min | 1.130 | 1.00-1.25 | BC extension range minimum |
| strategy_bc_ab_max | 2.618 | 2.00-3.00 | BC extension range maximum |
| strategy_cd_bc_min | 2.000 | 1.618-2.24 | CD leg extension minimum |
| strategy_cd_bc_max | 3.618 | 3.00-4.00 | CD leg extension maximum |
| strategy_d_xa_ratio | 1.130 | 1.130 fixed | D-pivot extension beyond X |
| strategy_rsi_d1_min | 25.0 | 20-30 | D1 RSI filter range minimum |
| strategy_rsi_d1_max | 75.0 | 70-80 | D1 RSI filter range maximum |
| strategy_atr_period | 14 | 10-21 | ATR period for stops and targets |
| strategy_atr_sl_mult | 1.27 | 1.0-2.0 | Stop loss distance beyond D in ATR multiples |
| strategy_tp_ad_retracement | 0.382 | 0.382-0.618 | Profit target AD retracement fraction |
| strategy_max_hold_bars | 30 | 20-45 | Maximum hold duration in H4 bars |
| strategy_cooldown_bars | 18 | 12-24 | Minimum bars between entries in same direction |
| strategy_spread_max_atr_mult | 0.3 | 0.2-0.5 | Max allowed spread as fraction of ATR |

---

## 3. Symbol Universe

**Designed for:**
- `GDAXI.DWX` — DAX 40 index CFD
- `NDX.DWX` — Nasdaq 100 index CFD
- `SP500.DWX` — S&P 500 index CFD
- `UK100.DWX` — FTSE 100 index CFD
- `WS30.DWX` — Dow 30 index CFD
- `XAUUSD.DWX` — Gold commodity CFD
- `EURUSD.DWX` — FX major
- `GBPUSD.DWX` — FX major
- `USDJPY.DWX` — FX major
- `USDCHF.DWX` — FX major
- `AUDUSD.DWX` — FX major
- `USDCAD.DWX` — FX major
- `NZDUSD.DWX` — FX major

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | D1 (RSI 14 filter) |
| Bar gating | `QM_IsNewBar(_Symbol, _Period)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 10-25 |
| Typical hold time | 2-5 days (max 30 H4 bars) |
| Expected drawdown profile | Clean structural stops beyond D extension |
| Regime preference | Reversal at harmonic exhaustion points |
| Win rate target (qualitative) | High (55-65%) |

---

## 6. Source Citation

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** published book / forum
**Pointer:** Scott M. Carney — Harmonic Trading Vol II (2010) ch. 3 pp. 89-104 + FF thread/272317
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12939_carney-alternate-bat-h4.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
