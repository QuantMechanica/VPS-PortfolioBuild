# QM5_11121_easy-trend-adx - Strategy Spec

**EA ID:** QM5_11121
**Slug:** easy-trend-adx
**Source:** 0693c604-4f96-56ef-be79-15efe9f48b86 (see `strategy-seeds/sources/0693c604-4f96-56ef-be79-15efe9f48b86/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA evaluates completed H4 bars and reproduces the Easy Trend Visualizer arrow rule from the approved source. A long entry fires when ADX(10), ADX(14), and ADX(20) are all rising versus the prior bar, ADX(10) is above 35, ADX(14) is above 30, and +DI is above -DI; the previous completed bar must not already have been in that source trend state. A short entry uses the same triple-ADX rising and threshold rule with -DI above +DI. The EA exits on the opposite source arrow, ADX(14) falling for two completed bars, or after 18 H4 bars.

---

## 2. Parameters

Table of every input parameter, its default, range, and meaning.

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_signal_tf | PERIOD_H4 | H4 baseline | Timeframe used for ADX/DI signal evaluation. |
| strategy_adx_fast_period | 10 | 2-100 | Fast source ADX period used for threshold and DI direction. |
| strategy_adx_mid_period | 14 | 2-100 | Middle source ADX period used for threshold and falling-exit check. |
| strategy_adx_slow_period | 20 | 2-100 | Slow source ADX period used in the triple-rising trend-state rule. |
| strategy_adx_fast_threshold | 35.0 | 1-100 | Source Alvl threshold applied to ADX(10). |
| strategy_adx_mid_threshold | 30.0 | 1-100 | Source Alvl2 threshold applied to ADX(14). |
| strategy_atr_period | 14 | 2-100 | ATR period for the initial stop. |
| strategy_atr_sl_mult | 2.5 | 0.1-10 | Initial stop distance in ATR multiples. |
| strategy_max_hold_bars | 18 | 1-200 | Maximum holding period in H4 bars. |

---

## 3. Symbol Universe

Which `.DWX` symbols this EA is designed for. Be explicit about both inclusions
and exclusions.

**Designed for:**
- EURUSD.DWX - liquid FX major in the approved R3 basket with OHLC-derived ADX/DI and ATR data.
- GBPUSD.DWX - liquid FX major in the approved R3 basket with OHLC-derived ADX/DI and ATR data.
- USDJPY.DWX - liquid FX major in the approved R3 basket with OHLC-derived ADX/DI and ATR data.
- XAUUSD.DWX - liquid metal in the approved R3 basket with OHLC-derived ADX/DI and ATR data.

**Explicitly NOT for:**
- Non-DWX symbols - the build and pipeline use Darwinex `.DWX` custom-symbol data only.
- Symbols outside the approved R3 basket - not registered for this EA in `magic_numbers.csv`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

How this EA should behave in production. Calibrates downstream gate expectations.

| Metric | Expected |
|---|---|
| Trades / year / symbol | 25 |
| Typical hold time | Up to 18 H4 bars, usually hours to a few days. |
| Expected drawdown profile | Trend-following whipsaws in sideways markets; ATR stop limits initial trade risk. |
| Regime preference | ADX trend-strength / trend-following regime. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 0693c604-4f96-56ef-be79-15efe9f48b86
**Source type:** GitHub repository and MQL4/MQL5 indicator source
**Pointer:** https://github.com/EarnForex/Easy-Trend-Visualizer and `D:/QM/strategy_farm/tmp_earnforex_batch15/Easy-Trend-Visualizer/EasyTrendVisualizer.mq5`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11121_easy-trend-adx.md`

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
| v1 | 2026-06-07 | Initial build from card | 8e7cb198-8c1a-461e-98c4-eb7afc940731 |
