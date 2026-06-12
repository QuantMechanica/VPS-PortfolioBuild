# QM5_10337_smallcap-mr - Strategy Spec

**EA ID:** QM5_10337
**Slug:** smallcap-mr
**Source:** fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

This EA trades an intraday mean-reversion fade on M15 bars. It builds a same-session VWAP proxy from M5 typical price weighted by tick volume, then buys when the latest closed M15 price is at least 1.25 times 20-bar realized volatility below VWAP after a negative bar, and sells when price is that far above VWAP after a positive bar. Entries are allowed only inside the liquid cash-session window, after the first 15 minutes and before the last 15 minutes, with current M15 tick volume above the 60-session same-time median and spread below its rolling 80th percentile. Exits occur on VWAP touch, after four M15 bars, or when the liquid session ends.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_extreme_mult | 1.25 | 0.1-10.0 | Required VWAP distance as a multiple of realized volatility. |
| strategy_realized_vol_lookback | 20 | 2-200 | M15 close-difference sample used for realized volatility. |
| strategy_volume_sessions | 60 | 1-60 | Same-time M15 tick-volume samples required for the median filter. |
| strategy_spread_lookback | 80 | 1-128 | Rolling spread sample count for the percentile filter. |
| strategy_spread_percentile | 80.0 | 0-100 | Maximum permitted current spread percentile. |
| strategy_atr_period | 14 | 2-200 | ATR period used for the stop loss. |
| strategy_atr_sl_mult | 1.00 | 0.1-10.0 | ATR multiple for the stop loss. |
| strategy_min_stop_spreads | 4.00 | 1-20 | Minimum stop distance measured in current spreads. |
| strategy_max_hold_bars | 4 | 1-96 | Maximum holding time in M15 bars. |
| strategy_cash_session_start_hhmm | 1530 | 0000-2359 | Broker-time cash-session start used for entries and VWAP. |
| strategy_cash_session_end_hhmm | 2200 | 0000-2359 | Broker-time cash-session end; positions close outside the active window. |
| strategy_session_exclude_minutes | 15 | 0-120 | Minutes excluded after session open and before session close. |

---

## 3. Symbol Universe

**Designed for:**
- SP500.DWX - S&P 500 custom symbol matches the card's US index port; backtest-only live caveat remains for T6.
- NDX.DWX - Liquid US large-cap index CFD suitable for intraday VWAP and tick-volume filters.
- WS30.DWX - Liquid US large-cap index CFD suitable for intraday VWAP and tick-volume filters.
- GDAXI.DWX - Available DAX custom symbol used as the DWX matrix equivalent for the card's GER40.DWX target.

**Explicitly NOT for:**
- GER40.DWX - Card-stated symbol is not present in `framework/registry/dwx_symbol_matrix.csv`; GDAXI.DWX is registered instead.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | M5 session VWAP proxy |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 70 |
| Typical hold time | Up to 4 M15 bars, about 1 hour maximum |
| Expected drawdown profile | Intraday mean-reversion drawdowns concentrated during sustained session trends. |
| Regime preference | Intraday mean-revert with volatility and liquidity filters |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9
**Source type:** paper
**Pointer:** Sandip Poudel, SSRN abstract 5921742, https://papers.ssrn.com/sol3/papers.cfm?abstract_id=5921742
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10337_smallcap-mr.md`

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
| v1 | 2026-06-13 | Initial build from card | a6a92650-ad79-490a-9f17-9620fdd03d9a |
