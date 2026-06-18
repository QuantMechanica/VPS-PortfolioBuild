# QM5_11341_tc-m5-20-ema3-bb-macd — Strategy Spec

**EA ID:** QM5_11341
**Slug:** `tc-m5-20-ema3-bb-macd`
**Source:** `e78a9f1f-4e6a-563c-a080-915133d6ed28` (Thomas Carter, 20 Forex Trading Strategies — 5 Min System #20, p.48)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

Fast M5 momentum scalp. The single trigger EVENT is EMA(3) crossing the Bollinger
Bands(20, 3.0) middle band on the last closed bar: a cross above is a long setup, a
cross below is a short setup. The MACD(12,26,9) main line provides a confirming STATE
(not a second event): for a long, MACD must either have crossed up through zero
(main was ≤0 on the prior closed bar and >0 on the trigger bar) OR be approaching zero
from below — its main value rising toward zero (absolute value strictly decreasing)
for `macd_approach_bars` consecutive closed bars while still negative. The short side is
the mirror. MACD main is treated as a signed value and is never rejected for being
negative. Entries fill at the next M5 bar open. Each trade exits at a fixed 12-pip stop,
a fixed 12-pip target, or a time stop that closes the position at market after 12 closed
M5 bars if neither stop nor target is hit. One position per magic.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_bb_period` | 20 | 10-50 | Bollinger Bands period (middle band = SMA) |
| `strategy_bb_deviation` | 3.0 | 1.0-3.0 | Bollinger deviation (mandatory band arg) |
| `strategy_ema_period` | 3 | 2-10 | Fast EMA crossing the BB middle band |
| `strategy_macd_fast` | 12 | 5-20 | MACD fast EMA period |
| `strategy_macd_slow` | 26 | 15-40 | MACD slow EMA period |
| `strategy_macd_signal` | 9 | 5-15 | MACD signal EMA period |
| `strategy_macd_approach_bars` | 2 | 1-3 | Consecutive closed bars of |MACD| decreasing to count as "approaching zero" |
| `strategy_sl_pips` | 12 | 10-15 | Stop loss in pips |
| `strategy_tp_pips` | 12 | 10-15 | Take profit in pips |
| `strategy_time_stop_bars` | 12 | 0-18 | Close after this many closed M5 bars (0 = off) |
| `strategy_spread_cap_points` | 20 | 10-40 | Skip only a genuinely wide spread (raw points; fail-open on zero) |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — most liquid major; tightest real spread for an M5 scalp.
- `GBPUSD.DWX` — liquid major with the intraday volatility this momentum scalp needs.
- `AUDUSD.DWX` — liquid commodity major; the card lists it in the P2 basket.
- `USDJPY.DWX` — liquid JPY major; pip scaling handled via `QM_StopRulesPipsToPriceDistance`.

**Explicitly NOT for:**
- Index / metal `.DWX` symbols — the 12-pip fixed stop/target is FX-calibrated; index point scaling would mis-size stops.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~150` |
| Typical hold time | `minutes (≤12 M5 bars = ≤60 min)` |
| Expected drawdown profile | `frequent small losers, fixed 1:1 R; shallow but choppy equity` |
| Regime preference | `momentum / volatility-expansion intraday` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `e78a9f1f-4e6a-563c-a080-915133d6ed28`
**Source type:** `book`
**Pointer:** `Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)", 5 Min Trading System #20, page 48`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11341_tc-m5-20-ema3-bb-macd.md`

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
| v1 | 2026-06-18 | Initial build from card | EMA3/BB-mid cross EVENT + MACD zero-line STATE; fixed 12-pip SL/TP + 12-bar time stop |
