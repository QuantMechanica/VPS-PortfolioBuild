# QM5_11206_ft-asdts-macd - Strategy Spec

**EA ID:** QM5_11206
**Slug:** ft-asdts-macd
**Source:** 1580128f-e465-5454-bb97-a7572a6cfd6d (see `strategy-seeds/sources/1580128f-e465-5454-bb97-a7572a6cfd6d/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-08

---

## 1. Strategy Logic

This EA trades long-only on M5 closed bars. It enters when the MACD main line is above zero and above the MACD signal line, using the default MACD shape from the source card. It exits when the MACD main line falls below the signal line, when the source ROI ladder is met, or through the framework Friday close and ATR stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_macd_fast | 12 | 8-16 | Fast EMA length used by MACD. |
| strategy_macd_slow | 26 | 21-34 | Slow EMA length used by MACD. |
| strategy_macd_signal | 9 | 6-12 | MACD signal smoothing length. |
| strategy_atr_period | 14 | P3 sweep if approved | ATR lookback for the safety stop. |
| strategy_atr_stop_mult | 2.0 | 1.5-2.5 | ATR multiplier for the initial stop. |
| strategy_max_spread_stop_frac | 0.08 | fixed card filter | Maximum spread as a fraction of planned stop distance. |
| strategy_warmup_bars | 35 | at least slow plus signal | MACD warmup depth before signals are accepted. |
| strategy_roi_0m_pct | 5.0 | source fixed | Profit percent needed immediately after entry. |
| strategy_roi_20m_pct | 4.0 | source fixed | Profit percent needed after 20 minutes. |
| strategy_roi_30m_pct | 3.0 | source fixed | Profit percent needed after 30 minutes. |
| strategy_roi_60m_pct | 1.0 | source fixed | Profit percent needed after 60 minutes. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card-listed major FX symbol with DWX M5 OHLC data.
- GBPUSD.DWX - Card-listed major FX symbol with DWX M5 OHLC data.
- USDJPY.DWX - Card-listed major FX symbol with DWX M5 OHLC data.
- XAUUSD.DWX - Card-listed liquid metal symbol with DWX M5 OHLC data.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - build-time registration is forbidden for non-matrix symbols.

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
| Trades / year / symbol | 180 |
| Typical hold time | minutes to hours, governed by the 20/30/60 minute ROI ladder |
| Expected drawdown profile | medium risk with ATR safety stop and fixed-risk sizing |
| Regime preference | trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 1580128f-e465-5454-bb97-a7572a6cfd6d
**Source type:** GitHub strategy source
**Pointer:** https://github.com/freqtrade/freqtrade-strategies/blob/main/user_data/strategies/berlinguyinca/ASDTSRockwellTrading.py
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11206_ft-asdts-macd.md`

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
| v1 | 2026-06-08 | Initial build from card | 5002784e-f0e9-4e6d-9913-f204f933740a |
