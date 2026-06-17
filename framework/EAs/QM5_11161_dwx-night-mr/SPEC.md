# QM5_11161_dwx-night-mr — Strategy Spec

**EA ID:** QM5_11161
**Slug:** `dwx-night-mr`
**Source:** `0d015701-0978-5f79-85bc-045914b12692` (see `strategy-seeds/sources/0d015701-0978-5f79-85bc-045914b12692/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-17

---

## 1. Strategy Logic

A night-session mean-reversion scalper for FX. Trades only inside the broker-time
night window (default 22:00–01:00, NY-Close GMT+2/+3 DST-aware) after the New York
session, when liquidity is thin and price tends to revert after the day's volatility.
On each closed M15 bar in the window: if ATR(14) is below its same-time-of-day
median across the prior 20 days (a quiet, post-volatility regime), and the previous
closed bar closed BELOW the lower Bollinger Band(20, 2.0) → enter long at market;
if it closed ABOVE the upper band → enter short. The take-profit is the Bollinger
middle band (the mean) and the hard stop is 1.2 × ATR(14) from entry. Positions also
exit on a time stop after 8 closed bars, are force-flattened at the end of the night
window, and bail via an emergency exit if the last close runs beyond 1.5 × band-width
against the position. Rollover (23:55–00:10), Sunday-night, and Friday-night sessions
are skipped; spread guard fails open on .DWX zero modeled spread.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_bb_period` | 20 | 14-30 | Bollinger Band period |
| `strategy_bb_deviation` | 2.0 | 1.5-2.5 | Bollinger Band standard-deviation multiple |
| `strategy_atr_period` | 14 | 10-20 | ATR period (vol filter + stop) |
| `strategy_atr_sl_mult` | 1.2 | 0.8-1.6 | Hard-stop distance = mult × ATR(14) |
| `strategy_session_start_h` | 22 | 0-23 | Night window start, broker hour |
| `strategy_session_end_h` | 1 | 0-23 | Night window end (exclusive), broker hour |
| `strategy_rollover_skip_start_min` | 1435 | 0-1439 | Rollover skip start, broker minutes-of-day (23:55) |
| `strategy_rollover_skip_end_min` | 10 | 0-1439 | Rollover skip end, broker minutes-of-day (00:10) |
| `strategy_max_holding_bars` | 8 | 4-12 | Time stop, in closed M15 bars |
| `strategy_atr_median_days` | 20 | 10-30 | Same-time-of-day ATR median lookback (days) |
| `strategy_band_break_mult` | 1.5 | 1.0-2.5 | Emergency exit beyond mult × band-width against position |
| `strategy_spread_pct_of_stop` | 8.0 | 4-15 | Skip if spread > this % of planned stop distance |
| `strategy_skip_sunday_night` | true | bool | Skip Sunday-night session |
| `strategy_skip_friday_night` | true | bool | Skip Friday-night session |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep, liquid major; clean post-NY mean reversion in quiet hours.
- `GBPUSD.DWX` — liquid major with comparable night-session behaviour.
- `USDJPY.DWX` — liquid major; JPY-pair pip scaling handled by framework stop helpers.

**Explicitly NOT for:**
- Index / commodity `.DWX` symbols (NDX, WS30, XAUUSD, …) — the night-after-NY FX
  liquidity-reversion edge does not transfer to index/metal session structure.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~75` |
| Typical hold time | `up to 8 M15 bars (~2 hours), force-flat at window end` |
| Expected drawdown profile | `shallow, frequent small wins; tail risk on overnight gaps` |
| Regime preference | `mean-revert` |
| Win rate target (qualitative) | `high` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `0d015701-0978-5f79-85bc-045914b12692`
**Source type:** `forum` (Darwinex Blog interview article)
**Pointer:** `https://blog.darwinex.com/the-journey-of-an-automated-trading-expert`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11161_dwx-night-mr.md`

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
| v1 | 2026-06-17 | Initial build from card | board-advisor build |
