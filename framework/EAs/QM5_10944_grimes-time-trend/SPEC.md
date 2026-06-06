# QM5_10944_grimes-time-trend - Strategy Spec

**EA ID:** QM5_10944
**Slug:** grimes-time-trend
**Source:** fbfd7f6e-462a-55c8-9efa-9005a70c9f5c
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA trades M15 index continuation only near the session open and close. It computes a session VWAP proxy as the average M15 typical price from the configured session-open proxy to the signal bar. A long signal requires the closed bar to finish above that VWAP proxy, close in the top quarter of its range, and have range at least 0.70 x ATR(20); a short signal mirrors the same rule below VWAP and in the bottom quarter. Entries are stop orders at the signal bar high or low, with force-flat exits at the end of the active window, a two-close VWAP cross exit, and a prior-two-bar trailing stop after 1R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_tf | PERIOD_M15 | M15 recommended | Signal, ATR, and VWAP-proxy timeframe. |
| strategy_session_open_hour | 15 | 0-23 | Broker-time hour for the cash/session open proxy. |
| strategy_session_open_minute | 30 | 0-59 | Broker-time minute for the cash/session open proxy. |
| strategy_session_close_hour | 22 | 0-23 | Broker-time hour for the cash/session close proxy. |
| strategy_session_close_minute | 0 | 0-59 | Broker-time minute for the cash/session close proxy. |
| strategy_window_minutes | 90 | 1-240 | Morning and afternoon active-window length. |
| strategy_atr_period | 20 | 2-200 | ATR period for signal range and stop filters. |
| strategy_min_bar_atr_mult | 0.70 | 0.10-3.00 | Minimum signal-bar range as a multiple of ATR. |
| strategy_stop_buffer_atr_mult | 0.10 | 0.00-1.00 | Stop buffer beyond the signal bar high or low. |
| strategy_min_stop_atr_mult | 0.40 | 0.10-3.00 | Minimum accepted stop distance as a multiple of ATR. |
| strategy_max_stop_atr_mult | 1.40 | 0.10-5.00 | Maximum accepted stop distance as a multiple of ATR. |
| strategy_morning_target_r | 1.50 | 0.10-10.00 | Morning-window target in R. |
| strategy_afternoon_target_r | 2.00 | 0.10-10.00 | Afternoon-window target in R. |
| strategy_close_top_fraction | 0.75 | 0.50-1.00 | Long close-location threshold inside the signal bar. |
| strategy_close_bottom_fraction | 0.25 | 0.00-0.50 | Short close-location threshold inside the signal bar. |
| strategy_max_spread_stop_fraction | 0.10 | 0.00-1.00 | Maximum spread as a fraction of stop distance. |
| strategy_pending_expiry_minutes | 15 | 1-240 | Pending stop-order expiry after signal creation. |
| strategy_vwap_lookback_bars | 80 | 10-200 | Bounded M15 history used to build the session VWAP proxy. |

---

## 3. Symbol Universe

**Designed for:**
- SP500.DWX - S&P 500 index proxy directly named by the card and available as a custom backtest symbol.
- NDX.DWX - Nasdaq 100 index proxy in the card's US large-cap basket.
- WS30.DWX - Dow 30 index proxy in the card's US large-cap basket.
- GDAXI.DWX - Available DWX DAX proxy used in place of the card's GER40.DWX name.

**Explicitly NOT for:**
- GER40.DWX - Not present in `framework/registry/dwx_symbol_matrix.csv`; GDAXI.DWX is the registered DAX equivalent.
- SPX500.DWX - Not a canonical DWX symbol; SP500.DWX is the available S&P 500 custom symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default framework gate) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 65 |
| Typical hold time | Intraday, usually within the 90-minute active window |
| Expected drawdown profile | Trend-continuation stops are bounded by 0.4-1.4 x ATR signal risk. |
| Regime preference | Intraday trend and volatility expansion near open or close |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** fbfd7f6e-462a-55c8-9efa-9005a70c9f5c
**Source type:** blog
**Pointer:** Adam H. Grimes, "It's all in a day's work" and "S&P 500 futures activity by time of day"
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10944_grimes-time-trend.md`

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
| v1 | 2026-06-06 | Initial build from card | 9befc6ae-be73-4e7d-b79b-108e66c23731 |
