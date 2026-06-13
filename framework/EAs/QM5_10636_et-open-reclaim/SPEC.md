# QM5_10636_et-open-reclaim - Strategy Spec

**EA ID:** QM5_10636
**Slug:** et-open-reclaim
**Source:** cf54ceef-f6e7-5fa0-ae03-98d3d4f8fe64 (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

The EA trades an opening-price reclaim or breakdown on M5 bars during the first part of the primary session. A long setup requires a down open versus the prior session close, a small first-15-minute opening range, M15 close above SMA(100), price trading below the session open, and a closed M5 reclaim above that open. A short setup mirrors the logic after an up open in a downtrend. Stops sit outside the opening range with an ATR buffer, targets use the prior session high or low capped at 2R, and exits also occur on session-open failure, max hold time, session close, or framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_session_start_hour | 16 | 0-23 | Broker-hour for the primary session open. |
| strategy_session_start_minute | 30 | 0-59 | Broker-minute for the primary session open. |
| strategy_session_end_hour | 23 | 0-23 | Broker-hour for session close time exit. |
| strategy_session_end_minute | 0 | 0-59 | Broker-minute for session close time exit. |
| strategy_atr_period | 14 | 1+ | ATR period on M5 for gap, range, and stop buffer. |
| strategy_trend_sma_period | 100 | 1+ | SMA period on M15 for trend direction. |
| strategy_gap_atr_mult | 0.25 | 0.0+ | Required open dislocation versus prior session close, in ATR. |
| strategy_opening_range_minutes | 15 | 5+ | Length of the opening range window. |
| strategy_small_range_atr_mult | 0.80 | 0.0+ | Maximum opening range size, in ATR. |
| strategy_reclaim_deadline_minutes | 60 | 1+ | Latest allowed reclaim or breakdown after session open. |
| strategy_entry_window_minutes | 90 | 1+ | First-session entry evaluation window. |
| strategy_max_hold_bars | 18 | 1+ | Time exit in M5 bars. |
| strategy_sl_atr_buffer_mult | 0.15 | 0.0+ | ATR buffer beyond the opening range for SL. |
| strategy_tp_r_cap | 2.0 | 0.0+ | Maximum target distance in R. |
| strategy_max_spread_points | 0 | 0+ | Entry spread filter; 0 disables because the card did not specify a spread cap. |

---

## 3. Symbol Universe

**Designed for:**
- NDX.DWX - Nasdaq 100 index CFD fits the liquid US large-cap opening pattern.
- SP500.DWX - S&P 500 custom symbol fits the source's US equity-index port; backtest-only caveat applies.
- WS30.DWX - Dow 30 index CFD fits the liquid US large-cap opening pattern.
- GDAXI.DWX - Canonical DWX DAX symbol used as the matrix-available port for the card's GER40.DWX target.

**Explicitly NOT for:**
- GER40.DWX - Not present in `framework/registry/dwx_symbol_matrix.csv`; use GDAXI.DWX.
- SPX500.DWX, SPY.DWX, ES.DWX - Not canonical available DWX symbols for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | M15 close and SMA(100) trend filter |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 35 |
| Typical hold time | Up to 18 M5 bars, roughly 90 minutes |
| Expected drawdown profile | Fixed-risk intraday losses bounded by opening-range ATR stops |
| Regime preference | Opening-price reclaim or breakdown with trend filter after gap dislocation |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** cf54ceef-f6e7-5fa0-ae03-98d3d4f8fe64
**Source type:** forum
**Pointer:** Elite Trader thread "Breaking Open Price", 2002-08-16
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10636_et-open-reclaim.md`

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
| v1 | 2026-06-13 | Initial build from card | aa0ec29c-c207-4712-9c77-6e934b4882b2 |
