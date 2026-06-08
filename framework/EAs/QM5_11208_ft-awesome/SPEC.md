# QM5_11208_ft-awesome - Strategy Spec

**EA ID:** QM5_11208
**Slug:** ft-awesome
**Source:** 1580128f-e465-5454-bb97-a7572a6cfd6d
**Author of this spec:** Codex
**Last revised:** 2026-06-08

---

## 1. Strategy Logic

This EA trades long-only H1 momentum continuation. On each new closed H1 bar it computes MACD(12,26,9) on close and Awesome Oscillator as SMA(5, median price) minus SMA(34, median price). It opens long when MACD is above zero and Awesome Oscillator crosses from below zero to above zero. It exits when MACD is below zero and Awesome Oscillator crosses from above zero to below zero, or by the framework Friday close, ATR stop, or 10 percent ROI target.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_macd_fast | 12 | 8-16 | Fast EMA period for the MACD line. |
| strategy_macd_slow | 26 | 21-34 | Slow EMA period for the MACD line. |
| strategy_macd_signal | 9 | fixed baseline | MACD signal period from TA-Lib defaults. |
| strategy_ao_fast | 5 | 5-8 | Fast SMA period for Awesome Oscillator median price. |
| strategy_ao_slow | 34 | 21-34 | Slow SMA period for Awesome Oscillator median price. |
| strategy_atr_period | 14 | fixed baseline | ATR period used for baseline stop distance. |
| strategy_atr_stop_mult | 2.5 | 2.0-3.0 | ATR multiplier used for the stop loss. |
| strategy_roi_pct | 10.0 | fixed source value | Immediate ROI target percentage from the source strategy. |
| strategy_max_spread_stop_pct | 10.0 | card filter | Maximum spread as a percentage of planned stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card R3 primary FX basket member with standard OHLC data.
- GBPUSD.DWX - Card R3 primary FX basket member with standard OHLC data.
- USDJPY.DWX - Card R3 primary FX basket member with standard OHLC data.
- XAUUSD.DWX - Card R3 primary metals basket member with standard OHLC data.

**Explicitly NOT for:**
- Symbols outside the card R3 basket - not part of this approved portable baseline.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 70 |
| Typical hold time | H1 momentum hold until ROI target, ATR stop, opposite AO/MACD signal, or Friday close |
| Expected drawdown profile | Medium risk class from card initial risk profile |
| Regime preference | Momentum continuation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 1580128f-e465-5454-bb97-a7572a6cfd6d
**Source type:** GitHub strategy source
**Pointer:** https://github.com/freqtrade/freqtrade-strategies/blob/main/user_data/strategies/berlinguyinca/AwesomeMacd.py
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11208_ft-awesome.md`

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
| v1 | 2026-06-08 | Initial build from card | 8e991b7b-86e7-45f7-9e65-d36ac042f7e9 |
