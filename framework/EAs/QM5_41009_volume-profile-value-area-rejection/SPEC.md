# QM5_41009_volume-profile-value-area-rejection — Strategy Spec

**EA ID:** QM5_41009
**Slug:** volume-profile-value-area-rejection
**Source:** volume-profile-value-area-rejection-official-source
**Author of this spec:** Gemini
**Last revised:** 2026-08-18

---

## 1. Strategy Logic

Auction Market Theory (AMT) value area rejection model operating on M5 bars. On the first bar of each trading day, the EA constructs the previous completed broker-day's volume profile and determines the 70% Value Area High (VAH), Value Area Low (VAL), and Point of Control (POC). During the trading session, when price probes outside the value area (below VAL or above VAH) and rejects back into the value area on a closed M5 reversal candle, the EA enters a fade position. Initial stop loss is placed at 1.5x ATR(14, M5), and take profit targets the prior day's POC. Stop loss is moved to break-even once +1.0R is achieved.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `InpValueAreaPct` | 70.0 | 68.0-72.0 | Value Area volume percentile |
| `InpBufferTicks` | 4 | 2-8 | Rejection buffer in ticks |
| `InpAtrPeriod` | 14 | 10-30 | ATR period for stop loss sizing |
| `InpAtrSlMult` | 1.5 | 1.0-3.0 | ATR multiplier for stop loss placement |
| `InpSpreadAtrMult` | 1.8 | 1.0-3.0 | Maximum allowable spread as multiple of M5 ATR(14) |
| `InpEnableBreakEven` | true | true/false | Move stop loss to break-even at +1.0R |
| `InpBucketTicks` | 10 | 5-20 | Volume profile histogram bucket width in ticks |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` — Deep liquid equity index CFD with pronounced auction market structure and value area adherence.
- `NDX.DWX` — High-beta equity index CFD exhibiting sharp intraday mean-reverting probes at profile extremes.

**Explicitly NOT for:**
- `EURCHF.DWX` — Low-volatility FX pair lacking sufficient auction profile dispersion.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 150 |
| Typical hold time | hours |
| Expected drawdown profile | Tight controlled drawdown (<2.5%) with rapid mean-reversion profile |
| Regime preference | mean-revert |
| Win rate target (qualitative) | high |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** volume-profile-value-area-rejection-official-source
**Source type:** book
**Pointer:** Dalton, J. (1990). Mind Over Markets: Power Trading with Market Generated Information.
**R1–R4 verdict (Q00):** all PASS / see `strategy-seeds/cards/approved/QM5_41009_volume-profile-value-area-rejection.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-18 | Initial build from card | Task 0fd1b0a8-c415-4309-9778-4ebefa05a1cf |
