# QM5_13213_balke-gmt3-range-breakout - Strategy Spec

**EA ID:** QM5_13213
**Slug:** `balke-gmt3-range-breakout`
**Source:** René Balke ForexFactory Range Breakout, exact-parameter port (OWNER-verified
via agy analysis 2026-07-13); ported from QM5_9936 `ff-range-breakout-gmt3-h1`
**Author of this spec:** Sonnet (headless research build)
**Last revised:** 2026-07-14

---

## 1. Strategy Logic

The EA builds the completed 03:00-06:00 GMT+3-equivalent H1 range for the current
trading day (broker time, DST-normalized via `QM_BrokerToUTC` + fixed +3h re-projection
— the same time handling as QM5_9936, just re-windowed). At 06:00 GMT+3-equivalent it
places a buy stop at the range high and a sell stop at the range low, with the initial
stop on the opposite side of the range and no fixed take profit. It skips the day when
the range height is below 0.4x ATR(14,H1) or above 2.5x ATR(14,H1). Open trades close at
18:00 GMT+3-equivalent (Balke's single evening resolution — collapses 9936's separate
13:00 cancel-only / 20:00 close-only hours into one), on an opposite range-side touch, or
trail to the prior two completed H1 lows/highs after price has moved at least +1R.

This is a direct diff against QM5_9936: only `strategy_range_start_hour` (1 -> 3) and the
evening-resolution hour (9936's `strategy_order_cancel_hour_gmt3=13` /
`strategy_session_close_hour_gmt3=20` -> single `strategy_exit_hour=18`) changed. ATR
range filter, +1R two-bar trail, magic/risk/news/Friday-close wiring are byte-identical
logic to 9936.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_range_start_hour` | 3 | 0-23 | First GMT+3-equivalent hour included in the range (Balke exact). |
| `strategy_range_end_hour` | 6 | 1-24 | First GMT+3-equivalent hour after the range and the order placement hour (Balke exact). |
| `strategy_exit_hour` | 18 | 0-23 | GMT+3-equivalent hour at which untriggered stop orders are removed AND open positions close (Balke's single evening resolution; ~18:00 per OWNER analysis). |
| `strategy_atr_period` | 14 | >=1 | ATR period used for range-height filters. |
| `strategy_min_range_atr_mult` | 0.4 | >0 | Minimum range height as a multiple of ATR(14,H1). |
| `strategy_max_range_atr_mult` | 2.5 | >0 | Maximum range height and hard SL cap as a multiple of ATR(14,H1). |
| `strategy_trail_trigger_r` | 1.0 | >=0 | Profit in R before the prior-two-bar trailing stop starts. |
| `strategy_range_scan_bars` | 36 | >=6 | Closed H1 bars scanned to reconstruct the current GMT+3-equivalent session range. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for (this research build):**
- `USDJPY.DWX` - direct comparison target vs QM5_9936 (same symbol, same base logic,
  different window) to isolate the effect of Balke's exact 03:00-06:00 window.
- `XAUUSD.DWX` - Balke's stated best-performing symbol (OWNER note: strong performance,
  documented drawdown phases — cross-checked against the company's existing 26-month-DD
  observation on gold).

**Explicitly NOT for (yet):**
- Any symbol outside this walkforward's scope. No basket, no master-EA wiring. Full
  symbol-universe decision deferred to Q00/Q02 if this research build is promoted.

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
| Trades / year / symbol | Comparable order of magnitude to QM5_9936 (~140), narrower range window (3h vs 5h) should mean somewhat fewer valid-range days. |
| Typical hold time | Same-day intraday hold, from 06:00 GMT+3-equivalent entry window until no later than 18:00 GMT+3-equivalent. |
| Expected drawdown profile | Fixed-risk breakout losses bounded by the completed 03:00-06:00 GMT+3-equivalent range. |
| Regime preference | Breakout / volatility-expansion days after a valid overnight range. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This EA was mechanised from:

**Source:** René Balke's Range Breakout EA, exact parameters per OWNER-verified agy
analysis (2026-07-13) — range window 03:00-06:00 broker time (GMT+2/+3, DST-aware), buy
stop at range high / sell stop at range low placed after 06:00, evening resolution
(close all + cancel pending) at ~18:00 broker time.
**Base implementation:** `framework/EAs/QM5_9936_ff-range-breakout-gmt3-h1/` (Q04 PASS,
PF 1.31) — GMT-normalized time handling reused verbatim; only window/exit hours changed.
**R1-R4 verdict (Q00):** not run — this is an ad-hoc Sonnet research walkforward per
`docs/ops/tasks/BALKE_RANGE_BREAKOUT_SONNET_BRIEF.md`. No approved card exists; Q02
evidence would be required before any portfolio claim.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (ad-hoc walkforward, this build) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-14 | Initial research build from QM5_9936, re-windowed to Balke's exact 03:00-06:00/18:00 spec | `docs/ops/tasks/BALKE_RANGE_BREAKOUT_SONNET_BRIEF.md` |
