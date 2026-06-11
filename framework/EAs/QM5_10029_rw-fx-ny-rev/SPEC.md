# QM5_10029_rw-fx-ny-rev - Strategy Spec

**EA ID:** QM5_10029
**Slug:** rw-fx-ny-rev
**Source:** dcbac84f-6ecf-5d21-9630-50faa69306ec (see approved card citation)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

At 11:00 New York time on an H1 chart, the EA measures the same-day FX move from 09:00 to 11:00. If the move is up by at least 0.05 x ATR(14,H1), it enters short; if the move is down by at least 0.05 x ATR(14,H1), it enters long. The initial stop is 0.60 x ATR(14,H1), and the trade exits after two hours, at 13:00 New York time, or earlier if price crosses the 09:00-11:00 midpoint in favor of the open trade.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_entry_hour_ny | 11 | 0-23 | New York hour when the reversal entry is evaluated. |
| strategy_start_hour_ny | 9 | 0-23 | New York hour used as the start of the intraday return window. |
| strategy_exit_hour_ny | 13 | 0-23 | New York hour for the scheduled time exit. |
| strategy_hold_hours | 2 | 1-3 | Maximum holding time in hours. |
| strategy_atr_period | 14 | 2-100 | ATR period on H1 bars for threshold and stop sizing. |
| strategy_entry_atr_mult | 0.05 | 0.00-0.10 | Minimum 09:00-11:00 move as a multiple of ATR. |
| strategy_sl_atr_mult | 0.60 | 0.10-3.00 | Initial stop distance as a multiple of ATR. |
| strategy_spread_mult | 1.50 | 1.00-5.00 | Entry is skipped when current spread exceeds this multiple of the same-hour median spread. |
| strategy_spread_lookback_h1 | 480 | 24-720 | H1 bars sampled for the same-hour spread median. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - major DWX FX pair named in the approved R3 basket.
- GBPUSD.DWX - major DWX FX pair named in the approved R3 basket.
- USDJPY.DWX - major DWX FX pair named in the approved R3 basket.
- AUDUSD.DWX - major DWX FX pair named in the approved R3 basket.
- NZDUSD.DWX - major DWX FX pair named in the approved R3 basket.
- USDCAD.DWX - major DWX FX pair named in the approved R3 basket.

**Explicitly NOT for:**
- Non-FX index and metal symbols - the card is a New York-time FX intraday reversal and does not authorize cross-asset expansion.

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
| Trades / year / symbol | 180 |
| Typical hold time | About two hours |
| Expected drawdown profile | Intraday mean-reversion drawdowns around FX session shocks and high-spread conditions. |
| Regime preference | Mean-revert / intraday seasonality |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** dcbac84f-6ecf-5d21-9630-50faa69306ec
**Source type:** Robot Wealth public strategy index and PDF
**Pointer:** Robot Wealth, "Index of Strategies" FX momentum reversal in NY TIME section, and "Reversal in NY Time - Backtesting Multiple Currencies"
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10029_rw-fx-ny-rev.md`

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
| v1 | 2026-06-11 | Initial build from card | 3cb346d9-2491-449b-bc42-c1f5c2b31a4d |
