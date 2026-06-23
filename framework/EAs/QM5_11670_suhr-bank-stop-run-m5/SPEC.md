# QM5_11670_suhr-bank-stop-run-m5 - Strategy Spec

**EA ID:** QM5_11670
**Slug:** suhr-bank-stop-run-m5
**Source:** 6de42a45-3a46-5eb6-a767-71c5ac89a2eb (see `strategy-seeds/sources/6de42a45-3a46-5eb6-a767-71c5ac89a2eb/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

The EA trades M5 reversals around the prior day's high and low. For a long setup, price must have swept below the prior D1 low by at least 3 pips within the last five closed M5 candles, then a closed M5 candle must close back above that low and remain within 15 pips of the stop-run extreme. Short setups mirror this at the prior D1 high. The stop is placed 20 pips beyond the stop-run candle extreme, and the take profit targets the opposite prior-day manipulation point with a 40-pip fixed fallback when the daily range geometry is too small.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_sweep_pips` | 3 | 1-20 | Minimum pierce beyond the prior-day high or low required to count as a stop run. |
| `strategy_confirm_window` | 5 | 1-20 | Number of closed M5 bars before the confirmation bar searched for the stop-run extreme. |
| `strategy_pullback_pips` | 15 | 1-100 | Maximum distance from the current entry reference to the stop-run extreme. |
| `strategy_sl_pips` | 20 | 1-200 | Fixed stop buffer beyond the stop-run candle extreme. |
| `strategy_tp_fallback_pips` | 40 | 1-300 | Fixed take-profit distance used when the opposite prior-day level is too close or degenerate. |
| `strategy_spread_pct_of_stop` | 15.0 | 0.0-100.0 | Blocks only genuinely wide positive spread when spread exceeds this percentage of the stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card-listed major FX pair with direct M5 DWX coverage.
- `GBPUSD.DWX` - Card-listed major FX pair with direct M5 DWX coverage.
- `USDJPY.DWX` - Card-listed major FX pair with direct M5 DWX coverage.
- `USDCHF.DWX` - Card-listed major FX pair with direct M5 DWX coverage.
- `AUDUSD.DWX` - Card-listed major FX pair with direct M5 DWX coverage.

**Explicitly NOT for:**
- Non-FX index and commodity `.DWX` symbols - The card targets FX stop-run behavior on major currency pairs only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | Prior closed D1 high and low |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 50 |
| Typical hold time | Intraday, from M5 reversal entry to fixed stop or opposite daily level |
| Expected drawdown profile | Moderate reversal drawdowns concentrated around failed false-break setups |
| Regime preference | Mean-revert / reversal after liquidity sweep |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6de42a45-3a46-5eb6-a767-71c5ac89a2eb
**Source type:** book / local PDF
**Pointer:** Sterling Suhr (Day Trading Forex Live), "The Bank Trading Forex Strategy", in `6 Simple Strategies for Trading Forex`, pp. 61-72; local TradingPub PDF.
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11670_suhr-bank-stop-run-m5.md`.

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
| v1 | 2026-06-23 | Initial build from card | 1c21d431-289a-4083-a5ad-bd262c126f94 |
