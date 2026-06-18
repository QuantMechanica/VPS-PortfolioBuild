# QM5_11345_continuation-method-ema50-sma5-wpr — Strategy Spec

**EA ID:** QM5_11345
**Slug:** `continuation-method-ema50-sma5-wpr`
**Source:** `303c7744-aad0-51a3-8616-b9c272831ff2` (see `strategy-seeds/sources/303c7744-aad0-51a3-8616-b9c272831ff2/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

Multi-timeframe trend-continuation system on D1. The higher timeframe (default
Weekly) sets the trend as a STATE: the EMA(50) is sloping up when
EMA50[1] > EMA50[1+10] and down when EMA50[1] < EMA50[1+10]; if the slope is
flatter than the flat-floor it is treated as no-trend and skipped. On the entry
timeframe (D1) the EA waits for a pullback STATE — at least one of the last five
closed bars closed on the counter-trend side of the entry-TF EMA(50). The single
entry EVENT is a Williams %R(14) recovery cross: for a long, WPR was at or below
-80 on the prior closed bar and is now above -80; for a short, WPR was at or
above -20 and is now below -20. On that cross the EA enters at market in the
trend direction. The stop is the structural swing low/high over the last ten
bars, clamped to 20–100 pips (the setup is skipped if the swing is wider than
100 pips); the take-profit is 2:1 off that clamped stop distance. The position is
also trailed out on two consecutive D1 closes on the wrong side of the SMA(5)
(below for longs, above for shorts), plus the framework Friday-close and news
guards.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_htf` | PERIOD_W1 | D1–MN1 | Higher-TF EMA50 trend filter |
| `strategy_ema_period` | 50 | 20–200 | EMA period (trend + pullback reference) |
| `strategy_slope_bars` | 10 | 3–30 | Bars back for the HTF EMA50 slope comparison |
| `strategy_flat_floor_pips` | 10.0 | 1–50 | Skip when abs(HTF EMA50 slope) below this (flat) |
| `strategy_wpr_period` | 14 | 7–28 | Williams %R period |
| `strategy_wpr_os_level` | -80.0 | -95..-60 | Oversold exhaustion level (long arm) |
| `strategy_wpr_ob_level` | -20.0 | -40..-5 | Overbought exhaustion level (short arm) |
| `strategy_pullback_bars` | 5 | 2–10 | Lookback for a pullback close through EMA50 |
| `strategy_swing_lookback` | 10 | 5–30 | Bars for the structural swing stop |
| `strategy_sl_min_pips` | 20 | 5–50 | Stop clamp lower bound (pips) |
| `strategy_sl_max_pips` | 100 | 50–300 | Stop clamp upper bound; skip if swing wider |
| `strategy_tp_rr` | 2.0 | 1.0–4.0 | Take-profit R:R off the stop distance |
| `strategy_sma_trail_period` | 5 | 3–20 | SMA period for the trailing exit |
| `strategy_exit_consec` | 2 | 1–4 | Consecutive wrong-side closes to exit |
| `strategy_spread_pct_of_stop` | 15.0 | 5–50 | Skip if spread exceeds this % of stop distance |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — major FX with clean D1 swings; primary named in the card.
- `GBPUSD.DWX` — major FX, comparable trend behaviour; named in the card.
- `USDJPY.DWX` — major FX, named in the card; pip-scaling handled by helpers.

**Explicitly NOT for:**
- Index / metal CFDs — the card mechanises an FX continuation pattern; pip
  bounds (20–100 pips) are calibrated for FX majors, not indices.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | `W1` EMA(50) slope (higher-TF trend filter) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~20` |
| Typical hold time | `several days to weeks (D1 swing)` |
| Expected drawdown profile | `moderate; structural stop + 2:1 RR, trend-aligned` |
| Regime preference | `trend (continuation/pullback)` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `303c7744-aad0-51a3-8616-b9c272831ff2`
**Source type:** `book`
**Pointer:** `Secret to Winning Forex — The Continuation Method Trading Strategy (anonymous ebook), pages 11-22`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11345_continuation-method-ema50-sma5-wpr.md`

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
| v1 | 2026-06-18 | Initial build from card | board-advisor build |
