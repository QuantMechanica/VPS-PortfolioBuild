# QM5_9955_ff-rectangle-sweep-m1 - Strategy Spec

**EA ID:** QM5_9955
**Slug:** `ff-rectangle-sweep-m1`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

The EA builds a short-term rectangle from the highest high and lowest low of the last four completed M15 bars, accepting it only when its height is between 0.5 and 2.5 times M15 ATR(14). On each new M1 bar it looks back over the last four completed M1 bars for a sweep beyond one rectangle boundary by at least 0.10 times M1 ATR(14), a rejection wick of at least 50% of that bar's range, and a close back inside the rectangle. It enters at market on the next M1 open with the stop 0.20 times M1 ATR beyond the swept boundary and a 2.0R take profit. It exits early if the latest M1 close breaks the rectangle boundary against the trade by 0.20 times M1 ATR, or after 30 M1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_rectangle_bars_m15` | 4 | fixed at 4 | Completed M15 bars used to build the rectangle. |
| `strategy_atr_period` | 14 | 2-100 | ATR period for M15 rectangle validation and M1 sweep distances. |
| `strategy_rect_min_atr_mult` | 0.50 | 0.10-5.00 | Minimum rectangle height as a multiple of M15 ATR. |
| `strategy_rect_max_atr_mult` | 2.50 | 0.10-10.00 | Maximum rectangle height as a multiple of M15 ATR. |
| `strategy_sweep_atr_mult` | 0.10 | 0.01-2.00 | Required sweep distance beyond the rectangle as a multiple of M1 ATR. |
| `strategy_closeback_bars` | 3 | fixed at 3 | Number of M1 bars allowed after the sweep to close back inside. |
| `strategy_wick_min_fraction` | 0.50 | 0.00-1.00 | Minimum rejection wick fraction of the sweep bar's full range. |
| `strategy_sl_atr_mult` | 0.20 | 0.01-5.00 | Stop offset beyond the swept rectangle boundary as a multiple of M1 ATR. |
| `strategy_early_exit_atr_mult` | 0.20 | 0.01-5.00 | Adverse boundary-break distance that triggers an early exit. |
| `strategy_rr_target` | 2.00 | 0.10-10.00 | Take-profit reward-to-risk multiple. |
| `strategy_time_stop_bars` | 30 | 1-500 | Maximum holding time in M1 bars. |
| `strategy_session_start_hour` | 7 | 0-23 | Broker-hour start of the entry session. |
| `strategy_session_end_hour` | 17 | 1-24 | Broker-hour end of the entry session. |
| `strategy_spread_atr_max` | 0.10 | 0.01-2.00 | Maximum allowed spread as a multiple of M1 ATR. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed liquid major FX pair for M1/M15 OHLC sweep testing.
- `GBPUSD.DWX` - card-listed liquid major FX pair for M1/M15 OHLC sweep testing.
- `USDJPY.DWX` - card-listed liquid major FX pair for M1/M15 OHLC sweep testing.
- `XAUUSD.DWX` - card-listed liquid metal symbol with DWX M1/M15 OHLC availability.

**Explicitly NOT for:**
- `SP500.DWX` - not in the card's R3 P2 basket.
- `NDX.DWX` - not in the card's R3 P2 basket.
- `WS30.DWX` - not in the card's R3 P2 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M1` |
| Multi-timeframe refs | `M15` rectangle high, rectangle low, and ATR validation |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `120` |
| Typical hold time | `Up to 30 M1 bars` |
| Expected drawdown profile | `Fixed-risk intraday reversal strategy with losses bounded by rectangle-plus-ATR stops.` |
| Regime preference | `Liquidity-sweep mean reversion after short-term stop runs` |
| Win rate target (qualitative) | `Medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** `forum`
**Pointer:** `ForexFactory thread: ruben-trader, 1 Minute Trading Strategy`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9955_ff-rectangle-sweep-m1.md`

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
| v1 | 2026-06-10 | Initial build from card | 232bacde-29d2-4f00-8890-652aa123aaf8 |
