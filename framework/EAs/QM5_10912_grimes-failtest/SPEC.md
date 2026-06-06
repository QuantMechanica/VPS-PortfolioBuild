# QM5_10912_grimes-failtest - Strategy Spec

**EA ID:** QM5_10912
**Slug:** `grimes-failtest`
**Source:** `fbfd7f6e-462a-55c8-9efa-9005a70c9f5c` (see `strategy-seeds/sources/fbfd7f6e-462a-55c8-9efa-9005a70c9f5c/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA evaluates H1 closed bars for failed tests of a 20-bar range. A short is opened when price pushes at least 0.1 ATR(14) above the prior 20-bar resistance and closes back below it; a long is opened when price pushes at least 0.1 ATR(14) below prior support and closes back above it. The same reversal is allowed on the next bar after a close beyond support or resistance. Stops are placed beyond the failed-test extreme by 0.2 ATR(14), targets use the opposite side of the active 20-bar range capped at 2R, and positions exit if they fail to reach 0.5R within 6 H1 bars or remain open after 16 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_lookback_bars` | 20 | 2-100 | Prior range length for support and resistance. |
| `strategy_atr_period` | 14 | 2-100 | ATR period used for buffers and stop validation. |
| `strategy_break_buffer_atr` | 0.10 | 0.00-2.00 | Minimum penetration beyond support or resistance, in ATR. |
| `strategy_stop_buffer_atr` | 0.20 | 0.00-2.00 | Stop offset beyond the failed-test high or low, in ATR. |
| `strategy_max_stop_atr` | 2.00 | 0.25-10.00 | Reject entries whose stop distance exceeds this ATR multiple. |
| `strategy_min_range_atr` | 1.50 | 0.00-10.00 | Minimum 20-bar range width, in ATR. |
| `strategy_max_range_atr` | 6.00 | 0.50-20.00 | Maximum 20-bar range width, in ATR. |
| `strategy_no_progress_bars` | 6 | 1-48 | Bars allowed to achieve minimum favorable movement. |
| `strategy_no_progress_r` | 0.50 | 0.00-5.00 | Required favorable movement before the no-progress exit. |
| `strategy_time_exit_bars` | 16 | 1-168 | Maximum H1 bars to hold a trade. |
| `strategy_max_target_r` | 2.00 | 0.25-10.00 | Maximum target distance in R. |
| `strategy_outer_close_fraction` | 0.20 | 0.00-0.49 | Rejects closes in the outer breakout-side fraction of the signal bar. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed liquid FX pair with OHLC failure-test suitability.
- `GBPUSD.DWX` - card-listed liquid FX pair with OHLC failure-test suitability.
- `XAUUSD.DWX` - card-listed gold symbol for metal range failures.
- `GDAXI.DWX` - DAX equivalent in the DWX matrix for the card's `GER40.DWX` exposure.
- `NDX.DWX` - card-listed Nasdaq 100 index symbol.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; registered `GDAXI.DWX` instead.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `35` |
| Typical hold time | Intraday to 16 H1 bars |
| Expected drawdown profile | Mean-reversion losses can gap through failed extremes; stops are capped at 2 ATR. |
| Regime preference | Mean-revert / failed breakout around established ranges |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `fbfd7f6e-462a-55c8-9efa-9005a70c9f5c`
**Source type:** blog
**Pointer:** Adam H. Grimes, "The Failure Test", 2014-11-11, https://www.adamhgrimes.com/failure-test-2/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10912_grimes-failtest.md`

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
| v1 | 2026-06-06 | Initial build from card | bcc2bbee-591d-462f-beb4-3f391b9f33bc |
