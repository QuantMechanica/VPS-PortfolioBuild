# QM5_12362_nikh-supertrend - Strategy Spec

**EA ID:** QM5_12362
**Slug:** nikh-supertrend
**Source:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab (see approved card source citation)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

This EA is a long-only daily SuperTrend flip system. On each completed D1 bar it reconstructs SuperTrend from ATR lookback 10 and multiplier 3, then enters long when the prior SuperTrend line was above price and the latest closed-bar SuperTrend line is below price. It exits the long position when the SuperTrend line flips back above the latest closed-bar price. The baseline protective stop is a hard 2.0 x ATR(14) stop from entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_supertrend_atr_period | 10 | 7-14 tested | ATR lookback used to reconstruct the SuperTrend line. |
| strategy_supertrend_multiplier | 3.0 | 2.0-4.0 tested | ATR multiplier used for SuperTrend upper and lower bands. |
| strategy_stop_atr_period | 14 | 14 baseline | ATR lookback for the hard protective stop. |
| strategy_stop_atr_mult | 2.0 | 1.5-2.5 tested | ATR multiple for the hard protective stop. |
| strategy_warmup_bars | 120 | 120+ | Minimum D1 bars used before trading signals are accepted. |
| strategy_atr_median_filter | false | true/false | Optional P3 filter to skip entries when ATR is below its median. |
| strategy_atr_median_lookback | 120 | 5-500 | Lookback used by the optional ATR median filter. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed DWX forex symbol with D1 OHLC and ATR data.
- GBPUSD.DWX - card-listed DWX forex symbol with D1 OHLC and ATR data.
- USDJPY.DWX - card-listed DWX forex symbol with D1 OHLC and ATR data.
- XAUUSD.DWX - card-listed DWX metals symbol with D1 OHLC and ATR data.
- GDAXI.DWX - DWX matrix DAX proxy for card-listed GER40.DWX, which is not present in the matrix.
- NDX.DWX - card-listed DWX Nasdaq 100 index symbol with D1 OHLC and ATR data.
- WS30.DWX - card-listed DWX Dow 30 index symbol with D1 OHLC and ATR data.

**Explicitly NOT for:**
- GER40.DWX - not present in `framework/registry/dwx_symbol_matrix.csv`; DAX exposure is registered as GDAXI.DWX.
- SP500.DWX - optional card symbol only, not part of the primary P2 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 12 |
| Typical hold time | Daily trend holds; conservative completed trade frequency is 8-18 trades/year/symbol. |
| Expected drawdown profile | Whipsaw risk during sideways ranges with volatility-adjusted stop distance. |
| Regime preference | trend-following, volatility-adjusted, signal-reversal-exit, atr-hard-stop, long-only |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab
**Source type:** GitHub source file
**Pointer:** Nikhil-Adithyan/Algorithmic-Trading-with-Python, Overlap/SuperTrend.py
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12362_nikh-supertrend.md`

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
| v1 | 2026-06-18 | Initial build from card | 4f250719-8d0e-40a9-a8c6-17a04c276b66 |
