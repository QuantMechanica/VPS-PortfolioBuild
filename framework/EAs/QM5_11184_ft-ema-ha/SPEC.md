# QM5_11184_ft-ema-ha - Strategy Spec

**EA ID:** QM5_11184
**Slug:** ft-ema-ha
**Source:** 1580128f-e465-5454-bb97-a7572a6cfd6d
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

This EA trades long on M5 closed bars when EMA20 crosses above EMA50 and the same closed bar is confirmed by a green Heikin-Ashi candle whose close is above EMA20. It enters at market on the next bar tick, uses an ATR(14) stop multiplied by 2.0, and exits on the source signal where EMA50 crosses above EMA100 while the Heikin-Ashi candle turns red below EMA20. Open trades can also close through the source ROI ladder: 5% immediately, 4% after 20 minutes, 3% after 30 minutes, and 1% after 60 minutes.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_ema_fast | 20 | 10-30 | Fast EMA used for the entry crossover and Heikin-Ashi close filter. |
| strategy_ema_mid | 50 | 40-60 | Mid EMA used for entry and exit crossovers. |
| strategy_ema_slow | 100 | 80-120 | Slow EMA used for exit crossover and warmup. |
| strategy_atr_period | 14 | P3 sweep candidate | ATR period for the protective stop. |
| strategy_atr_stop_mult | 2.0 | 1.5-2.5 | ATR multiplier for the protective stop. |
| strategy_max_spread_stop_frac | 0.08 | fixed from card | Maximum spread as a fraction of planned stop distance. |
| strategy_roi_0m_pct | 5.0 | source value | Minimum profit percent for immediate ROI close. |
| strategy_roi_20m_pct | 4.0 | source value | Minimum profit percent after 20 minutes. |
| strategy_roi_30m_pct | 3.0 | source value | Minimum profit percent after 30 minutes. |
| strategy_roi_60m_pct | 1.0 | source value | Minimum profit percent after 60 minutes. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - liquid FX major suitable for OHLC-derived EMA and Heikin-Ashi trend signals.
- GBPUSD.DWX - liquid FX major suitable for the same portable M5 trend mechanics.
- USDJPY.DWX - liquid FX major with DWX data availability for M5 OHLC-derived signals.
- XAUUSD.DWX - liquid metal CFD included by the approved R3 basket for trend mechanics.

**Explicitly NOT for:**
- Non-DWX symbols - build and pipeline runs require canonical DWX symbols from the matrix.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 140 |
| Typical hold time | README sample average duration 476.1 minutes; ROI ladder evaluates from 0 to 60 minutes. |
| Expected drawdown profile | medium risk from ATR stop and M5 trend-following cadence |
| Regime preference | trend-following |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 1580128f-e465-5454-bb97-a7572a6cfd6d
**Source type:** GitHub strategy source
**Pointer:** https://github.com/freqtrade/freqtrade-strategies/blob/main/user_data/strategies/Strategy001.py
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11184_ft-ema-ha.md`

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
| v1 | 2026-06-07 | Initial build from card | a625860d-f44e-449c-af79-5069a979364d |
