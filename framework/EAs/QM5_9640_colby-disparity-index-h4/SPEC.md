# QM5_9640_colby-disparity-index-h4 — Strategy Spec

**EA ID:** QM5_9640
**Slug:** `colby-disparity-index-h4`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The Disparity Index (DI) measures price deviation from its 20-bar SMA as a percentage: `DI = 100 * (Close - SMA(20)) / SMA(20)`. A 252-bar rolling z-score of DI identifies statistically extreme deviations from the norm. The EA enters long when DI z-score is at or below -1.75 (price deeply below its moving average), the close is above SMA(200) confirming an uptrend context, and DI z-score has risen by at least 0.25 from the prior bar (momentum turning back toward zero). Short entries mirror this: DI z-score at or above +1.75, close below SMA(200), and DI z-score falling by at least 0.25. Positions exit when DI z-score crosses back through zero (mean-reversion complete), when the 1.5R take-profit is hit, or after 12 H4 bars (time stop). A slope filter blocks entries when SMA(200) has moved less than 0.05 × ATR(14) over the past 10 bars, avoiding flat-chop regimes where mean-reversion signals become noise.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_di_period` | 20 | 10–50 | SMA period used to compute the Disparity Index |
| `strategy_di_zscore_window` | 252 | 100–504 | Rolling lookback (bars) for z-score mean/std |
| `strategy_entry_zscore` | 1.75 | 1.0–3.0 | Absolute DI z-score threshold to trigger entry |
| `strategy_momentum_min` | 0.25 | 0.05–0.5 | Minimum DI_z change toward zero between last two bars |
| `strategy_sma200_period` | 200 | 100–300 | Trend bias SMA period |
| `strategy_sma200_slope_bars` | 10 | 5–20 | Bars over which SMA(200) slope is measured |
| `strategy_sma200_slope_atr` | 0.05 | 0.01–0.2 | Slope filter threshold as fraction of ATR(14) |
| `strategy_sl_atr_mult` | 0.35 | 0.1–1.0 | SL distance = setup bar extreme + X × ATR(14) |
| `strategy_tp_r_mult` | 1.5 | 1.0–3.0 | Take-profit in R multiples |
| `strategy_time_stop_bars` | 12 | 4–48 | Maximum hold in H4 bars before forced exit |
| `strategy_atr_period` | 14 | 7–21 | ATR period for SL sizing and slope filter |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — Major FX pair; liquid, mean-reverting behavior on H4 around SMA; tight spreads favor z-score strategy
- `GBPUSD.DWX` — Major FX pair; similar DI mean-reversion characteristics to EURUSD
- `USDJPY.DWX` — Major FX pair; trend-and-revert dynamics make DI z-score viable
- `XAUUSD.DWX` — Gold; exhibits strong mean-reversion around MA on H4; DWX custom symbol with tick data from 2018

**Explicitly NOT for:**
- `SP500.DWX` — Not in card basket; equity indices have stronger trending characteristics than FX/Gold mean-reversion

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar()` (PERIOD_CURRENT = H4 when deployed on H4 chart) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~60 (range 40–90) |
| Typical hold time | 4–48 hours (1–12 H4 bars) |
| Expected drawdown profile | Moderate; mean-reversion with fixed SL limits runaway losses |
| Regime preference | Mean-reversion within trending context |
| Win rate target (qualitative) | Medium (z-score reversions tend to complete; TP at 1.5R) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** `book / forum`
**Pointer:** Robert W. Colby, *The Encyclopedia of Technical Market Indicators*, McGraw-Hill 2003; ForexFactory Trading Systems indicator discussions, https://www.forexfactory.com/forums
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9640_colby-disparity-index-h4.md`

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
| v1 | 2026-06-11 | Initial build from card | 74f515e0-92d4-4131-b349-5fd7e2c2b09c |
