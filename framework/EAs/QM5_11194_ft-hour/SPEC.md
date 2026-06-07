# QM5_11194_ft-hour - Strategy Spec

**EA ID:** QM5_11194
**Slug:** ft-hour
**Source:** 1580128f-e465-5454-bb97-a7572a6cfd6d
**Author of this spec:** Codex
**Last revised:** 2026-06-08

---

## 1. Strategy Logic

The EA trades long on H1 closed bars when the just-closed candle's Darwinex broker hour is inside the source buy window. The default buy window is broker hour 4 through 23, matching the source `buy_hour_min = 4` and `buy_hour_max = 24` over valid 0-23 hour values. Open trades are closed when the sell-hour window is active, or when the fixed ROI ladder threshold is reached for the current holding time. The default sell window is interpreted literally as a wraparound window from broker hour 22 through 21, which covers all broker hours.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_buy_hour_min | 4 | 0-23 | First broker hour eligible for long entry. |
| strategy_buy_hour_max | 24 | 0-24 | Last broker hour eligible for long entry; 24 means through hour 23. |
| strategy_sell_hour_min | 22 | 0-23 | First broker hour eligible for signal exit. |
| strategy_sell_hour_max | 21 | 0-24 | Last broker hour eligible for signal exit; lower than min means wraparound. |
| strategy_atr_period | 14 | 1-200 | ATR period used for the protective stop. |
| strategy_atr_stop_mult | 2.0 | 0.1-10.0 | ATR multiple used for the protective stop. |
| strategy_max_spread_stop_fraction | 0.08 | 0.0-1.0 | Maximum allowed spread as a fraction of planned stop distance. |
| strategy_roi_t1_minutes | 169 | 0-10080 | First holding-time step in the ROI ladder. |
| strategy_roi_t2_minutes | 528 | 0-10080 | Second holding-time step in the ROI ladder. |
| strategy_roi_t3_minutes | 1837 | 0-10080 | Final holding-time step in the ROI ladder. |
| strategy_roi_t0 | 0.528 | 0.0-1.0 | Required profit fraction before the first ROI time step. |
| strategy_roi_t1 | 0.113 | 0.0-1.0 | Required profit fraction after `strategy_roi_t1_minutes`. |
| strategy_roi_t2 | 0.089 | 0.0-1.0 | Required profit fraction after `strategy_roi_t2_minutes`. |
| strategy_roi_t3 | 0.0 | 0.0-1.0 | Required profit fraction after `strategy_roi_t3_minutes`. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - FX major with continuous H1 broker-time coverage for session timing.
- GBPUSD.DWX - FX major with continuous H1 broker-time coverage for session timing.
- XAUUSD.DWX - liquid metal symbol listed in the card's portable DWX basket.
- GDAXI.DWX - matrix-verified DAX custom symbol used for the card's German index leg.

**Explicitly NOT for:**
- GER40.DWX - card-stated German index name is not present in `dwx_symbol_matrix.csv`; use GDAXI.DWX.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 80 |
| Typical hold time | Source ROI ladder spans immediate exit through 1837 minutes; default sell-hour wrap can close earlier. |
| Expected drawdown profile | Medium risk per card initial risk profile, with ATR stop replacing the source -10% stoploss for MT5 baseline. |
| Regime preference | Time-of-day session edge. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 1580128f-e465-5454-bb97-a7572a6cfd6d
**Source type:** GitHub strategy repository
**Pointer:** https://github.com/freqtrade/freqtrade-strategies/blob/main/user_data/strategies/HourBasedStrategy.py
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11194_ft-hour.md`

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
| v1 | 2026-06-08 | Initial build from card | 24f9f1b7-b4db-4a63-84cd-eb04e5ab0aac |
