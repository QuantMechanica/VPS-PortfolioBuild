# QM5_11371_tom-demark-ema9-30-momentum-h1 — Strategy Spec

**EA ID:** QM5_11371
**Slug:** `tom-demark-ema9-30-momentum-h1`
**Source:** `becda36b-263f-5989-b5fa-f1e945c0d4bd` (see `strategy-seeds/sources/becda36b-263f-5989-b5fa-f1e945c0d4bd/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

On the close of each H1 bar the EA fires a single entry EVENT — the EMA(9)
crossing the EMA(30) — and confirms it with two STATES sampled on the same
closed bar. LONG: EMA(9) crosses above EMA(30), Momentum(14) is above its 100
baseline, and the last bar closes above a DeMark downtrend line drawn through
the three most recent TD High Points (local maxima with strictly lower
neighbouring highs and monotonically decreasing peaks). SHORT mirrors this:
EMA(9) crosses below EMA(30), Momentum(14) below 100, and the bar closes below
an uptrend line through three rising TD Low Points. Stops are a fixed 40 pips;
the position takes profit at 2.5R and is step-trailed in 10-pip increments
once 20 pips in profit. Only one position per symbol/magic is held at a time.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_fast_period` | 9 | 5-20 | Fast EMA period for the cross event |
| `strategy_ema_slow_period` | 30 | 20-60 | Slow EMA period for the cross event |
| `strategy_mom_period` | 14 | 7-21 | Momentum lookback period |
| `strategy_mom_baseline` | 100.0 | 100 | Momentum neutral level (MT5 ratio×100) |
| `strategy_td_min_points` | 3 | 3-5 | Min TD points required to build a trend line |
| `strategy_td_scan_bars` | 60 | 20-120 | Bounded closed-bar scan window for TD points |
| `strategy_sl_pips` | 40 | 20-80 | Fixed initial stop distance in pips |
| `strategy_tp_rr` | 2.5 | 1.0-5.0 | Take-profit as a multiple of stop distance |
| `strategy_trail_trigger_pips` | 20 | 10-60 | Profit before trailing starts |
| `strategy_trail_step_pips` | 10 | 5-20 | Step-trail increment in pips |
| `strategy_max_spread_pips` | 20 | 5-30 | Block only a genuinely wide spread |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep, liquid H1 major; the canonical Tom DeMark FX test pair.
- `GBPUSD.DWX` — liquid major with trend persistence suiting EMA-cross entries.
- `USDJPY.DWX` — liquid major; pip-scale handled via `QM_StopRulesPipsToPriceDistance`.

**Explicitly NOT for:**
- Index / metal `.DWX` symbols — the 40-pip fixed stop and TD-line scale are
  calibrated to forex majors, not to index point structure.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~50` |
| Typical hold time | `hours to a few days` |
| Expected drawdown profile | `moderate; fixed 40-pip stop caps per-trade loss` |
| Regime preference | `trend / breakout` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `becda36b-263f-5989-b5fa-f1e945c0d4bd`
**Source type:** `book` (retail compilation referencing Tom DeMark methodology)
**Pointer:** `9 Forex Systems` (DayTradeForex.com compilation), local PDF archive citation in card
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11371_tom-demark-ema9-30-momentum-h1.md`

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
| v1 | 2026-06-18 | Initial build from card | pending |
