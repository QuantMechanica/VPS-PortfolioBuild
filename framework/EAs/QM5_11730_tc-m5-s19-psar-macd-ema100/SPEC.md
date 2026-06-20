# QM5_11730_tc-m5-s19-psar-macd-ema100 - Strategy Spec

**EA ID:** QM5_11730
**Slug:** `tc-m5-s19-psar-macd-ema100`
**Source:** `40a4454c-64ff-5015-8538-9f7b32abc0e9` (see `sources/tc-m5-20-forex-strategies`)
**Author of this spec:** Codex
**Last revised:** 2026-06-21

---

## 1. Strategy Logic

This EA trades Thomas Carter Strategy #19 on M5 forex symbols. It opens long when the last closed M5 bar is above EMA(100), PSAR(0.01, 0.01) flips from above price to below price, and MACD(64,128,9) main is positive. It opens short on the inverse: close below EMA(100), PSAR flips above price, and MACD main is negative. Stop loss is 3 pips beyond the first PSAR dot after the flip, take profit is fixed at 10 pips, and an opposite PSAR flip closes the position before SL/TP if it arrives first.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_psar_step` | 0.01 | > 0 | Parabolic SAR step from the card. |
| `strategy_psar_maximum` | 0.01 | > 0 | Parabolic SAR maximum from the card; equal to step for slow SAR. |
| `strategy_ema_period` | 100 | >= 1 | EMA trend filter period on M5 closed bars. |
| `strategy_macd_fast` | 64 | >= 1 | MACD fast EMA period. |
| `strategy_macd_slow` | 128 | > fast | MACD slow EMA period. |
| `strategy_macd_signal` | 9 | >= 1 | MACD signal period. |
| `strategy_sl_buffer_pips` | 3 | >= 1 | Stop buffer beyond the first PSAR dot after a flip. |
| `strategy_tp_pips` | 10 | >= 1 | Fixed take-profit distance; card range is 7-12 pips. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - explicitly listed by the card and present in the DWX matrix.
- `GBPUSD.DWX` - explicitly listed by the card and present in the DWX matrix.
- `USDJPY.DWX` - explicitly listed by the card and present in the DWX matrix.
- `USDCHF.DWX` - explicitly listed by the card and present in the DWX matrix.

**Explicitly NOT for:**
- Non-DWX symbols - Q01/P2 backtests require canonical `.DWX` symbols.
- Indices, metals, commodities - the card targets M5 forex majors only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` from the V5 skeleton; strategy reads closed `PERIOD_M5` bars |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `300` |
| Typical hold time | Minutes to intraday; tight 10-pip target and 3-pip PSAR-buffer stop. |
| Expected drawdown profile | Scalping profile with frequent small wins/losses and sensitivity to spread/slippage. |
| Regime preference | Trend-following scalp after PSAR flips in EMA/MACD-aligned direction. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `40a4454c-64ff-5015-8538-9f7b32abc0e9`
**Source type:** PDF/booklet strategy collection
**Pointer:** `367145560-20-forex-trading-strategies-5-minute-time-frame-pdf.pdf`, Thomas Carter, *20 Forex Trading Strategies (5 Minute Time Frame)*, Strategy #19, 2013.
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11730_tc-m5-s19-psar-macd-ema100.md`

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
| v1 | 2026-06-21 | Initial build from card | 67c192e7-5894-4dd4-ba17-9ee7b0be2db9 |
